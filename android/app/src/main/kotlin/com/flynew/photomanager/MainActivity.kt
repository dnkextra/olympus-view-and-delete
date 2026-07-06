package com.flynew.photomanager

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
