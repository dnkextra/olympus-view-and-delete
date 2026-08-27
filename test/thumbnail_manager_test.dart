import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:olympus_tg6_manager/services/service_config.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Blocks [ImageDiskCache] initialisation until released, simulating a slow
/// storage layer so queue-vs-disk interleavings are fully deterministic.
/// The cache root is a unique temp directory so one run's disk-cached results
/// can never leak into another run.
class _GatedPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final _release = Completer<void>();
  late final String _root;

  Future<void> dispose() async {
    try {
      await Directory(_root).delete(recursive: true);
    } catch (_) {}
  }

  void release() {
    if (_release.isCompleted) return;
    () async {
      final dir = await Directory.systemTemp.createTemp('olympus_gate_cache_');
      _root = dir.path;
      _release.complete();
    }();
  }

  @override
  Future<String?> getApplicationCachePath() =>
      _release.future.then((_) => _root);
}

/// Simulates a broken storage layer: every cache init attempt fails.
class _ThrowingPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getApplicationCachePath() async =>
      throw StateError('storage unavailable');
}

/// Serves a fixed cache root (pre-created by the test).
class _FixedPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FixedPathProvider(this._root);
  final String _root;

  @override
  Future<String?> getApplicationCachePath() async => _root;
}

Uint8List _validJpeg() => Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

/// Mock camera client that records every requested URL and answers with a
/// structurally valid JPEG (passes isCompleteCameraJpeg).
(http.Client, List<String>) _countingJpegClient() {
  final urls = <String>[];
  final client = MockClient((request) async {
    urls.add(request.url.toString());
    return http.Response.bytes(_validJpeg(), 200);
  });
  return (client, urls);
}

