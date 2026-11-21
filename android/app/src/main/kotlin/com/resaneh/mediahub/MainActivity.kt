package com.resaneh.mediahub

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.Executors
import kotlin.math.min

class MainActivity : FlutterActivity() {
    companion object {
        private const val THUMBNAIL_CHANNEL = "com.resaneh.media/thumbnail"
    }

    private val thumbnailExecutor = Executors.newSingleThreadExecutor()
    private lateinit var backupDocumentsChannel: BackupDocumentsChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupDocumentsChannel = BackupDocumentsChannel(this)
        backupDocumentsChannel.attach(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THUMBNAIL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "createImageThumbnail" &&
                    call.method != "createVideoThumbnail") {
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
                        val thumb = if (call.method == "createImageThumbnail") {
                            imageThumbnail(sourcePath, maxWidth, maxHeight)
                        } else {
                            videoThumbnail(sourcePath, timeUs)
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
        while (bounds.outWidth / sampleSize > width ||
            bounds.outHeight / sampleSize > height) sampleSize *= 2
        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        return BitmapFactory.decodeFile(path, options)
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
