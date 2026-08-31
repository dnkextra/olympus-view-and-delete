package com.flynew.photomanager

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URLConnection
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "olympus_view/media_store",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveMedia") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val filename = call.argument<String>("filename")
            val bytes = call.argument<ByteArray>("bytes")
            if (filename == null || bytes == null) {
                result.error("invalid_arguments", "Missing filename or bytes", null)
                return@setMethodCallHandler
            }
            thread {
                try {
                    val saved = saveMedia(filename, bytes)
                    runOnUiThread { result.success(saved) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error("save_failed", error.message, null)
                    }
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "olympus_view/download_foreground_service",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    startDownloadService(call, asForegroundStart = true)
                    result.success(null)
                }
                "update" -> {
                    startDownloadService(call, asForegroundStart = false)
                    result.success(null)
                }
                "stop" -> {
                    stopService(Intent(this, DownloadForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveMedia(filename: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val directory = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
                "OlympusView",
            ).apply { mkdirs() }
            val file = File(directory, filename)
            file.writeBytes(bytes)
            MediaScannerConnection.scanFile(this, arrayOf(file.path), null, null)
            return file.path
        }

        val resolver = contentResolver
        val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val relativePath = "${Environment.DIRECTORY_DCIM}/OlympusView/"
        val selection =
            "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND " +
                "${MediaStore.MediaColumns.RELATIVE_PATH}=?"
        val existing = resolver.query(
            collection,
            arrayOf(MediaStore.MediaColumns._ID),
            selection,
            arrayOf(filename, relativePath),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                android.content.ContentUris.withAppendedId(collection, cursor.getLong(0))
            } else {
                null
            }
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE,
                URLConnection.guessContentTypeFromName(filename) ?: "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = existing ?: resolver.insert(collection, values)
            ?: error("Could not create MediaStore entry")
        if (existing != null) resolver.update(uri, values, null, null)

        try {
            resolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                ?: error("Could not open MediaStore entry")
            resolver.update(uri, ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }, null, null)
        } catch (error: Exception) {
            if (existing == null) {
                resolver.delete(uri, null, null)
            } else {
                resolver.update(uri, ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }, null, null)
            }
            throw error
        }
        return uri.toString()
    }

    private fun startDownloadService(call: MethodCall, asForegroundStart: Boolean) {
        val intent = Intent(this, DownloadForegroundService::class.java)
            .putExtra(
                DownloadForegroundService.EXTRA_TITLE,
                call.argument<String>("title"),
            )
            .putExtra(
                DownloadForegroundService.EXTRA_TEXT,
                call.argument<String>("text"),
            )
            .putExtra(
                DownloadForegroundService.EXTRA_DONE,
                call.argument<Int>("done") ?: 0,
            )
            .putExtra(
                DownloadForegroundService.EXTRA_TOTAL,
                call.argument<Int>("total") ?: 0,
            )

        if (asForegroundStart && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}
