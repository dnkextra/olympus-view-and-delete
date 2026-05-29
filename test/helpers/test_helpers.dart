import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Minimal `path_provider` mock that routes every application path to a single
/// temp directory. Shared by tests that need [ImageDiskCache] (or anything
/// using `path_provider`) to initialise without a real platform.
class FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationCachePath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// An `http.Client` that responds to every request with [status] and [body],
/// so widgets/services never hit the real network in tests.
http.Client fixedResponseClient({int status = 204, String body = ''}) =>
    MockClient((_) async => http.Response(body, status));
