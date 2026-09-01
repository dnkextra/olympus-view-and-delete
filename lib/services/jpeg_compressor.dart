import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Lowest/highest JPEG quality the size search considers. Below [kMinJpegQuality]
/// the result stops looking like a photo, so a file that cannot reach the target
/// is saved at that quality instead of going lower. The Kotlin
/// background-download compressor uses the same bounds and the same search,
/// so both download paths land on comparable output.
const int kMinJpegQuality = 40;
const int kMaxJpegQuality = 95;

bool isJpegFilename(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
}

/// Re-encodes [bytes] so the result fits in [targetBytes].
///
/// Returns the input unchanged when no target is set, the target is not
/// positive, the data already fits, or the JPEG cannot be decoded. Pixel
/// dimensions are never changed; only the JPEG quality varies.
Future<Uint8List> compressJpegToTarget(
  List<int> bytes,
  int? targetBytes,
) async {
  final source = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  if (targetBytes == null || targetBytes <= 0 || source.length <= targetBytes) {
    return source;
  }
  return compute(
    _compressJpeg,
    (bytes: source, targetBytes: targetBytes),
  );
}

Uint8List _compressJpeg(({Uint8List bytes, int targetBytes}) input) {
  final decoded = image.decodeJpg(input.bytes);
  if (decoded == null) return input.bytes;

  // decodeJpg copies the source EXIF onto the decoded image and encodeJpg
  // writes it back out, so the tags survive the round trip. decodeJpg also
  // bakes the orientation into the pixels and clears the orientation tag,
  // which swaps width/height for orientations 5-8, so the dimension tags have
  // to be refreshed from the decoded image.
  _syncExifDimensions(decoded);

  // Highest quality whose output still fits the target. If even the lowest
  // quality overshoots, the file is saved at that lowest quality anyway.
  var low = kMinJpegQuality;
  var high = kMaxJpegQuality;
  Uint8List? best;
  while (low <= high) {
    final quality = (low + high) ~/ 2;
    final candidate = _encode(decoded, quality);
    if (candidate.length <= input.targetBytes) {
      best = candidate;
      low = quality + 1;
    } else {
      high = quality - 1;
    }
  }
  return best ?? _encode(decoded, kMinJpegQuality);
}

// 4:2:0 chroma subsampling matches Android's Bitmap.compress, so the two
// implementations produce similarly sized files at the same quality.
Uint8List _encode(image.Image decoded, int quality) =>
    image.encodeJpg(decoded, quality: quality, chroma: image.JpegChroma.yuv420);

void _syncExifDimensions(image.Image decoded) {
  final exif = decoded.exif;
  if (exif.isEmpty) return;
  if (exif.imageIfd.imageWidth != null) {
    exif.imageIfd.imageWidth = decoded.width;
  }
  if (exif.imageIfd.imageHeight != null) {
    exif.imageIfd.imageHeight = decoded.height;
  }
  if (exif.exifIfd['ExifImageWidth'] != null) {
    exif.exifIfd['ExifImageWidth'] = decoded.width;
  }
  if (exif.exifIfd['ExifImageLength'] != null) {
    exif.exifIfd['ExifImageLength'] = decoded.height;
  }
}
