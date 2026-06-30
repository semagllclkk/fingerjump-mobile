package com.example.pixel_game

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "finger_jump/hand_tracking"
    private val EVENT_CHANNEL  = "finger_jump/hand_events"

    private var handLandmarker: HandLandmarker? = null
    private var eventSink: EventChannel.EventSink? = null
    private var frameCount = 0L

    // tip → pip çiftleri (yumruk tespiti)
    private val fingerPairs = listOf(
        Pair(8, 6), Pair(12, 10), Pair(16, 14), Pair(20, 18)
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> {
                        Thread {
                            try {
                                initMediaPipe()
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("MEDIAPIPE_ERROR", e.message ?: "Bilinmeyen hata", null)
                                }
                            }
                        }.start()
                    }
                    "stopTracking" -> {
                        handLandmarker?.close()
                        handLandmarker = null
                        result.success(null)
                    }
                    "processFrame" -> {
                        val bytes  = call.argument<ByteArray>("bytes")!!
                        val width  = call.argument<Int>("width")!!
                        val height = call.argument<Int>("height")!!
                        processFrame(bytes, width, height)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
                override fun onCancel(args: Any?) { eventSink = null }
            })
    }

    // ─── MediaPipe başlatma ──────────────────────────────────────────────────────
    // setModelAssetBuffer kullanıyoruz: dosyayı Java'da okuyoruz → hata native
    // crash değil yakalanabilir IOException olarak gelir.
    //
    // Flutter APK'da asset yolu: flutter_assets/assets/models/hand_landmarker.task
    // (pubspec.yaml'daki "assets/models/" tanımı bu yolda sonuçlanır)

    private fun initMediaPipe() {
        val assetPath = "flutter_assets/assets/models/hand_landmarker.task"

        val modelBytes = assets.open(assetPath).use { it.readBytes() }
        val modelBuffer = ByteBuffer.allocateDirect(modelBytes.size).apply {
            put(modelBytes)
            rewind()
        }

        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetBuffer(modelBuffer)
                    .build()
            )
            .setRunningMode(RunningMode.IMAGE)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .build()

        handLandmarker = HandLandmarker.createFromOptions(this, options)
    }

    // Flutter JPEG formatında gönderdiği için doğrudan Bitmap'e decode edilir.
    // Ön kamera portrait modunda görüntü 90° dönük gelir → MediaPipe algılayamaz.
    // 90° döndürme + yatay flip ile el doğru yöne getirilir.
    private fun processFrame(jpegBytes: ByteArray, width: Int, height: Int) {
        val lm = handLandmarker ?: return
        if (frameCount++ % 2 != 0L) return        // her 2 frame'de 1 işle

        try {
            val raw = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size) ?: return

            // Ön kamera düzeltmesi: 90° CW + yatay ayna
            val mat = Matrix().apply {
                postRotate(90f)
                postScale(-1f, 1f)   // mirror flip (ön kamera)
            }
            val bitmap = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, mat, true)
            raw.recycle()

            val mpImage = BitmapImageBuilder(bitmap).build()
            val result: HandLandmarkerResult = lm.detect(mpImage)
            bitmap.recycle()

            if (result == null || result.landmarks().isEmpty()) {
                runOnUiThread { eventSink?.success(mapOf("found" to false, "isPunch" to false)) }
                return
            }

            val landmarks = result.landmarks()[0]
            val fingerX = landmarks[8].x().toDouble()
            val fingerY = landmarks[8].y().toDouble()
            val isFist  = fingerPairs.count { (tip, pip) ->
                landmarks[tip].y() > landmarks[pip].y()
            } >= 3

            runOnUiThread {
                eventSink?.success(mapOf("found" to true, "fingerX" to fingerX, "fingerY" to fingerY, "isPunch" to isFist))
            }
        } catch (_: Exception) { /* sessizce geç */ }
    }
}
