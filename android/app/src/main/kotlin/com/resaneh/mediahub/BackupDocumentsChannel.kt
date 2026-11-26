package com.resaneh.mediahub

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.Executors

/** Android SAF: no all-files permission, no whole-ZIP byte[] in Dart. */
class BackupDocumentsChannel(private val activity: Activity) {
    companion object {
        const val EXPORT_REQUEST = 7201
        const val IMPORT_REQUEST = 7202
        private const val CHANNEL = "com.resaneh.media/backup_documents"
    }

    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingExportPath: String? = null
    private var pendingAction: String? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (pending != null) {
                    result.error("BUSY", "A document picker is already active", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "exportZip" -> {
                        val source = call.argument<String>("sourcePath")
                        val name = call.argument<String>("suggestedName")
                        if (source.isNullOrBlank() || name.isNullOrBlank()) {
                            result.error("ARGUMENT", "A ZIP path and name are required", null)
                            return@setMethodCallHandler
                        }
                        val sourceFile = File(source).canonicalFile
                        val cachePath = activity.cacheDir.canonicalPath + File.separator
                        if (!sourceFile.path.startsWith(cachePath) || !sourceFile.isFile) {
                            result.error("PATH", "Backup must be stored in private cache", null)
                            return@setMethodCallHandler
                        }
                        pending = result
                        pendingAction = "exportZip"
                        pendingExportPath = sourceFile.path
                        try {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = if (name.endsWith(".rmb", ignoreCase = true)) "application/octet-stream" else "application/zip"
                                putExtra(Intent.EXTRA_TITLE, name.replace('/', '_'))
                            }
                            activity.startActivityForResult(intent, EXPORT_REQUEST)
                        } catch (e: Exception) {
                            clearPending()?.error("SAF_EXPORT", e.message, null)
                        }
                    }
                    "importZip" -> {
                        pending = result
                        pendingAction = "importZip"
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            activity.startActivityForResult(intent, IMPORT_REQUEST)
                        } catch (e: Exception) {
                            clearPending()?.error("SAF_IMPORT", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun clearPending(): MethodChannel.Result? {
        val reply = pending
        pending = null
        pendingAction = null
        pendingExportPath = null
        return reply
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != EXPORT_REQUEST && requestCode != IMPORT_REQUEST) return false
        val result = pending ?: return true
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            clearPending()
            if (requestCode == EXPORT_REQUEST) result.success(false) else result.success(null)
            return true
        }
        val uri: Uri = data.data!!
        val action = pendingAction
        val exportFile = pendingExportPath
        clearPending()
        worker.execute {
            var importedFile: File? = null
            try {
                if (action == "exportZip" && exportFile != null) {
                    val output = activity.contentResolver.openOutputStream(uri, "wt")
                        ?: throw IllegalStateException("Unable to open destination")
                    FileInputStream(File(exportFile)).use { input ->
                        output.use { target -> input.copyTo(target, 128 * 1024) }
                    }
                    activity.runOnUiThread { result.success(true) }
                } else if (action == "importZip") {
                    val directory = File(activity.cacheDir, "resaneh_backup_imports")
                    if (!directory.exists()) directory.mkdirs()
                    val localFile = File(directory, "${UUID.randomUUID()}.zip")
                    importedFile = localFile
                    val input = activity.contentResolver.openInputStream(uri)
                        ?: throw IllegalStateException("Unable to open backup")
                    input.use { source ->
                        FileOutputStream(localFile).use { output ->
                            source.copyTo(output, 128 * 1024)
                            output.fd.sync()
                        }
                    }
                    val finished = localFile.absolutePath
                    activity.runOnUiThread { result.success(finished) }
                } else {
                    throw IllegalStateException("Unexpected document request")
                }
            } catch (error: Exception) {
                importedFile?.delete()
                activity.runOnUiThread {
                    result.error("DOCUMENT_IO", error.message ?: "Document transfer failed", null)
                }
            }
        }
        return true
    }

    fun shutdown() { worker.shutdown() }
}
