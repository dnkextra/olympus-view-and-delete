from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"marker not found in {path}: {old[:120]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# ---------------------------------------------------------------------------
# Local build script: only this branch is allowed to masquerade as 1.3.4+13.
# Source versions remain 1.3.5+14 so release/master metadata stays truthful.
# ---------------------------------------------------------------------------
replace_once(
    "build_release.cmd",
    '''if /I not "!GIT_BRANCH!"=="master" (\n  echo ERROR: build_release.cmd only builds the repository master branch.\n  echo Current branch: !GIT_BRANCH!\n  echo.\n  echo Run:\n  echo   git switch master\n  echo   git pull --ff-only\n  echo   build_release.cmd\n  goto :failed\n)''',
    '''set "TEST_UPDATE_BUILD=0"\nif /I "!GIT_BRANCH!"=="agent/update-progress-test" set "TEST_UPDATE_BUILD=1"\nif /I not "!GIT_BRANCH!"=="master" if "!TEST_UPDATE_BUILD!"=="0" (\n  echo ERROR: build_release.cmd only builds master or agent/update-progress-test.\n  echo Current branch: !GIT_BRANCH!\n  goto :failed\n)''',
)
replace_once(
    "build_release.cmd",
    '''if not defined BUILD_NAME goto :bad_version\nif not defined BUILD_NUMBER goto :bad_version\n\ngoto :version_ok''',
    '''if not defined BUILD_NAME goto :bad_version\nif not defined BUILD_NUMBER goto :bad_version\n\nif "!TEST_UPDATE_BUILD!"=="1" (\n  echo [test] Updater E2E branch: overriding APK manifest version to 1.3.4+13.\n  set "BUILD_NAME=1.3.4"\n  set "BUILD_NUMBER=13"\n)\n\ngoto :version_ok''',
)
replace_once(
    "build_release.cmd",
    "echo App version   : !BUILD_NAME! (build !BUILD_NUMBER!)",
    "echo App version   : !BUILD_NAME! (build !BUILD_NUMBER!)\nif \"!TEST_UPDATE_BUILD!\"==\"1\" echo TEST MODE     : public latest remains v1.3.5; this APK intentionally reports v1.3.4+13",
)
replace_once(
    "build_release.cmd",
    "echo ERROR: APK versionCode does not match pubspec build !BUILD_NUMBER!.",
    "echo ERROR: APK versionCode does not match requested build !BUILD_NUMBER!.",
)
replace_once(
    "build_release.cmd",
    "echo ERROR: APK versionName does not match pubspec version !BUILD_NAME!.",
    "echo ERROR: APK versionName does not match requested version !BUILD_NAME!.",
)

