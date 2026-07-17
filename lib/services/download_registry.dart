import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

/// Remembers which camera files have already been downloaded to this device
/// so the UI can show a "downloaded" indicator.
///
/// Keys come from `CameraFile.downloadKey` (path + size + timestamp), so a
/// new photo that reuses a deleted file's name is not falsely marked.
/// The set is persisted in SharedPreferences and kept in memory; listeners
/// are notified when it changes so visible items can update immediately.
class DownloadRegistry extends ChangeNotifier {
  DownloadRegistry._();

  static final DownloadRegistry instance = DownloadRegistry._();

  static const String _prefsKey = 'downloaded_files';

  final Set<String> _keys = <String>{};
  bool _loaded = false;
  Future<void>? _loading;
  bool _dirty = false;
  Future<void>? _writing;
  bool _notifyScheduled = false;

  /// Load persisted keys once; subsequent calls are no-ops.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _keys.addAll(prefs.getStringList(_prefsKey) ?? const []);
    } catch (e, st) {
      AppLogger.warning('failed to load download registry',
          name: 'download_registry', error: e, stackTrace: st);
      _loading = null;
      return;
    }
    _loaded = true;
    notifyListeners();
    if (_dirty) await _persist();
  }

  bool isDownloaded(String key) => _keys.contains(key);

  /// Record a successful download. Safe to call without awaiting.
  Future<void> markDownloaded(String key) async {
    await ensureLoaded();
    final added = _keys.add(key);
    if (added) _scheduleNotify();
    if (!_loaded) {
      if (added) _dirty = true;
      return;
    }
    if (added || _dirty) await _persist();
  }

  /// Coalesces bursts into few writes; awaiting guarantees this mutation is
  /// persisted once loading has succeeded.
  Future<void> _persist() {
    if (!_loaded) return Future<void>.value();
    _dirty = true;
    return _writing ??= _drain();
  }

  Future<void> _drain() async {
    try {
      while (_dirty) {
        _dirty = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          final saved = await prefs.setStringList(_prefsKey, _keys.toList());
          if (!saved) {
            _dirty = true;
            AppLogger.warning('failed to persist download registry',
                name: 'download_registry');
            break;
          }
        } catch (e, st) {
          _dirty = true;
          AppLogger.warning('failed to persist download registry',
              name: 'download_registry', error: e, stackTrace: st);
          break;
        }
      }
    } finally {
      _writing = null;
    }
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// Reset in-memory state so tests can start from clean prefs.
  @visibleForTesting
  void resetForTests() {
    _keys.clear();
    _loaded = false;
    _loading = null;
    _dirty = false;
    _writing = null;
    _notifyScheduled = false;
  }
}
