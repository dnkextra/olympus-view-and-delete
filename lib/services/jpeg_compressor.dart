import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

Future<List<int>> compressJpegToTarget(
  List<int> bytes,
  int? targetBytes,
) async {
  if (targetBytes == null || bytes.length <= targetBytes) return bytes;
  return compute(
    _compressJpeg,
    (bytes: bytes, targetBytes: targetBytes),
  );
}

List<int> _compressJpeg(({List<int> bytes, int targetBytes}) input) {
  final decoded = image.decodeJpg(Uint8List.fromList(input.bytes));
  if (decoded == null) return input.bytes;

  var low = 5;
  var high = 95;
  var best = image.encodeJpg(decoded, quality: low);
  while (low <= high) {
    final quality = (low + high) ~/ 2;
    final candidate = image.encodeJpg(decoded, quality: quality);
    if (candidate.length <= input.targetBytes) {
      best = candidate;
      low = quality + 1;
    } else {
      high = quality - 1;
    }
  }
  return best.length < input.bytes.length ? best : input.bytes;
}
