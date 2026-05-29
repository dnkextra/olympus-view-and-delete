import 'dart:async';
import 'dart:io';

import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';
import 'filename_sanitizer.dart';

Future<String> saveFileToDevice(String filename, List<int> bytes, String? dirPath) async {
  final dir = dirPath ?? await getSaveDirectory();
  await ensureDirectory(dir);
  final safe = sanitizeFilename(filename);
  final filePath = '$dir/$safe';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  // Notify Android MediaScanner so file appears in Gallery
  if (Platform.isAndroid) {
    try {
      unawaited(MediaScanner.loadMedia(path: filePath));
    } catch (e) {
      // Non-fatal: file is saved, only the gallery refresh failed.
      AppLogger.debug('MediaScanner.loadMedia failed: $e',
          name: 'file_saver');
    }
  }

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
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
