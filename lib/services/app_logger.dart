import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity levels for [AppLogger].
enum LogLevel { debug, info, warning, error }

/// Lightweight application-wide logger.
///
/// Wraps `dart:developer`'s [developer.log] so messages show up in the
/// IDE / DevTools logging view on all platforms (including web) without the
/// downsides of `print` (which is stripped/linted and has no severity).
///
/// In release builds only [LogLevel.warning] and above are emitted to keep
/// noise (and any potential PII) out of production logs.
class AppLogger {
  AppLogger._();

  /// Minimum level that will actually be emitted. Debug/info are suppressed
  /// in release builds.
  static LogLevel minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  static const int _levelSeverity = 0; // base; offset added per level below.

  static void debug(String message, {String name = 'app'}) =>
      _log(LogLevel.debug, message, name: name);

  static void info(String message, {String name = 'app'}) =>
      _log(LogLevel.info, message, name: name);

  static void warning(String message,
          {String name = 'app', Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.warning, message,
          name: name, error: error, stackTrace: stackTrace);

  static void error(String message,
          {String name = 'app', Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message,
          name: name, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String message, {
    String name = 'app',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    developer.log(
      message,
      name: name,
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Map [LogLevel] to the numeric severity used by `dart:developer`
  /// (loosely based on package:logging levels).
  static int _severity(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500 + _levelSeverity;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
