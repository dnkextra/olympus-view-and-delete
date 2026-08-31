import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'filename_sanitizer.dart';

const _mediaStore = MethodChannel('olympus_view/media_store');

Future<String> saveFileToDevice(
    String filename, List<int> bytes, String? dirPath) async {
  final safe = sanitizeFilename(filename);
  if (Platform.isAndroid) {
    final uri = await _mediaStore.invokeMethod<String>('saveMedia', {
      'filename': safe,
      'bytes': bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    });
    if (uri == null) throw const FileSystemException('MediaStore save failed');
    return uri;
  }

  final dir = dirPath ?? await getSaveDirectory();
  await ensureDirectory(dir);
  final filePath = '$dir/$safe';
  await File(filePath).writeAsBytes(bytes);
  return filePath;
}

Future<String> getSaveDirectory() async {
  if (Platform.isAndroid) {
    return '/storage/emulated/0/DCIM/OlympusView';
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/OlympusView';
  }
}

Future<void> ensureDirectory(String path) async {
  if (Platform.isAndroid) return;
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