# ---------------------------------------------------------------------------
# Dart service: expose DownloadManager progress/status/install/cancel.
# ---------------------------------------------------------------------------
replace_once(
    "lib/services/app_update_service.dart",
    "class AppUpdateService {",
    '''class AppUpdateDownloadStatus {\n  const AppUpdateDownloadStatus({\n    required this.state,\n    required this.version,\n    required this.downloadedBytes,\n    required this.totalBytes,\n    required this.reason,\n  });\n\n  factory AppUpdateDownloadStatus.fromMap(Map<String, dynamic>? map) {\n    int asInt(Object? value) {\n      if (value is int) return value;\n      return int.tryParse(value?.toString() ?? '') ?? 0;\n    }\n\n    return AppUpdateDownloadStatus(\n      state: map?['state']?.toString() ?? 'none',\n      version: map?['version']?.toString() ?? '',\n      downloadedBytes: asInt(map?['downloadedBytes']),\n      totalBytes: asInt(map?['totalBytes']),\n      reason: map?['reason']?.toString() ?? '',\n    );\n  }\n\n  final String state;\n  final String version;\n  final int downloadedBytes;\n  final int totalBytes;\n  final String reason;\n\n  bool get isActive =>\n      state == 'pending' || state == 'running' || state == 'paused';\n  bool get isReady => state == 'successful';\n  bool get isFailed => state == 'failed';\n  bool get isIdle => state == 'none';\n\n  double? get progress {\n    if (totalBytes <= 0) return null;\n    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);\n  }\n}\n\nclass AppUpdateService {''',
)
replace_once(
    "lib/services/app_update_service.dart",
    "  static String _cleanReleaseNotes(String raw) {",
    '''  static Future<AppUpdateDownloadStatus> getUpdateDownloadStatus() async {\n    if (!supportsExternalUpdates) {\n      return const AppUpdateDownloadStatus(\n        state: 'none',\n        version: '',\n        downloadedBytes: 0,\n        totalBytes: 0,\n        reason: '',\n      );\n    }\n    try {\n      final status = await _channel.invokeMapMethod<String, dynamic>(\n        'getUpdateDownloadStatus',\n      );\n      return AppUpdateDownloadStatus.fromMap(status);\n    } on PlatformException catch (error) {\n      AppLogger.debug(\n        'update status lookup failed: $error',\n        name: 'app_update',\n      );\n      return const AppUpdateDownloadStatus(\n        state: 'none',\n        version: '',\n        downloadedBytes: 0,\n        totalBytes: 0,\n        reason: '',\n      );\n    }\n  }\n\n  static Future<bool> installDownloadedUpdate() async {\n    if (!supportsExternalUpdates) return false;\n    return await _channel.invokeMethod<bool>('installDownloadedUpdate') ?? false;\n  }\n\n  static Future<void> cancelUpdateDownload() async {\n    if (!supportsExternalUpdates) return;\n    await _channel.invokeMethod<void>('cancelUpdateDownload');\n  }\n\n  static String _cleanReleaseNotes(String raw) {''',
)

# ---------------------------------------------------------------------------
# Android bridge routes.
# ---------------------------------------------------------------------------
replace_once(
    "android/app/src/main/kotlin/com/flynew/photomanager/MainActivity.kt",
    '''                    "startUpdateDownload" -> {''',
    '''                    "getUpdateDownloadStatus" -> {\n                        result.success(UpdateDownloadReceiver.status(this))\n                    }\n                    "installDownloadedUpdate" -> {\n                        result.success(UpdateDownloadReceiver.install(this))\n                    }\n                    "cancelUpdateDownload" -> {\n                        UpdateDownloadReceiver.cancel(this)\n                        result.success(null)\n                    }\n                    "startUpdateDownload" -> {''',
)

# ---------------------------------------------------------------------------
# Native DownloadManager tracking. Keep successful ID until the installed app
# reaches the target version, so the UI can offer Install even if notification
# permission is denied or the completion broadcast was missed by the user.
# ---------------------------------------------------------------------------
Path("android/app/src/main/kotlin/com/flynew/photomanager/UpdateDownloadReceiver.kt").write_text(r'''package com.flynew.photomanager

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
''', encoding="utf-8")