void main() {
  final manager = ThumbnailManager.instance;

  setUp(manager.clear);
  tearDown(manager.clear);

  test('byte cap evicts oldest entries when total exceeds kMaxMemThumbBytes',
      () {
    // Each chunk is a quarter of the byte cap, so the 5th insertion must push
    // total over the cap and evict the oldest.
    final chunk = Uint8List(kMaxMemThumbBytes ~/ 4);
    for (var i = 0; i < 5; i++) {
      manager.debugPutInMemCache('url_$i', chunk);
    }

    expect(manager.memCacheBytes <= kMaxMemThumbBytes, isTrue);
    expect(manager.memCacheCount, lessThan(5));
  });

  test('a single oversized thumbnail is kept (cache never fully empties)', () {
    final huge = Uint8List(kMaxMemThumbBytes * 2);
    manager.debugPutInMemCache('huge', huge);

    expect(manager.memCacheCount, 1);
    expect(manager.memCacheBytes, huge.lengthInBytes);
  });

  test('byte total stays in sync when replacing an existing key', () {
    manager.debugPutInMemCache('a', Uint8List(1000));
    expect(manager.memCacheBytes, 1000);

    manager.debugPutInMemCache('a', Uint8List(250));
    expect(manager.memCacheCount, 1);
    expect(manager.memCacheBytes, 250);
  });

  test('clear resets the byte counter', () {
    manager.debugPutInMemCache('a', Uint8List(500));
    expect(manager.memCacheBytes, 500);

    manager.clear();
    expect(manager.memCacheCount, 0);
    expect(manager.memCacheBytes, 0);
  });

  group('disk-check vs queue race', () {
    const url = 'http://192.168.0.10/get_thumbnail.cgi?DIR=/DCIM/A.JPG';
    const imagePath = '/DCIM/A.JPG|100|0|0';

    test('queue never starts HTTP while a disk lookup is still pending',
        () async {
      final provider = _GatedPathProvider();
      PathProviderPlatform.instance = provider;
      SharedPreferences.setMockInitialValues({});
      await ImageDiskCache.instance.resetForTests();
      try {
        final (client, urls) = _countingJpegClient();
        final isolated = ThumbnailManager.forTesting(client: client);
        isolated.updateVisibleRange(0, 20);

        final done = isolated.load(url, 0, imagePath: imagePath);

        // Deterministic stand-in for any concurrent event that pumps the queue
        // while the disk read is unresolved: another fetch finishing, another
        // request's disk miss, etc. Before the fix this dequeued and fetched
        // the very thumbnail that was about to arrive from disk.
        isolated.pauseNetwork();
        isolated.resumeNetwork();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(urls, isEmpty,
            reason: 'HTTP must not start before the disk check resolves');

        // Disk turns out to be a miss — only now may HTTP start, exactly once.
        provider.release();
        final result = await done;
        expect(result, isNotNull);
        expect(urls, [url]);
      } finally {
        await ImageDiskCache.instance.resetForTests();
        await provider.dispose();
      }
    });

    test('a failed disk lookup falls back to HTTP instead of hanging',
        () async {
      PathProviderPlatform.instance = _ThrowingPathProvider();
      SharedPreferences.setMockInitialValues({});
      await ImageDiskCache.instance.resetForTests();

      final (client, urls) = _countingJpegClient();
      final isolated = ThumbnailManager.forTesting(client: client);

      final result =
          await isolated.load(url, 0, imagePath: '/DCIM/B.JPG|100|0|0');

      expect(result, isNotNull);
      expect(urls, [url]);
    });

    test('HTTP starts immediately when there is no disk identity to check',
        () async {
      final (client, urls) = _countingJpegClient();
      final isolated = ThumbnailManager.forTesting(client: client);

      final result = await isolated.load(url, 0);

      expect(result, isNotNull);
      expect(urls, [url]);
    });
  });

  test(
      'storm of 24 concurrent loads: disk hits never reach HTTP, misses are '
      'fetched exactly once, and the camera slot cap holds', () async {
    final root = await Directory.systemTemp.createTemp('olympus_storm_cache_');
    PathProviderPlatform.instance = _FixedPathProvider(root.path);
    SharedPreferences.setMockInitialValues({});
    await ImageDiskCache.instance.resetForTests();
    try {
      const total = 24;
      // Big overlap: every 3rd file is already on disk from a previous
      // session, so the storm mixes disk lookups with fresh fetches.
      final isSeeded = List.generate(total, (i) => i % 3 == 0);
      for (var i = 0; i < total; i++) {
        if (isSeeded[i]) {
          await ImageDiskCache.instance.put(
            '/DCIM/F$i.JPG|100|0|0',
            'thumb',
            _validJpeg(),
          );
        }
      }

      var inFlight = 0;
      var maxInFlight = 0;
      final urls = <String>[];
      final client = MockClient((request) async {
        urls.add(request.url.toString());
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        try {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        } finally {
          inFlight--;
        }
        return http.Response.bytes(_validJpeg(), 200);
      });
      final isolated = ThumbnailManager.forTesting(client: client);
      isolated.updateVisibleRange(0, total);

      final results = await Future.wait([
        for (var i = 0; i < total; i++)
          isolated.load(
            'http://192.168.0.10/get_thumbnail.cgi?DIR=/DCIM/F$i.JPG',
            i,
            imagePath: '/DCIM/F$i.JPG|100|0|0',
          ),
      ]);

      // Everything completes with usable bytes.
      for (final result in results) {
        expect(result, isNotNull);
      }
      // Per-URL exactly-once semantics under full overlap.
      for (var i = 0; i < total; i++) {
        final expectedUrl =
            'http://192.168.0.10/get_thumbnail.cgi?DIR=/DCIM/F$i.JPG';
        final hits = urls.where((u) => u == expectedUrl).length;
        if (isSeeded[i]) {
          expect(hits, 0, reason: 'seeded F$i.JPG must come from disk');
        } else {
          expect(hits, 1, reason: 'F$i.JPG must be fetched exactly once');
        }
      }
      // The scarce camera connection is never oversubscribed.
      expect(maxInFlight, lessThanOrEqualTo(kMaxConcurrentThumbs));
    } finally {
      await ImageDiskCache.instance.resetForTests();
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    }
  });
}
