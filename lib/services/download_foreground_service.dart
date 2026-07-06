import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';

class DownloadForegroundService {
  DownloadForegroundService._();

  static const _channel =
      MethodChannel('olympus_view/download_foreground_service');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start({
    required int total,
    String currentFile = '',
  }) {
    return _call('start', done: 0, total: total, currentFile: currentFile);
  }

  static Future<void> update({
    required int done,
    required int total,
    required String currentFile,
  }) {
    return _call(
      'update',
      done: done,
      total: total,
      currentFile: currentFile,
    );
  }

  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e, st) {
      AppLogger.warning(
        'failed to stop download foreground service',
        name: 'download_service',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _call(
    String method, {
    required int done,
    required int total,
    required String currentFile,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, {
        'title': 'Downloading camera files',
        'text': currentFile.isEmpty ? 'Preparing download...' : currentFile,
        'done': done,
        'total': total,
      });
    } on PlatformException catch (e, st) {
      AppLogger.warning(
        'failed to $method download foreground service',
        name: 'download_service',
        error: e,
        stackTrace: st,
      );
    }
  }
}