# ---------------------------------------------------------------------------
# Home screen: update download gets its own visible state and blocks camera
# auto-connect until it completes/cancels. Notifications become optional.
# ---------------------------------------------------------------------------
replace_once(
    "lib/screens/home_screen.dart",
    '''  AppReleaseInfo? _pendingUpdateAfterPermission;''',
    '''  AppReleaseInfo? _pendingUpdateAfterPermission;\n  Timer? _appUpdatePollTimer;\n  AppUpdateDownloadStatus? _appUpdateStatus;\n  bool _updateInstallIntentOpened = false;''',
)
replace_once(
    "lib/screens/home_screen.dart",
    '''    _downloadPollTimer?.cancel();\n    _batchFlushTimer?.cancel();''',
    '''    _downloadPollTimer?.cancel();\n    _appUpdatePollTimer?.cancel();\n    _batchFlushTimer?.cancel();''',
)
replace_once(
    "lib/screens/home_screen.dart",
    '''      unawaited(_refreshDownloadedHistory());\n      unawaited(_resumePendingUpdate());\n      unawaited(_resumeBackgroundMonitor());''',
    '''      unawaited(_refreshDownloadedHistory());\n      unawaited(_resumePendingUpdate());\n      unawaited(_resumeAppUpdateMonitor());\n      unawaited(_resumeBackgroundMonitor());''',
)
replace_once(
    "lib/screens/home_screen.dart",
    '''  Future<void> _startApp() async {\n    await _refreshDownloadedHistory();\n    await _checkForAppUpdate();\n    if (mounted) unawaited(_initLoad());\n  }''',
    '''  Future<void> _startApp() async {\n    await _refreshDownloadedHistory();\n\n    final existingUpdate = await AppUpdateService.getUpdateDownloadStatus();\n    if (existingUpdate.isActive || existingUpdate.isReady || existingUpdate.isFailed) {\n      if (!mounted) return;\n      setState(() => _appUpdateStatus = existingUpdate);\n      if (existingUpdate.isActive) _startAppUpdateMonitor();\n      if (existingUpdate.isReady) {\n        unawaited(_openDownloadedUpdateInstaller());\n      }\n      return;\n    }\n\n    await _checkForAppUpdate();\n    final startedUpdate = await AppUpdateService.getUpdateDownloadStatus();\n    if (startedUpdate.isActive || startedUpdate.isReady || startedUpdate.isFailed) {\n      if (!mounted) return;\n      setState(() => _appUpdateStatus = startedUpdate);\n      if (startedUpdate.isActive) _startAppUpdateMonitor();\n      if (startedUpdate.isReady) {\n        unawaited(_openDownloadedUpdateInstaller());\n      }\n      return;\n    }\n\n    if (mounted) unawaited(_initLoad());\n  }''',
)
replace_once(
    "lib/screens/home_screen.dart",
    '''    final notifications = await Permission.notification.request();\n    if (!notifications.isGranted) {\n      if (mounted) {\n        _showSnack(_localizedText(\n          en: 'Notifications are required so Olympus View can tell you when the update is ready to install.',\n          ru: 'Разрешите уведомления, чтобы Olympus View сообщил, когда обновление будет готово к установке.',\n          uk: 'Дозвольте сповіщення, щоб Olympus View повідомив, коли оновлення буде готове до встановлення.',\n        ));\n      }\n      return;\n    }\n    await AppUpdateService.startUpdateDownload(release);''',
    '''    final notifications = await Permission.notification.request();\n    if (!notifications.isGranted && mounted) {\n      _showSnack(_localizedText(\n        en: 'Notifications are off. Download progress and the Install button will remain visible in Olympus View.',\n        ru: 'Уведомления отключены. Прогресс и кнопка установки будут видны прямо в Olympus View.',\n        uk: 'Сповіщення вимкнені. Прогрес і кнопка встановлення будуть видимі прямо в Olympus View.',\n      ));\n    }\n    await AppUpdateService.startUpdateDownload(release);''',
)
replace_once(
    "lib/screens/home_screen.dart",
    '''    _pendingUpdateAfterPermission = null;\n    _showSnack(_localizedText(\n      en: 'Update is downloading in the background. Tap the notification when it is ready to install.',\n      ru: 'Обновление скачивается в фоне. Когда оно будет готово, нажмите уведомление для установки.',\n      uk: 'Оновлення завантажується у фоні. Коли воно буде готове, натисніть сповіщення для встановлення.',\n    ));\n  }''',
    '''    _pendingUpdateAfterPermission = null;\n    await _refreshAppUpdateStatus();\n    _startAppUpdateMonitor();\n    _showSnack(_localizedText(\n      en: 'Update download started. Camera auto-connect is paused until it finishes.',\n      ru: 'Скачивание обновления началось. Автоподключение к камере приостановлено до завершения.',\n      uk: 'Завантаження оновлення почалося. Автопідключення до камери призупинено до завершення.',\n    ));\n  }''',
)

