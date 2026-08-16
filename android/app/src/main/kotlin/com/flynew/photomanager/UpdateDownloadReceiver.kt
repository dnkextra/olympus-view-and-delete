package com.flynew.photomanager

import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment

class UpdateDownloadReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return

        val completedId = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pendingId = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
        if (completedId <= 0 || completedId != pendingId) return

        val manager = context.getSystemService(DownloadManager::class.java)
        val query = DownloadManager.Query().setFilterById(completedId)
        manager.query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) return
            val downloadStatus = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
            )
            val version = prefs.getString(KEY_VERSION, "") ?: ""
            if (downloadStatus == DownloadManager.STATUS_SUCCESSFUL) {
                showInstallNotification(context, manager, completedId, version)
            } else if (downloadStatus == DownloadManager.STATUS_FAILED) {
                showFailureNotification(context, version)
            }
        }
    }

    private fun showInstallNotification(
        context: Context,
        manager: DownloadManager,
        downloadId: Long,
        version: String,
    ) {
        val apkUri = manager.getUriForDownloadedFile(downloadId) ?: return
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, APK_MIME)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            4201,
            installIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        ensureChannel(context)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val title = if (version.isBlank()) {
            "Olympus View update ready"
        } else {
            "Olympus View $version is ready"
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle(title)
            .setContentText("Tap to install the downloaded update")
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    private fun showFailureNotification(context: Context, version: String) {
        ensureChannel(context)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val suffix = if (version.isBlank()) "" else " $version"
        val notification = builder
            .setSmallIcon(R.drawable.ic_download_notification)
            .setContentTitle("Olympus View$suffix update failed")
            .setContentText("Open the app and try again when internet is available")
            .setAutoCancel(true)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification)
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Application updates",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Alerts when an Olympus View APK update is ready"
            enableVibration(true)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    companion object {
        private const val PREFS_NAME = "olympus_app_update"
        private const val KEY_DOWNLOAD_ID = "download_id"
        private const val KEY_VERSION = "version"
        private const val APK_MIME = "application/vnd.android.package-archive"
        private const val CHANNEL_ID = "olympus_app_updates"
        private const val NOTIFICATION_ID = 4202

        fun enqueue(context: Context, url: String, version: String): Long {
            cancel(context)
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle("Olympus View $version")
                .setDescription("Downloading application update")
                .setMimeType(APK_MIME)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(false)
                .setDestinationInExternalFilesDir(
                    context,
                    Environment.DIRECTORY_DOWNLOADS,
                    "OlympusView-$version.apk",
                )

            val manager = context.getSystemService(DownloadManager::class.java)
            val id = manager.enqueue(request)
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_DOWNLOAD_ID, id)
                .putString(KEY_VERSION, version)
                .apply()
            return id
        }

        fun status(context: Context): Map<String, Any?> {
            val manager = context.getSystemService(DownloadManager::class.java)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val id = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
            val version = prefs.getString(KEY_VERSION, "") ?: ""
            if (id <= 0L) return idleStatus(version)

            if (version.isNotBlank() && currentVersionAtLeast(context, version)) {
                cancel(context)
                return idleStatus("")
            }

            val query = DownloadManager.Query().setFilterById(id)
            manager.query(query)?.use { cursor ->
                if (!cursor.moveToFirst()) {
                    prefs.edit().remove(KEY_DOWNLOAD_ID).remove(KEY_VERSION).apply()
                    return idleStatus("")
                }
                val rawStatus = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
                )
                val downloaded = cursor.getLong(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR),
                )
                val total = cursor.getLong(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
                )
                val reason = cursor.getInt(
                    cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
                )
                return mapOf(
                    "state" to stateName(rawStatus),
                    "version" to version,
                    "downloadedBytes" to downloaded.coerceAtLeast(0L),
                    "totalBytes" to total.coerceAtLeast(0L),
                    "reason" to reasonName(rawStatus, reason),
                )
            }
            return idleStatus(version)
        }

        fun install(context: Context): Boolean {
            val manager = context.getSystemService(DownloadManager::class.java)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val id = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
            if (id <= 0L) return false
            val apkUri = manager.getUriForDownloadedFile(id) ?: return false
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, APK_MIME)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            return true
        }

        fun cancel(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val id = prefs.getLong(KEY_DOWNLOAD_ID, -1L)
            if (id > 0L) {
                context.getSystemService(DownloadManager::class.java).remove(id)
            }
            prefs.edit().remove(KEY_DOWNLOAD_ID).remove(KEY_VERSION).apply()
        }

        private fun idleStatus(version: String) = mapOf<String, Any?>(
            "state" to "none",
            "version" to version,
            "downloadedBytes" to 0L,
            "totalBytes" to 0L,
            "reason" to "",
        )

        private fun stateName(status: Int): String = when (status) {
            DownloadManager.STATUS_PENDING -> "pending"
            DownloadManager.STATUS_RUNNING -> "running"
            DownloadManager.STATUS_PAUSED -> "paused"
            DownloadManager.STATUS_SUCCESSFUL -> "successful"
            DownloadManager.STATUS_FAILED -> "failed"
            else -> "none"
        }

        private fun reasonName(status: Int, reason: Int): String {
            if (status == DownloadManager.STATUS_PAUSED) {
                return when (reason) {
                    DownloadManager.PAUSED_WAITING_FOR_NETWORK -> "waiting_for_network"
                    DownloadManager.PAUSED_WAITING_TO_RETRY -> "waiting_to_retry"
                    DownloadManager.PAUSED_QUEUED_FOR_WIFI -> "queued_for_wifi"
                    else -> "paused"
                }
            }
            return if (status == DownloadManager.STATUS_FAILED) "error_$reason" else ""
        }

        private fun currentVersionAtLeast(context: Context, target: String): Boolean {
            @Suppress("DEPRECATION")
            val current = context.packageManager.getPackageInfo(context.packageName, 0)
                .versionName ?: "0.0.0"
            val a = versionParts(current)
            val b = versionParts(target)
            for (i in 0..2) {
                if (a[i] != b[i]) return a[i] > b[i]
            }
            return true
        }

        private fun versionParts(value: String): List<Int> {
            val matches = Regex("\\d+").findAll(value).take(3).map {
                it.value.toIntOrNull() ?: 0
            }.toMutableList()
            while (matches.size < 3) matches += 0
            return matches
        }
    }
}
