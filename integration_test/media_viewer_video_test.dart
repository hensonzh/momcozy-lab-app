import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:video_player/video_player.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'streams, plays, and opens an authenticated video fullscreen',
    (tester) async {
      final fixture = await rootBundle.load(MomCozyAssets.agentThinkingAvatar);
      final server = await _VideoFixtureServer.start(
        fixture.buffer.asUint8List(
          fixture.offsetInBytes,
          fixture.lengthInBytes,
        ),
      );
      addTearDown(() => server.close());
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
        tokenProvider: () => 'integration-video-token',
      );
      final runtime = MomCozyApiRuntime(
        jsonTransport: const _NoopJsonTransport(),
        productAssetRepository: repository,
        userId: 'integration-user',
        babyId: 'integration-baby',
        locale: 'zh-CN',
      );
      final location = Uri(
        path: '/media-viewer',
        queryParameters: const {
          'kind': 'video',
          'url': '/v1/assets/asset-video?kind=video',
          'title': '视频播放验收',
        },
      ).toString();

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: runtime,
          router: createMomCozyRouter(initialLocation: location),
        ),
      );
      final controller = await _waitForReadyVideo(tester);

      expect(controller.value.duration, greaterThan(Duration.zero));
      expect(server.authorizationHeaders, isNotEmpty);
      expect(
        server.authorizationHeaders,
        everyElement('Bearer integration-video-token'),
      );

      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-play-pause')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.position, greaterThan(Duration.zero));

      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-fullscreen')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('product-asset-video-immersive')),
        findsOneWidget,
      );

      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 300));
      final screenshot = await binding.takeScreenshot('media-video-fullscreen');
      expect(await _screenshotColorCount(screenshot), greaterThan(8));

      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-exit-fullscreen')),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<VideoPlayerController> _waitForReadyVideo(WidgetTester tester) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final finder = find.byType(VideoPlayer);
    if (finder.evaluate().isEmpty) continue;
    final controller = tester.widget<VideoPlayer>(finder).controller;
    if (controller.value.isInitialized) return controller;
  }
  fail('Native video player did not become ready.');
}

Future<int> _screenshotColorCount(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = data!.buffer.asUint8List();
  final colors = <int>{};
  for (var index = 0; index + 3 < pixels.length; index += 1600) {
    colors.add(
      (pixels[index] << 16) | (pixels[index + 1] << 8) | pixels[index + 2],
    );
  }
  frame.image.dispose();
  codec.dispose();
  return colors.length;
}

class _VideoFixtureServer {
  _VideoFixtureServer._(this._server, this._subscription, this.bytes);

  final HttpServer _server;
  final StreamSubscription<HttpRequest> _subscription;
  final Uint8List bytes;
  final authorizationHeaders = <String>[];
  final rangeHeaders = <String>[];

  int get port => _server.port;

  static Future<_VideoFixtureServer> start(Uint8List bytes) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late final _VideoFixtureServer fixtureServer;
    final subscription = server.listen((request) {
      unawaited(fixtureServer._handle(request));
    });
    fixtureServer = _VideoFixtureServer._(server, subscription, bytes);
    return fixtureServer;
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.uri.path != '/v1/assets/asset-video') {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    authorizationHeaders.add(
      request.headers.value(HttpHeaders.authorizationHeader) ?? '',
    );
    response.headers
      ..contentType = ContentType('video', 'mp4')
      ..set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (request.method == 'HEAD') {
      response.contentLength = bytes.length;
      await response.close();
      return;
    }
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    if (rangeHeader == null || rangeHeader.isEmpty) {
      response.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      return;
    }
    rangeHeaders.add(rangeHeader);
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(rangeHeader);
    if (match == null) {
      await _rejectRange(response);
      return;
    }
    final start = int.parse(match.group(1)!);
    if (start >= bytes.length) {
      await _rejectRange(response);
      return;
    }
    final requestedEnd = match.group(2)!;
    final end = requestedEnd.isEmpty
        ? bytes.length - 1
        : int.parse(requestedEnd).clamp(start, bytes.length - 1);
    final body = bytes.sublist(start, end + 1);
    response
      ..statusCode = HttpStatus.partialContent
      ..contentLength = body.length;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${bytes.length}',
    );
    response.add(body);
    await response.close();
  }

  Future<void> _rejectRange(HttpResponse response) async {
    response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes */${bytes.length}',
    );
    await response.close();
  }
}

class _NoopJsonTransport implements ApiJsonTransport {
  const _NoopJsonTransport();

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => throw UnsupportedError('No JSON request expected.');

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnsupportedError('No JSON request expected.');
}
