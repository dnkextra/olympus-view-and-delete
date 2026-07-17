import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/l10n/l10n.dart';
import 'package:olympus_tg6_manager/screens/home_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/locale_controller.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCameraApi extends CameraApi {
  _FakeCameraApi(this.files);

  final List<CameraFile> files;
  final Completer<List<CameraFile>> _loadCompleter = Completer();
  bool listRequested = false;

  @override
  Future<bool> testConnection(
      {Duration timeout = const Duration(seconds: 5)}) async {
    return true;
  }

  @override
  Future<Map<String, String>> getCameraInfo() async {
    return const {'model': 'Test camera'};
  }

  @override
  Future<List<CameraFile>> listAllFiles({
    void Function(List<CameraFile>)? onBatch,
  }) {
    listRequested = true;
    return _loadCompleter.future;
  }

  void completeLoad() => _loadCompleter.complete(files);

  @override
  void dispose() {}
}

CameraFile _file(String name) {
  return CameraFile(
    directory: '/DCIM/100OLYMP',
    filename: name,
    size: 1024,
    attributes: 0,
    dateRaw: 0,
    timeRaw: 0,
    date: DateTime(2024, 6, 1, 12),
  );
}

Future<void> _pumpHome(
  WidgetTester tester,
  CameraFile file,
) async {
  final api = _FakeCameraApi([file]);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: localizationsDelegates,
      supportedLocales: L10n.all,
      home: HomeScreen(
        localeController: LocaleController(),
        api: api,
      ),
    ),
  );
  for (var i = 0; i < 5 && !api.listRequested; i++) {
    await tester.pump();
  }
  expect(api.listRequested, isTrue);
  ThumbnailManager.instance.debugPutInMemCache(
    file.thumbnailUrl,
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  api.completeLoad();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CameraFile file;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    file = _file('P0000001.JPG');
  });

  testWidgets('deselecting the last file exits selection mode', (tester) async {
    await _pumpHome(tester, file);

    await tester.longPress(find.text(file.filename));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text(file.filename));
    await tester.pump();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Test camera'), findsOneWidget);
    expect(find.byTooltip('Deselect all'), findsNothing);
  });

  testWidgets('deselect all exits selection mode', (tester) async {
    await _pumpHome(tester, file);

    await tester.longPress(find.text(file.filename));
    await tester.pump();
    await tester.tap(find.byTooltip('Deselect all'));
    await tester.pump();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Test camera'), findsOneWidget);
  });
}
