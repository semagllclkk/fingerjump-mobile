package com.example.pixel_game

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
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
                        val y            = call.argument<ByteArray>("y")!!
                        val u            = call.argument<ByteArray>("u")!!
                        val v            = call.argument<ByteArray>("v")!!
                        val yRowStride   = call.argument<Int>("yRowStride")!!
                        val uvRowStride  = call.argument<Int>("uvRowStride")!!
                        val uvPixelStride = call.argument<Int>("uvPixelStride")!!
                        val width        = call.argument<Int>("width")!!
                        val height       = call.argument<Int>("height")!!
                        processFrame(y, u, v, yRowStride, uvRowStride, uvPixelStride, width, height)
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

    // ─── YUV420 → NV21 dönüşümü ─────────────────────────────────────────────────
    //
    // Flutter camera paketi Android'de YUV_420_888 formatı kullanır (yuv420).
    // Y, U, V plane'leri ayrı ByteArray olarak gelir; stride değerleri farklı olabilir.
    // NV21 = Y plane + interleaved VU plane → YuvImage → JPEG → Bitmap zinciri ile
    // MediaPipe'ın beklediği Bitmap elde edilir.

    private fun yuv420ToNv21(
        y: ByteArray, u: ByteArray, v: ByteArray,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
        width: Int, height: Int
    ): ByteArray {
        val nv21 = ByteArray(width * height + 2 * (width / 2) * (height / 2))

        // Y plane — her satır yRowStride genişliğinde, biz sadece width kadar kopyalarız.
        if (yRowStride == width) {
            System.arraycopy(y, 0, nv21, 0, width * height)
        } else {
            for (row in 0 until height) {
                System.arraycopy(y, row * yRowStride, nv21, row * width, width)
            }
        }

        // VU plane (NV21 sırası: V önce, U sonra)
        var offset = width * height
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                nv21[offset++] = v[row * uvRowStride + col * uvPixelStride]
                nv21[offset++] = u[row * uvRowStride + col * uvPixelStride]
            }
        }
        return nv21
    }

    // ─── Frame işleme ────────────────────────────────────────────────────────────
    //
    // Ön kamera portrait modunda görüntü 90° dönük + ayna gelir.
    // 90° CW döndürme + yatay flip ile el doğru yöne getirilir.

    private fun processFrame(
        y: ByteArray, u: ByteArray, v: ByteArray,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
        width: Int, height: Int
    ) {
        val lm = handLandmarker ?: return
        if (frameCount++ % 2 != 0L) return   // her 2 frame'de 1 işle

        try {
            // YUV420 → NV21 → YuvImage → JPEG → Bitmap
            val nv21 = yuv420ToNv21(y, u, v, yRowStride, uvRowStride, uvPixelStride, width, height)
            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val baos = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, baos)
            val raw = BitmapFactory.decodeByteArray(baos.toByteArray(), 0, baos.size()) ?: return

            // Ön kamera düzeltmesi: 90° CW + yatay ayna
            val mat = Matrix().apply {
                postRotate(90f)
                postScale(-1f, 1f)
            }
            val bitmap = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, mat, true)
            raw.recycle()

            val mpImage = BitmapImageBuilder(bitmap).build()
            val result: HandLandmarkerResult = lm.detect(mpImage)
            bitmap.recycle()

            if (result.landmarks().isEmpty()) {
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
