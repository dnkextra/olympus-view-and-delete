import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:olympus_tg6_manager/services/jpeg_compressor.dart';

image.Image _noise({int size = 300}) {
  final source = image.Image(width: size, height: size);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      source.setPixelRgb(x, y, x * y % 256, x * 7 % 256, y * 11 % 256);
    }
  }
  return source;
}

void main() {
  test('compresses a JPEG to at most the requested byte size', () async {
    final original = image.encodeJpg(_noise(), quality: 100);
    final target = original.length * 3 ~/ 4;

    final compressed = await compressJpegToTarget(original, target);

    expect(compressed.length, lessThanOrEqualTo(target));
    expect(image.decodeJpg(compressed), isNotNull);
  });

  test('falls back to the quality floor when the target is unreachable',
      () async {
    final original = image.encodeJpg(_noise(), quality: 100);

    final compressed = await compressJpegToTarget(original, 1);

    expect(compressed.length, lessThan(original.length));
    expect(image.decodeJpg(compressed), isNotNull);
    expect(
      compressed.length,
      image.encodeJpg(
        image.decodeJpg(original)!,
        quality: kMinJpegQuality,
        chroma: image.JpegChroma.yuv420,
      ).length,
    );
  });

  test('keeps bytes already at or below the target untouched', () async {
    final bytes = image.encodeJpg(image.Image(width: 1, height: 1));

    expect(await compressJpegToTarget(bytes, bytes.length), same(bytes));
    expect(await compressJpegToTarget(bytes, null), same(bytes));
    expect(await compressJpegToTarget(bytes, 0), same(bytes));
  });

  test('carries EXIF through the re-encode', () async {
    final source = _noise();
    source.exif.imageIfd['Model'] = 'TG-6';
    source.exif.exifIfd['DateTimeOriginal'] = '2024:01:02 03:04:05';
    final original = image.encodeJpg(source, quality: 100);

    final compressed =
        await compressJpegToTarget(original, original.length * 3 ~/ 4);

    final decoded = image.decodeJpg(Uint8List.fromList(compressed))!;
    expect(decoded.exif.imageIfd['Model'].toString(), 'TG-6');
    expect(decoded.exif.exifIfd['DateTimeOriginal'].toString(),
        '2024:01:02 03:04:05');
  });

  test('only .jpg/.jpeg names are treated as JPEG', () {
    expect(isJpegFilename('P1000123.JPG'), isTrue);
    expect(isJpegFilename('P1000123.jpeg'), isTrue);
    expect(isJpegFilename('P1000123.ORF'), isFalse);
    expect(isJpegFilename('P1000123.orf'), isFalse);
  });
}
