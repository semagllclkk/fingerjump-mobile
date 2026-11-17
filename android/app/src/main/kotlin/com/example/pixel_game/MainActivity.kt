package com.example.pixel_game

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * El takibi köprüsü.
 *
 * Performans tasarımı (eski sürümdeki kasmanın nedenleri parantez içinde):
 *  - Tüm görüntü işleme ve MediaPipe çağrıları tek thread'lik bir executor'da
 *    çalışır. (Eskiden Android ana thread'inde çalışıp onu her frame
 *    30–60 ms kilitliyordu.)
 *  - YUV420 → ARGB dönüşümü doğrudan piksel döngüsüyle yapılır; döndürme +
 *    ayna aynı döngüde (devrik okuma) uygulanır. (Eskiden YUV → NV21 → JPEG
 *    sıkıştır → JPEG çöz → döndürülmüş kopya zinciri vardı.)
 *  - Bitmap ve piksel dizisi yeniden kullanılır; her frame tahsis yapılmaz.
 *  - MediaPipe VIDEO modunda çalışır: el bir kez bulununca sonraki frame'lerde
 *    yalnızca landmark takibi yapılır. GPU delegate denenir, olmazsa CPU.
 *  - Sonuç, processFrame çağrısının cevabı olarak döner. Dart tarafı cevap
 *    gelmeden yeni frame göndermez → kuyruk birikmez, gecikme sabit kalır.
 */
