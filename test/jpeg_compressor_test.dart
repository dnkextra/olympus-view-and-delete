import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:olympus_tg6_manager/services/jpeg_compressor.dart';

void main() {
  test('compresses a JPEG toward the requested byte size', () async {
    final source = image.Image(width: 300, height: 300);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(x, y, x * y % 256, x * 7 % 256, y * 11 % 256);
      }
    }
    final original = image.encodeJpg(source, quality: 100);
    final target = original.length * 3 ~/ 4;

    final compressed = await compressJpegToTarget(original, target);

    expect(compressed.length, lessThanOrEqualTo(target));
    expect(image.decodeJpg(Uint8List.fromList(compressed)), isNotNull);

    final bestEffort = await compressJpegToTarget(original, 1);
    expect(bestEffort.length, lessThan(original.length));
  });

  test('keeps JPEG bytes already below the target unchanged', () async {
    final bytes = image.encodeJpg(image.Image(width: 1, height: 1));

    expect(await compressJpegToTarget(bytes, bytes.length), same(bytes));
  });
}
