import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Ways a request can fail, simulating a camera that dies mid-session.
enum FakeCameraFailure {
  /// Camera answers with HTTP 500.
  status500,

  /// HTTP 200 whose body is not a JPEG (e.g. an HTML error page).
  garbageBody,

  /// The transfer starts, then the connection drops before the whole body
  /// arrives — the client sees a truncated JPEG.
  truncatedJpeg,
}

/// In-process emulation of the Olympus camera HTTP API for integration tests
/// on an emulator. Implements the subset the app speaks:
///
///  - `GET /get_caminfo.cgi`            XML device info
///  - `GET /switch_cammode.cgi?mode=`   200 OK
///  - `GET /get_imglist.cgi?DIR=`       CSV listing (dirs have attrib & 16)
///  - `GET /get_thumbnail.cgi?DIR=`     JPEG bytes
///  - `GET /get_screennail.cgi?DIR=`    JPEG bytes
///  - `GET /get_resizeimg.cgi?DIR=&size=` JPEG bytes
///  - `GET /exec_erase.cgi?DIR=`        deletes, 200 OK body
///  - `GET /<fullPath>`                 original file download
///
/// Point the app at it via `debugCameraBaseUrlOverride` (see camera_api.dart).
class FakeCameraServer {
  final files = <String, Uint8List>{};
  final deletedPaths = <String>[];
  final requests = <String>[];

  /// Artificial per-request latency so concurrent fetches genuinely overlap.
  Duration delay = Duration.zero;

  HttpServer? _server;
  final _failures = <String, FakeCameraFailure>{};

  /// FAT date 2024-06-01 12:00:00 (valid for CameraFile.decodeFatDateTime).
  static const int _dateRaw = 22721;
  static const int _timeRaw = 24576;

  /// Minimal JPEG the app's own validator accepts (SOI...EOI).
  static Uint8List get jpeg => _jpeg;
  static final Uint8List _jpeg = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

  /// Adds a photo, e.g. `/DCIM/100OLYMP/P1010001.JPG`.
  void addPhoto(String fullPath, [Uint8List? bytes]) {
    files[fullPath] = bytes ?? jpeg;
  }

  /// Every request whose URL contains [urlFragment] fails with [failure]
  /// until [clearFailures] is called. The fragment may be a path
  /// (`/DCIM/BAD1.JPG`) or an endpoint (`get_thumbnail.cgi`).
  void failFor(String urlFragment, FakeCameraFailure failure) {
    _failures[urlFragment] = failure;
  }

  void clearFailures() => _failures.clear();

  /// Binds on the device loopback and returns the base URL to inject.
  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_serve());
    return 'http://127.0.0.1:${_server!.port}';
  }

  Future<void> close() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _serve() async {
    await for (final req in _server!) {
      try {
        requests.add(req.uri.toString());
        await _handle(req);
      } catch (_) {
        try {
          req.response.statusCode = 500;
          await req.response.close();
        } catch (_) {}
      }
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final failure = _failureFor(req);
    if (failure != null) {
      await _fail(req, failure);
      return;
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final body = _bodyFor(req, path);
    if (body == null) {
      req.response.statusCode = 404;
      await req.response.close();
      return;
    }
    req.response.headers.contentType =
        path.endsWith('.JPG') || path.endsWith('.jpg')
            ? ContentType('image', 'jpeg')
            : ContentType('text', 'plain', charset: 'utf-8');
    req.response.contentLength = body.lengthInBytes;
    req.response.add(body);
    await req.response.close();
  }

  FakeCameraFailure? _failureFor(HttpRequest req) {
    final url = req.uri.toString();
    for (final entry in _failures.entries) {
      if (url.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Answers a request with an injected failure instead of real content.
  Future<void> _fail(HttpRequest req, FakeCameraFailure failure) async {
    switch (failure) {
      case FakeCameraFailure.status500:
        req.response.statusCode = 500;
        await req.response.close();
      case FakeCameraFailure.garbageBody:
        final body = Uint8List.fromList(
          '<html><body>camera is dying</body></html>'.codeUnits,
        );
        req.response.headers.contentType = ContentType('image', 'jpeg');
        req.response.contentLength = body.lengthInBytes;
        req.response.add(body);
        await req.response.close();
      case FakeCameraFailure.truncatedJpeg:
        // Promise more bytes than we send, then close the socket: the client
        // sees the connection drop in the middle of the body.
        req.response.headers.contentType = ContentType('image', 'jpeg');
        req.response.contentLength = jpeg.lengthInBytes + 64;
        req.response.add(jpeg);
        await req.response.flush();
        await req.response.close();
    }
  }

  Uint8List? _bodyFor(HttpRequest req, String path) {
    final dir = req.uri.queryParameters['DIR'] ?? '';

    switch (path) {
      case '/get_caminfo.cgi':
        return Uint8List.fromList(
          '<INFO><MODEL>FAKE-OLYMPUS</MODEL><VERSION>1.0</VERSION>'
          '<SERIAL>TEST0001</SERIAL><LANG>en</LANG></INFO>'.codeUnits,
        );
      case '/switch_cammode.cgi':
        return Uint8List(0);
      case '/get_imglist.cgi':
        return Uint8List.fromList(_imgList(dir));
      case '/get_thumbnail.cgi':
      case '/get_screennail.cgi':
      case '/get_resizeimg.cgi':
        return files[dir] == null ? null : jpeg;
      case '/exec_erase.cgi':
        if (files.remove(dir) == null) return null;
        deletedPaths.add(dir);
        return Uint8List.fromList('OK'.codeUnits);
    }

    // Original file download: /DCIM/100OLYMP/P1010001.JPG
    return files[path];
  }

  /// Olympus CSV listing: `VER…` header, then per entry
  /// `parent,name,size,attrib,date,time`. Directories carry attrib & 16.
  List<int> _imgList(String dir) {
    final lines = <String>['VER100'];
    if (dir.isEmpty) return Uint8List.fromList('VER100\r\n'.codeUnits);

    final subdirs = <String>{};
    final filesHere = <String>[];
    for (final p in files.keys) {
      if (!p.startsWith('$dir/')) continue;
      final rel = p.substring(dir.length + 1);
      if (rel.contains('/')) {
        subdirs.add(rel.split('/').first);
      } else {
        filesHere.add(p);
      }
    }
    for (final name in subdirs) {
      lines.add('$dir,$name,0,49,0,0');
    }
    for (final p in filesHere) {
      final name = p.substring(p.lastIndexOf('/') + 1);
      lines.add('$dir,$name,${files[p]!.lengthInBytes},33,$_dateRaw,$_timeRaw');
    }
    return lines.join('\r\n').codeUnits;
  }
}