insert_marker = '''  void _startBackgroundDownloadMonitor() {'''
insert_block = r'''  void _startAppUpdateMonitor() {
    _appUpdatePollTimer?.cancel();
    _appUpdatePollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshAppUpdateStatus(openInstallerWhenReady: true));
    });
  }

  Future<void> _refreshAppUpdateStatus({bool openInstallerWhenReady = false}) async {
    final status = await AppUpdateService.getUpdateDownloadStatus();
    if (!mounted) return;

    setState(() {
      _appUpdateStatus = status.isIdle ? null : status;
    });

    if (status.isActive) return;
    _appUpdatePollTimer?.cancel();
    _appUpdatePollTimer = null;

    if (status.isReady && openInstallerWhenReady) {
      await _openDownloadedUpdateInstaller();
    }
  }

  Future<void> _resumeAppUpdateMonitor() async {
    final status = await AppUpdateService.getUpdateDownloadStatus();
    if (!mounted || status.isIdle) return;
    setState(() => _appUpdateStatus = status);
    if (status.isActive) {
      _startAppUpdateMonitor();
    } else if (status.isReady) {
      await _openDownloadedUpdateInstaller();
    }
  }

  Future<void> _openDownloadedUpdateInstaller() async {
    if (_updateInstallIntentOpened) return;
    _updateInstallIntentOpened = true;
    final opened = await AppUpdateService.installDownloadedUpdate();
    if (!opened && mounted) {
      _updateInstallIntentOpened = false;
      _showSnack(_localizedText(
        en: 'The installer could not be opened. Use the Install button to try again.',
        ru: 'Не удалось открыть установщик. Нажмите кнопку «Установить», чтобы повторить.',
        uk: 'Не вдалося відкрити інсталятор. Натисніть «Встановити», щоб повторити.',
      ));
    }
  }

  Future<void> _cancelAppUpdateAndConnect() async {
    _appUpdatePollTimer?.cancel();
    _appUpdatePollTimer = null;
    await AppUpdateService.cancelUpdateDownload();
    if (!mounted) return;
    setState(() {
      _appUpdateStatus = null;
      _updateInstallIntentOpened = false;
    });
    unawaited(_initLoad());
  }

  Future<void> _retryAppUpdate() async {
    await AppUpdateService.cancelUpdateDownload();
    if (!mounted) return;
    setState(() {
      _appUpdateStatus = null;
      _updateInstallIntentOpened = false;
    });
    await _checkForAppUpdate();
    await _refreshAppUpdateStatus();
    if (_appUpdateStatus?.isActive == true) {
      _startAppUpdateMonitor();
    }
  }

'''
replace_once("lib/screens/home_screen.dart", insert_marker, insert_block + insert_marker)

