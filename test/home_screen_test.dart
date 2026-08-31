import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/constants.dart';
import 'package:olympus_tg6_manager/l10n/l10n.dart';
import 'package:olympus_tg6_manager/screens/home_screen.dart';
import 'package:olympus_tg6_manager/screens/photo_preview_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/connection_history.dart';
import 'package:olympus_tg6_manager/services/download_registry.dart';
import 'package:olympus_tg6_manager/services/locale_controller.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCameraApi extends CameraApi {
  _FakeCameraApi(this.files, {this.connected = true});

  final List<CameraFile> files;
  final bool connected;
  final Completer<List<CameraFile>> _loadCompleter = Completer();
  bool listRequested = false;

  @override
  Future<bool> testConnection(
      {Duration timeout = const Duration(seconds: 5)}) async {
    return connected;
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
  CameraFile file, {
  List<CameraFile>? files,
}) async {
  final api = _FakeCameraApi(files ?? [file]);
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
    DownloadRegistry.instance.resetForTests();
    file = _file('P0000001.JPG');
  });

  testWidgets('multiple saved cameras show the connection choices on startup',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await ConnectionHistory.save(SavedConnection(
      ssid: 'CAMERA_ONE',
      password: 'one',
      lastConnected: DateTime(2024, 1, 1),
    ));
    await ConnectionHistory.save(SavedConnection(
      ssid: 'CAMERA_TWO',
      password: 'two',
      lastConnected: DateTime(2024, 1, 2),
    ));
    final api = _FakeCameraApi([], connected: false);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: localizationsDelegates,
      supportedLocales: L10n.all,
      home: HomeScreen(
        localeController: LocaleController(),
        api: api,
      ),
    ));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(find.text(AppStrings.scanQr), findsOneWidget);
    expect(find.text(AppStrings.savedCameras), findsOneWidget);
    expect(find.text('CAMERA_ONE'), findsOneWidget);
    expect(find.text('CAMERA_TWO'), findsOneWidget);
    expect(api.listRequested, isFalse);
  });

  testWidgets('deselecting the last file exits selection mode', (tester) async {
    await _pumpHome(tester, file);

    await tester.longPress(find.text(file.filename));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Deselect ${file.filename}'));
    await tester.pump();

    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Test camera'), findsOneWidget);
    expect(find.byTooltip('Deselect all'), findsNothing);
  });

  testWidgets('selection circles toggle while image taps open the preview',
      (tester) async {
    final second = _file('P0000002.JPG');
    await _pumpHome(tester, file, files: [file, second]);

    await tester.longPress(find.text(file.filename));
    await tester.pump();
    expect(find.byTooltip('Deselect ${file.filename}'), findsOneWidget);
    expect(find.byTooltip('Select ${second.filename}'), findsOneWidget);

    await tester.tap(find.byTooltip('Select ${second.filename}'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text(file.filename));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final preview = find.byType(PhotoPreviewScreen);
    expect(preview, findsOneWidget);
    expect(
      find.descendant(
        of: preview,
        matching: find.byTooltip('Deselect ${file.filename}'),
      ),
      findsOneWidget,
    );
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

  testWidgets('previously downloaded file shows the downloaded badge',
      (tester) async {
    await DownloadRegistry.instance.markDownloaded(file.downloadKey);
    await _pumpHome(tester, file);

    expect(find.byIcon(Icons.download_done), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('badge appears live when a file is marked downloaded',
      (tester) async {
    await _pumpHome(tester, file);
    expect(find.byIcon(Icons.download_done), findsNothing);

    await DownloadRegistry.instance.markDownloaded(file.downloadKey);
    await tester.pump();

    expect(find.byIcon(Icons.download_done), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
