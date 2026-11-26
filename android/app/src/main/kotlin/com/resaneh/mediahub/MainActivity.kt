package com.resaneh.mediahub

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.os.ParcelFileDescriptor
import android.media.MediaMetadataRetriever
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors
import kotlin.math.min

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val THUMBNAIL_CHANNEL = "com.resaneh.media/thumbnail"
    }

    private val thumbnailExecutor = Executors.newFixedThreadPool(2)
    private lateinit var backupDocumentsChannel: BackupDocumentsChannel

    override fun onCreate(savedInstanceState: Bundle?) {
        // Fail closed until Flutter has loaded the device-local policy.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupDocumentsChannel = BackupDocumentsChannel(this)
        backupDocumentsChannel.attach(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.resaneh.media/security")
            .setMethodCallHandler { call, result ->
                if (call.method != "setSecure") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (call.argument<Boolean>("enabled") != false) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(true)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THUMBNAIL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "createImageThumbnail" &&
                    call.method != "createVideoThumbnail" &&
                    call.method != "createPdfThumbnail") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val sourcePath = call.argument<String>("sourcePath")
                val destinationPath = call.argument<String>("destinationPath")
                if (sourcePath.isNullOrBlank() || destinationPath.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "File paths are required", null)
                    return@setMethodCallHandler
                }
                val maxWidth = (call.argument<Int>("maxWidth") ?: 480).coerceIn(1, 2048)
                val maxHeight = (call.argument<Int>("maxHeight") ?: 480).coerceIn(1, 2048)
                val quality = (call.argument<Int>("quality") ?: 82).coerceIn(1, 100)
                val timeUs = (call.argument<Number>("timeUs") ?: 1000000L).toLong()
                thumbnailExecutor.execute {
                    try {
                        val thumb = when (call.method) {
                            "createImageThumbnail" -> imageThumbnail(sourcePath, maxWidth, maxHeight)
                            "createPdfThumbnail" -> pdfThumbnail(sourcePath, maxWidth, maxHeight)
                            else -> videoThumbnail(sourcePath, timeUs)
                        }
                        if (thumb == null) {
                            runOnUiThread { result.success(false) }
                            return@execute
                        }
                        try {
                            val scale = min(
                                min(maxWidth.toFloat() / thumb.width,
                                    maxHeight.toFloat() / thumb.height), 1f)
                            val scaled = Bitmap.createScaledBitmap(
                                thumb,
                                (thumb.width * scale).toInt().coerceAtLeast(1),
                                (thumb.height * scale).toInt().coerceAtLeast(1),
                                true
                            )
                            try {
                                val outputFile = File(destinationPath)
                                outputFile.parentFile?.mkdirs()
                                FileOutputStream(outputFile).use { stream ->
                                    if (!scaled.compress(Bitmap.CompressFormat.JPEG, quality, stream)) {
                                        throw IOException("Thumbnail compression failed")
                                    }
                                    stream.flush()
                                    stream.fd.sync()
                                }
                            } finally {
                                if (scaled !== thumb) scaled.recycle()
                            }
                        } finally {
                            thumb.recycle()
                        }
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("THUMBNAIL_ERROR", e.message, null) }
                    }
                }
            }
    }

    private fun imageThumbnail(path: String, width: Int, height: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sampleSize = 1
        while (bounds.outWidth / (sampleSize * 2L) >= width ||
            bounds.outHeight / (sampleSize * 2L) >= height) sampleSize *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = BitmapFactory.decodeFile(path, options) ?: return null
        val orientation = try {
            ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL)
        } catch (_: IOException) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { matrix.setRotate(-90f); matrix.postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(270f)
        }
        if (matrix.isIdentity) return bitmap
        return try {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                .also { if (it !== bitmap) bitmap.recycle() }
        } catch (e: Exception) {
            bitmap.recycle()
            throw e
        }
    }

    private fun pdfThumbnail(path: String, width: Int, height: Int): Bitmap? {
        val descriptor = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try { PdfRenderer(descriptor) } catch (e: Exception) {
            descriptor.close()
            throw e
        }
        renderer.use { pdf ->
            if (pdf.pageCount == 0) return null
            pdf.openPage(0).use { page ->
                val scale = min(width.toFloat() / page.width, height.toFloat() / page.height)
                val bitmap = Bitmap.createBitmap((page.width * scale).toInt().coerceAtLeast(1),
                    (page.height * scale).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                try {
                    bitmap.eraseColor(Color.WHITE)
                    val matrix = Matrix().apply { setScale(scale, scale) }
                    page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                    return bitmap
                } catch (e: Exception) {
                    bitmap.recycle()
                    throw e
                }
            }
        }
    }

    private fun videoThumbnail(path: String, timeUs: Long): Bitmap? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            return retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: retriever.getFrameAtTime(0L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } finally {
            retriever.release()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::backupDocumentsChannel.isInitialized &&
            backupDocumentsChannel.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        thumbnailExecutor.shutdown()
        if (::backupDocumentsChannel.isInitialized) backupDocumentsChannel.shutdown()
        super.onDestroy()
    }
}