class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "finger_jump/hand_tracking"
    private val TAG = "HandTracking"

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Yalnızca executor thread'inden erişilir.
    private var handLandmarker: HandLandmarker? = null
    private var usingGpu = false
    private var lastTimestampMs = 0L
    private var pixels: IntArray? = null
    private var bitmap: Bitmap? = null

    // tip → pip çiftleri (yumruk tespiti)
    private val fingerPairs = listOf(
        Pair(8, 6), Pair(12, 10), Pair(16, 14), Pair(20, 18)
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> executor.execute {
                        try {
                            closeLandmarker()
                            initMediaPipe()
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("MEDIAPIPE_ERROR", e.message ?: "Bilinmeyen hata", null)
                            }
                        }
                    }
                    "stopTracking" -> executor.execute {
                        closeLandmarker()
                        mainHandler.post { result.success(null) }
                    }
                    "processFrame" -> {
                        val y = call.argument<ByteArray>("y")
                        val u = call.argument<ByteArray>("u")
                        val v = call.argument<ByteArray>("v")
                        val yRowStride = call.argument<Int>("yRowStride") ?: 0
                        val uvRowStride = call.argument<Int>("uvRowStride") ?: 0
                        val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        if (y == null || u == null || v == null || width == 0 || height == 0) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        executor.execute {
                            val out = try {
                                processFrame(y, u, v, yRowStride, uvRowStride, uvPixelStride, width, height)
                            } catch (e: Exception) {
                                Log.w(TAG, "processFrame: ${e.message}")
                                null
                            }
                            mainHandler.post { result.success(out) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        executor.execute { closeLandmarker() }
        executor.shutdown()
        super.onDestroy()
    }

    // ─── MediaPipe ───────────────────────────────────────────────────────────────

    private var modelBytes: ByteArray? = null

    private fun buildLandmarker(delegate: Delegate): HandLandmarker {
        val bytes = modelBytes
            ?: assets.open("flutter_assets/assets/models/hand_landmarker.task")
                .use { it.readBytes() }
                .also { modelBytes = it }
        val modelBuffer = ByteBuffer.allocateDirect(bytes.size).apply {
            put(bytes)
            rewind()
        }
        val options = HandLandmarker.HandLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetBuffer(modelBuffer)
                    .setDelegate(delegate)
                    .build()
            )
            .setRunningMode(RunningMode.VIDEO)
            .setNumHands(1)
            .setMinHandDetectionConfidence(0.5f)
            .setMinHandPresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .build()
        return HandLandmarker.createFromOptions(this, options)
    }

    private fun initMediaPipe() {
        handLandmarker = try {
            buildLandmarker(Delegate.GPU).also { usingGpu = true }
        } catch (e: Throwable) {
            Log.i(TAG, "GPU delegate kullanılamadı, CPU'ya geçiliyor: ${e.message}")
            usingGpu = false
            buildLandmarker(Delegate.CPU)
        }
        lastTimestampMs = 0L
    }

    private fun closeLandmarker() {
        try { handLandmarker?.close() } catch (_: Exception) {}
        handLandmarker = null
    }

    // ─── YUV420 → ARGB (döndürme + ayna dahil) ─────────────────────────────────
    //
    // Ön kamera portrait modunda görüntü 90° dönük + ayna gelir. Eski kodda
    // 90° CW döndürme + yatay ayna uygulanıyordu; bu ikisinin bileşimi bir
    // devriktir: hedef(X, Y) = kaynak(x = Y, y = X). Böylece ayrı bir döndürme
    // kopyasına gerek kalmaz.
    //
    // Geniş kareler (≥ 480 px) 2'ye bölünerek örneklenir; MediaPipe girişi
    // zaten 192–256 px'e küçülttüğü için doğruluk kaybı yoktur.

    private fun toBitmap(
        y: ByteArray, u: ByteArray, v: ByteArray,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
        width: Int, height: Int
    ): Bitmap {
        val step = if (width >= 480) 2 else 1
        val outW = height / step
        val outH = width / step

        var px = pixels
        if (px == null || px.size != outW * outH) {
            px = IntArray(outW * outH)
            pixels = px
        }
        var bmp = bitmap
        if (bmp == null || bmp.width != outW || bmp.height != outH) {
            bmp?.recycle()
            bmp = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
            bitmap = bmp
        }

        val ySize = y.size
        val uSize = u.size
        val vSize = v.size
        var i = 0
        for (oy in 0 until outH) {
            val sx = oy * step
            val uvCol = (sx shr 1) * uvPixelStride
            for (ox in 0 until outW) {
                val sy = ox * step
                val yi = sy * yRowStride + sx
                val uvi = (sy shr 1) * uvRowStride + uvCol
                val yy = if (yi < ySize) (y[yi].toInt() and 0xff) else 0
                val uu = (if (uvi < uSize) (u[uvi].toInt() and 0xff) else 128) - 128
                val vv = (if (uvi < vSize) (v[uvi].toInt() and 0xff) else 128) - 128

                // BT.601 tamsayı yaklaşımı
                var r = yy + ((1436 * vv) shr 10)
                var g = yy - ((352 * uu + 731 * vv) shr 10)
                var b = yy + ((1815 * uu) shr 10)
                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                px[i++] = -0x1000000 or (r shl 16) or (g shl 8) or b
            }
        }
        bmp.setPixels(px, 0, outW, 0, 0, outW, outH)
        return bmp
    }

    // ─── Frame işleme (executor thread) ─────────────────────────────────────────

    private fun processFrame(
        y: ByteArray, u: ByteArray, v: ByteArray,
        yRowStride: Int, uvRowStride: Int, uvPixelStride: Int,
        width: Int, height: Int
    ): Map<String, Any>? {
        val lm = handLandmarker ?: return null

        val bmp = toBitmap(y, u, v, yRowStride, uvRowStride, uvPixelStride, width, height)
        val mpImage = BitmapImageBuilder(bmp).build()

        // VIDEO modu kesin artan zaman damgası ister.
        var ts = SystemClock.uptimeMillis()
        if (ts <= lastTimestampMs) ts = lastTimestampMs + 1
        lastTimestampMs = ts

        val result = try {
            lm.detectForVideo(mpImage, ts)
        } catch (e: Exception) {
            if (usingGpu) {
                // Bazı cihazlarda GPU oluşturulabiliyor ama çalışmıyor → CPU'ya düş.
                Log.w(TAG, "GPU tespit hatası, CPU'ya geçiliyor: ${e.message}")
                closeLandmarker()
                usingGpu = false
                try {
                    handLandmarker = buildLandmarker(Delegate.CPU)
                    lastTimestampMs = 0L
                } catch (_: Exception) {}
            }
            return null
        }

        val hands = result.landmarks()
        if (hands.isEmpty()) {
            return mapOf("found" to false, "isPunch" to false)
        }

        val landmarks = hands[0]
        val isFist = fingerPairs.count { (tip, pip) ->
            landmarks[tip].y() > landmarks[pip].y()
        } >= 3

        return mapOf(
            "found" to true,
            "fingerX" to landmarks[8].x().toDouble(),
            "fingerY" to landmarks[8].y().toDouble(),
            "isPunch" to isFist,
        )
    }
}
