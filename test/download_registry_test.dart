import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/download_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final registry = DownloadRegistry.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registry.resetForTests();
  });

  test('unknown key is not downloaded', () async {
    await registry.ensureLoaded();
    expect(
        registry.isDownloaded('/DCIM/100OLYMP/P1010001.JPG|123|0|0'), isFalse);
  });

  test('markDownloaded makes key visible immediately', () async {
    await registry.markDownloaded('k1');
    expect(registry.isDownloaded('k1'), isTrue);
    expect(registry.isDownloaded('k2'), isFalse);
  });

  test('marked keys survive a reload from prefs', () async {
    await registry.markDownloaded('k1');
    await registry.markDownloaded('k2');
    // Let the serialized persist writes complete.
    await Future<void>.delayed(Duration.zero);

    registry.resetForTests();
    expect(registry.isDownloaded('k1'), isFalse); // memory cleared
    await registry.ensureLoaded();
    expect(registry.isDownloaded('k1'), isTrue);
    expect(registry.isDownloaded('k2'), isTrue);
  });

  test('marking notifies listeners', () async {
    int notified = 0;
    void listener() => notified++;
    registry.addListener(listener);
    await registry.markDownloaded('k1');
    await Future<void>.delayed(Duration.zero);
    expect(notified, greaterThan(0));
    final before = notified;
    // Re-marking the same key is a no-op and does not notify again.
    await registry.markDownloaded('k1');
    await Future<void>.delayed(Duration.zero);
    expect(notified, before);
    registry.removeListener(listener);
  });

  test('load failure does not overwrite stored value', () async {
    SharedPreferences.setMockInitialValues({
      'downloaded_files': 'not-a-list',
    });
    registry.resetForTests();

    await registry.markDownloaded('k1');

    expect(registry.isDownloaded('k1'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.get('downloaded_files'), 'not-a-list');
  });

  test('a mark is persisted after a transient load failure recovers', () async {
    SharedPreferences.setMockInitialValues({
      'downloaded_files': 'not-a-list',
    });
    registry.resetForTests();

    await registry.markDownloaded('k1');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('downloaded_files', []);
    await registry.markDownloaded('k1');

    registry.resetForTests();
    await registry.ensureLoaded();
    expect(registry.isDownloaded('k1'), isTrue);
  });

  test('concurrent marks are all persisted', () async {
    await Future.wait([
      for (int i = 0; i < 20; i++) registry.markDownloaded('c_$i'),
    ]);
    registry.resetForTests();
    await registry.ensureLoaded();
    for (int i = 0; i < 20; i++) {
      expect(registry.isDownloaded('c_$i'), isTrue, reason: 'c_$i lost');
    }
  });

  test('downloadKey distinguishes reused filenames', () {
    CameraFile file({int size = 100, int dateRaw = 1, int timeRaw = 2}) =>
        CameraFile(
          directory: '/DCIM/100OLYMP',
          filename: 'P1010001.JPG',
          size: size,
          attributes: 0,
          dateRaw: dateRaw,
          timeRaw: timeRaw,
          date: DateTime(2024, 5, 1),
        );

    expect(file().downloadKey, file().downloadKey);
    expect(file().downloadKey, isNot(file(size: 999).downloadKey));
    expect(file().downloadKey, isNot(file(dateRaw: 7).downloadKey));
    expect(file().downloadKey, isNot(file(timeRaw: 9).downloadKey));
  });
}
