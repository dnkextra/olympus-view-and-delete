import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/service_config.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';

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
}