ui_marker = '''  @override\n  Widget build(BuildContext context) {'''
ui_block = r'''  String _formatUpdateBytes(int value) {
    if (value <= 0) return '0 MB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildAppUpdateScreen(AppUpdateDownloadStatus status) {
    final progress = status.progress;
    final percent = progress == null ? null : (progress * 100).round();

    String title;
    String message;
    IconData icon;
    if (status.isReady) {
      title = _localizedText(
        en: 'Update downloaded',
        ru: 'Обновление скачано',
        uk: 'Оновлення завантажено',
      );
      message = _localizedText(
        en: 'Olympus View ${status.version} is ready to install.',
        ru: 'Olympus View ${status.version} готов к установке.',
        uk: 'Olympus View ${status.version} готовий до встановлення.',
      );
      icon = Icons.system_update_alt;
    } else if (status.isFailed) {
      title = _localizedText(
        en: 'Update download failed',
        ru: 'Ошибка скачивания обновления',
        uk: 'Помилка завантаження оновлення',
      );
      message = _localizedText(
        en: 'The APK could not be downloaded. Check the internet connection and retry.',
        ru: 'Не удалось скачать APK. Проверьте подключение к интернету и повторите.',
        uk: 'Не вдалося завантажити APK. Перевірте інтернет і повторіть.',
      );
      icon = Icons.error_outline;
    } else if (status.state == 'paused') {
      title = _localizedText(
        en: 'Update paused',
        ru: 'Обновление приостановлено',
        uk: 'Оновлення призупинено',
      );
      message = status.reason == 'waiting_for_network'
          ? _localizedText(
              en: 'Waiting for internet. Do not connect to the camera Wi-Fi until the APK finishes downloading.',
              ru: 'Ожидание интернета. Не подключайтесь к Wi‑Fi камеры, пока APK не будет скачан.',
              uk: 'Очікування інтернету. Не підключайтеся до Wi‑Fi камери, доки APK не завантажиться.',
            )
          : _localizedText(
              en: 'Android paused the download and will retry automatically.',
              ru: 'Android приостановил скачивание и автоматически попробует снова.',
              uk: 'Android призупинив завантаження та автоматично спробує знову.',
            );
      icon = Icons.wifi_off;
    } else {
      title = _localizedText(
        en: 'Downloading update',
        ru: 'Скачивание обновления',
        uk: 'Завантаження оновлення',
      );
      message = _localizedText(
        en: 'Keep an internet connection. Camera auto-connect is temporarily disabled.',
        ru: 'Оставьте подключение к интернету. Автоподключение к камере временно отключено.',
        uk: 'Залиште підключення до інтернету. Автопідключення до камери тимчасово вимкнено.',
      );
      icon = Icons.downloading;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Olympus View')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: kPrimaryColor),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (status.isActive) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text(
                    status.totalBytes > 0
                        ? '${_formatUpdateBytes(status.downloadedBytes)} / ${_formatUpdateBytes(status.totalBytes)}${percent == null ? '' : '  ($percent%)'}'
                        : _localizedText(
                            en: 'Preparing download…',
                            ru: 'Подготовка скачивания…',
                            uk: 'Підготовка завантаження…',
                          ),
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
                const SizedBox(height: 28),
                if (status.isReady)
                  FilledButton.icon(
                    onPressed: () {
                      _updateInstallIntentOpened = false;
                      unawaited(_openDownloadedUpdateInstaller());
                    },
                    icon: const Icon(Icons.install_mobile),
                    label: Text(_localizedText(
                      en: 'Install ${status.version}',
                      ru: 'Установить ${status.version}',
                      uk: 'Встановити ${status.version}',
                    )),
                  ),
                if (status.isFailed)
                  FilledButton.icon(
                    onPressed: _retryAppUpdate,
                    icon: const Icon(Icons.refresh),
                    label: Text(_localizedText(
                      en: 'Retry', ru: 'Повторить', uk: 'Повторити')),
                  ),
                if (!status.isReady) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cancelAppUpdateAndConnect,
                    child: Text(_localizedText(
                      en: 'Cancel update and connect to camera',
                      ru: 'Отменить обновление и подключиться к камере',
                      uk: 'Скасувати оновлення і підключитися до камери',
                    )),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appUpdate = _appUpdateStatus;
    if (appUpdate != null && !appUpdate.isIdle) {
      return _buildAppUpdateScreen(appUpdate);
    }
'''
replace_once("lib/screens/home_screen.dart", ui_marker, ui_block)

# Small unit coverage for native-map parsing/progress arithmetic.
replace_once(
    "test/app_update_service_test.dart",
    '''void main() {''',
    '''void main() {\n  group('AppUpdateDownloadStatus', () {\n    test('parses progress from the Android channel map', () {\n      final status = AppUpdateDownloadStatus.fromMap(<String, dynamic>{\n        'state': 'running',\n        'version': '1.3.5',\n        'downloadedBytes': 25,\n        'totalBytes': 100,\n        'reason': '',\n      });\n\n      expect(status.isActive, isTrue);\n      expect(status.isReady, isFalse);\n      expect(status.progress, 0.25);\n    });\n\n    test('recognizes waiting-for-network pause', () {\n      final status = AppUpdateDownloadStatus.fromMap(<String, dynamic>{\n        'state': 'paused',\n        'version': '1.3.5',\n        'downloadedBytes': 10,\n        'totalBytes': 100,\n        'reason': 'waiting_for_network',\n      });\n\n      expect(status.isActive, isTrue);\n      expect(status.reason, 'waiting_for_network');\n    });\n  });\n''',
)

print("Updater progress test branch patch applied")
