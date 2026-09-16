import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../test/support/fixture_api_transport.dart';
import '../test/support/fake_agent_voice.dart';
import '../test/support/test_pdf_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'native Agent resource cards, PDF, image, video and renewal routes',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await _AssetsServer.start();
      final transport = _NativeResourceTransport();
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'native-inventory-user',
        babyId: 'native-inventory-baby',
        locale: 'zh-CN',
        accessToken: 'isolated-native-session',
        refreshToken: 'isolated-native-refresh',
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport({}),
          productAssetRepository: ProductAssetRepository(
            baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
            tokenProvider: () => 'native-inventory-asset',
          ),
          agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
          session: session,
          supportsSessionAutoRefresh: false,
          now: () => DateTime.utc(2026, 9, 13, 8),
          timezoneProvider: () async => 'Asia/Shanghai',
        ),
      );
      final store = MemoryMomCozySessionStore(session);
      final platform = FakeRouteIntentPlatform();
      final router = createMomCozyRouter(
        initialLocation: '/more',
        runtimeController: runtime,
        sessionStore: store,
        agentHubBuilder: (context, uri, extra, voice) {
          final api = MomCozyRuntimeScope.of(context);
          return AgentHubPage(
            key: const ValueKey('native-inventory-agent'),
            stateCacheKey: api,
            interactionStateStore: createSessionAgentHubInteractionStateStore(
              api.currentSession,
            ),
            runner: AgentStreamRunner(SseAgentStreamClient(transport)),
            requestBuilder: (message) => buildSessionAgentHubRequest(
              message,
              session: api.currentSession,
            ),
            greetingProfileLoader:
                api.agentHubProfileRepository.fetchGreetingProfile,
            voicePlaybackCoordinator: voice,
            voicePlaybackPlayer: api.agentVoicePlaybackPlayer,
            productAssetRepository: api.productAssetRepository,
            onArtifactAction: (action) =>
                dispatchAgentArtifactAction(context, action),
          );
        },
      );
      addTearDown(() async {
        router.dispose();
        runtime.dispose();
        await platform.dispose();
        await transport.stream.close();
        await server.close();
      });
      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          runtimeController: runtime,
          sessionStore: store,
          routeIntentPlatform: platform,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bottom-nav-cozymate')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/');
      await tester.enterText(
        find.byKey(const ValueKey('agent-composer-input')),
        '请给我资料和支持入口。',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('agent-send-button')));
      for (var i = 0; i < 50 && transport.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(transport.requests, hasLength(1));
      transport.publish('artifact.created', 1, {
        'artifact_type': 'rich_text',
        'title': '资料与支持',
        'content': '从下方入口继续查看。',
        'actions': [
          {
            'kind': 'pdf',
            'label': '阅读资料 PDF',
            'value': '/v1/assets/native-pdf?kind=pdf',
          },
          {
            'kind': 'video',
            'label': '播放指导视频',
            'value': '/v1/assets/native-video?kind=video',
          },
          {
            'kind': 'image',
            'label': '查看示意图片',
            'value': '/v1/assets/native-image?kind=image',
          },
          {'kind': 'open_url', 'label': '继续查看支持方案', 'value': '/services/renew'},
        ],
      });
      transport.publish('message.completed', 2, {'text': '你可以从资料卡片继续查看。'});
      transport.publish('run.completed', 3, {});
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 500));
      final rows = <Map<String, Object?>>[];
      String? prior;
      Future<void> capture(
        String state,
        String trigger, {
        String route = '/',
        bool longChat = false,
        bool longList = false,
        String? fullDocument,
      }) async {
        expect(router.state.uri.path, route);
        expect(tester.takeException(), isNull);
        final name = 'native-resource-$state';
        await tester.pump(const Duration(milliseconds: 250));
        final bytes = await binding.takeScreenshot(name);
        final directory = await getApplicationDocumentsDirectory();
        await File('${directory.path}/$name.png').writeAsBytes(bytes);
        String? full = fullDocument;
        if (longChat || longList) {
          final finder = longChat
              ? find
                    .descendant(
                      of: find.byKey(const ValueKey('agent-chat-scroll-view')),
                      matching: find.byType(Scrollable),
                    )
                    .first
              : find.byType(Scrollable).first;
          if (await _captureLongScroll(tester, binding, finder, '$name-long')) {
            full = '$name-long';
          }
        }
        rows.add({
          'state': state,
          'file': '$name.png',
          'route': route,
          'trigger': trigger,
          'previous': prior,
          if (full != null) 'full_document': '$full.png',
          if (full != null) 'scroll_metadata': '$full.json',
          'root_entry':
              'More → Cozymate → send question → SSE artifact card → actual action button',
          'test': 'integration_test/agent_resource_inventory_test.dart',
        });
        prior = name;
        await File(
          '${directory.path}/native-resource-journeys.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(rows));
      }

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      final mediaBack = find.byKey(const ValueKey('media-return-button'));
      await tester.ensureVisible(find.text('阅读资料 PDF'));
      await tester.pumpAndSettle();
      await capture(
        'card',
        'Actual native Agent reply with four Chinese action labels',
        longChat: true,
      );
      await tap(find.text('阅读资料 PDF'));
      final pdf = await _waitForReadyPdf(tester);
      await tester.pumpAndSettle();
      expect(pdf.controller!.pageCount, 2);
      await _captureLongDocument(
        tester,
        binding,
        pdf.controller!,
        name: 'native-resource-pdf-full',
      );
      await capture(
        'pdf-first',
        'Tap PDF action → native PDFium displays first of two pages',
        route: '/media-viewer',
        fullDocument: 'native-resource-pdf-full',
      );
      await tap(find.byTooltip('下一页'));
      expect(pdf.controller!.pageNumber, 2);
      await capture(
        'pdf-next',
        'Tap next page → page two',
        route: '/media-viewer',
      );
      await tap(find.byTooltip('放大文档'));
      await _captureLongDocument(
        tester,
        binding,
        pdf.controller!,
        name: 'native-resource-pdf-zoom-full',
      );
      await capture(
        'pdf-zoom',
        'Zoom PDF → actual rendered zoom and complete document',
        route: '/media-viewer',
        fullDocument: 'native-resource-pdf-zoom-full',
      );
      await tap(find.byTooltip('缩小文档'));
      await tap(find.byTooltip('上一页'));
      await capture(
        'pdf-reset',
        'Zoom out then previous page → original document view',
        route: '/media-viewer',
      );
      await tap(mediaBack);
      await tester.ensureVisible(find.text('播放指导视频'));
      await tester.pumpAndSettle();
      await capture(
        'pdf-return',
        'Native PDF back → original Agent card',
        longChat: true,
      );

      await tap(find.text('播放指导视频'));
      final video = await _waitForReadyVideo(tester);
      await capture(
        'video-ready',
        'Tap video action → real Android decoder renders asset',
        route: '/media-viewer',
      );
      await tester.tap(
        find.byKey(const ValueKey('product-asset-video-play-pause')),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(video.value.isPlaying, isTrue);
      expect(video.value.position, greaterThan(Duration.zero));
      await capture(
        'video-playing',
        'Play → native video position advances',
        route: '/media-viewer',
      );
      await tap(find.byKey(const ValueKey('product-asset-video-play-pause')));
      expect(video.value.isPlaying, isFalse);
      await capture(
        'video-paused',
        'Pause native playback',
        route: '/media-viewer',
      );
      await tap(find.byKey(const ValueKey('product-asset-video-progress')));
      await tap(find.byKey(const ValueKey('product-asset-video-volume')));
      await capture(
        'video-seek-mute',
        'Seek and mute → actual controller controls',
        route: '/media-viewer',
      );
      await tap(find.byKey(const ValueKey('product-asset-video-fullscreen')));
      await capture(
        'video-fullscreen',
        'Open native immersive player',
        route: '/media-viewer',
      );
      await tap(
        find.byKey(const ValueKey('product-asset-video-exit-fullscreen')).first,
      );
      await capture(
        'video-inline',
        'Exit immersive player retains paused position',
        route: '/media-viewer',
      );
      await tap(mediaBack);
      await tester.ensureVisible(find.text('查看示意图片'));
      await tester.pumpAndSettle();
      await capture(
        'video-return',
        'Video back disposes player and restores original card',
        longChat: true,
      );

      await tap(find.text('查看示意图片'));
      final image = find.byKey(
        const ValueKey('media-image-interactive-viewer'),
      );
      for (var i = 0; i < 100 && image.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(image, findsOneWidget);
      await capture(
        'image',
        'Image card → native decoded PNG',
        route: '/media-viewer',
      );
      await tester.tap(image);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(image);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(image)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        2.5,
      );
      await capture(
        'image-zoom',
        'Double tap → 2.5x image zoom',
        route: '/media-viewer',
      );
      await tap(mediaBack);
      await tester.ensureVisible(find.text('继续查看支持方案'));
      await tester.pumpAndSettle();
      await capture(
        'image-return',
        'Image back → original native card',
        longChat: true,
      );
      await tap(find.text('继续查看支持方案'));
      await capture(
        'renew',
        'Native artifact internal link → generic renewal route',
        route: '/services/renew',
        longList: true,
      );
      await tap(find.text('返回'));
      expect(router.state.uri.path, '/me');
      await tester.tap(find.byKey(const ValueKey('bottom-nav-cozymate')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('继续查看支持方案'));
      await tester.pumpAndSettle();
      await capture(
        'renew-return',
        'Renewal back → Me; Cozymate tab restores the original reply',
        longChat: true,
      );
      expect(transport.requests, hasLength(1));
      expect(server.authorizations, isNotEmpty);
      expect(
        server.authorizations,
        everyElement('Bearer native-inventory-asset'),
      );
      final directory = await getApplicationDocumentsDirectory();
      await File('${directory.path}/native-resource-result.json').writeAsString(
        jsonEncode({
          'status': 'PASS',
          'states': rows.length,
          'sse_requests': transport.requests.length,
          'asset_paths': server.paths,
          'authorization_validated': true,
          'native_pdf_pages': 2,
          'native_video_position_advanced': true,
        }),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

class _NativeResourceTransport extends FixtureApiJsonTransportByPath
    implements AgentStreamTransport {
  _NativeResourceTransport()
    : super({
        '/v1/profile/me': {'preferred_name': 'Mia', 'age': 30},
        '/v1/profile/lactation': {'actual_delivery_date': '2026-08-24'},
        '/v1/care/overview': {'orders': [], 'episodes': []},
        '/v1/mother/diary': {'items': []},
        '/v1/lactation/records': {'items': []},
        '/v1/care/catalog': {
          'payment_mode': 'disabled',
          'packages': [
            {
              'id': 'feeding-confidence',
              'name': '喂养安心',
              'subtitle': 'Feeding Confidence',
              'description': '本地盘点用服务方案。',
              'duration_days': 7,
              'sessions': 2,
              'price_minor': 21900,
              'currency': 'USD',
              'highlights': [],
              'expert_services': [],
              'continuous_services': [],
            },
          ],
          'providers': [],
          'available_regions': [],
        },
      });
  final requests = <AgentStreamRequest>[];
  final stream = StreamController<String>.broadcast();
  @override
  Stream<String> frames(AgentStreamRequest request) {
    requests.add(request);
    return stream.stream;
  }

  void publish(
    String type,
    int sequence,
    Map<String, Object?> payload,
  ) => stream.add(
    'data: ${jsonEncode({'event_id': 'native-resource-$sequence', 'type': type, 'thread_id': '11111111-1111-4111-8111-111111111111', 'run_id': 'native-resource-run', 'message_id': 'native-resource-message', 'artifact_id': 'native-resource-card', 'sequence': sequence, 'payload': payload})}\n\n',
  );
}

class _AssetsServer {
  _AssetsServer(this.server, this.assets);
  final HttpServer server;
  final Map<String, (Uint8List, String)> assets;
  final paths = <String>[];
  final authorizations = <String>[];
  int get port => server.port;
  static Future<_AssetsServer> start() async {
    final image = await rootBundle.load('assets/images/mom/milk-hero.png');
    final video = await rootBundle.load(MomCozyAssets.agentThinkingAvatar);
    final server =
        _AssetsServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0), {
          '/v1/assets/native-pdf': (buildTwoPageTestPdf(), 'application/pdf'),
          '/v1/assets/native-video': (
            video.buffer.asUint8List(video.offsetInBytes, video.lengthInBytes),
            'video/mp4',
          ),
          '/v1/assets/native-image': (
            image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes),
            'image/png',
          ),
        });
    server.server.listen((request) => unawaited(server.handle(request)));
    return server;
  }

  Future<void> close() => server.close(force: true);
  Future<void> handle(HttpRequest request) async {
    final asset = assets[request.uri.path];
    final response = request.response;
    if (asset == null) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    paths.add(request.uri.path);
    authorizations.add(
      request.headers.value(HttpHeaders.authorizationHeader) ?? '',
    );
    response.headers.set(HttpHeaders.contentTypeHeader, asset.$2);
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    final bytes = asset.$1;
    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range == null || request.method == 'HEAD') {
      response.contentLength = bytes.length;
      if (request.method != 'HEAD') response.add(bytes);
      await response.close();
      return;
    }
    final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
    final start = match == null ? bytes.length : int.parse(match.group(1)!);
    if (start >= bytes.length) {
      response.statusCode = 416;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */${bytes.length}',
      );
      await response.close();
      return;
    }
    final requestedEnd = match!.group(2)!;
    final end = requestedEnd.isEmpty
        ? bytes.length - 1
        : int.parse(requestedEnd).clamp(start, bytes.length - 1);
    response.statusCode = 206;
    response.contentLength = end - start + 1;
    response.headers.set(
      HttpHeaders.contentRangeHeader,
      'bytes $start-$end/${bytes.length}',
    );
    response.add(bytes.sublist(start, end + 1));
    await response.close();
  }
}

Future<VideoPlayerController> _waitForReadyVideo(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final f = find.byType(VideoPlayer);
    if (f.evaluate().isNotEmpty) {
      final c = tester.widget<VideoPlayer>(f).controller;
      if (c.value.isInitialized) return c;
    }
  }
  fail('Native video did not initialize');
}

Future<bool> _captureLongScroll(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  Finder finder,
  String name,
) async {
  final state = tester.state<ScrollableState>(finder);
  final p = state.position;
  if (p.maxScrollExtent <= 1) return false;
  final original = p.pixels;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final frames = <ui.Image>[];
  final offsets = <double>[];
  final logicalWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final viewport = tester.getRect(finder);
  Rect? bounds;
  var written = 0.0;
  var ratio = 1.0;
  try {
    for (var i = 0; i < 100; i++) {
      final target = (i * viewport.height * .45).floorToDouble().clamp(
        0.0,
        p.maxScrollExtent,
      );
      for (var retry = 0; retry < 4; retry++) {
        p.jumpTo(target);
        await tester.pumpAndSettle();
        if ((p.pixels - target).abs() < .5) break;
      }
      expect((p.pixels - target).abs(), lessThan(.5));
      final bytes = await binding.takeScreenshot('$name-frame-$i');
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      frames.add(image);
      ratio = image.width / logicalWidth;
      bounds ??= Rect.fromLTRB(
        viewport.left * ratio,
        viewport.top * ratio,
        viewport.right * ratio,
        viewport.bottom * ratio,
      );
      if (i == 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Paint(),
        );
      }
      final offset = p.pixels * ratio;
      offsets.add(offset);
      var usable = bounds.height;
      final atEnd = p.pixels >= p.maxScrollExtent - .5;
      if (!atEnd) {
        usable -= 32 * ratio;
        final latest = find.byKey(const ValueKey('agent-scroll-latest-button'));
        if (latest.evaluate().isNotEmpty) {
          usable = usable.clamp(
            0.0,
            (tester.getRect(latest).top - viewport.top - 8) * ratio,
          );
        }
      }
      final start = (written - offset).clamp(0.0, usable);
      final count = usable - start;
      if (count > 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, bounds.top + start, image.width.toDouble(), count),
          Rect.fromLTWH(0, bounds.top + written, image.width.toDouble(), count),
          Paint(),
        );
        written += count;
      }
      if (atEnd) break;
    }
    expect(p.pixels, greaterThanOrEqualTo(p.maxScrollExtent - .5));
    expect(
      written,
      greaterThanOrEqualTo((p.maxScrollExtent + viewport.height) * ratio - 2),
    );
    final last = frames.last;
    final bottom = last.height - bounds!.bottom;
    canvas.drawImageRect(
      last,
      Rect.fromLTWH(0, bounds.bottom, last.width.toDouble(), bottom),
      Rect.fromLTWH(0, bounds.top + written, last.width.toDouble(), bottom),
      Paint(),
    );
    final picture = recorder.endRecording();
    final output = await picture.toImage(
      last.width,
      (bounds.top + written + bottom).ceil(),
    );
    picture.dispose();
    final png = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    final directory = await getApplicationDocumentsDirectory();
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    await File('${directory.path}/$name.json').writeAsString(
      jsonEncode({
        'kind': 'actual-native-ScrollPosition-measured-stitch',
        'first_visible_top': offsets.first,
        'last_visible_bottom': p.pixels + viewport.height,
        'document_height': p.maxScrollExtent + viewport.height,
        'pixel_ratio': ratio,
        'pixel_offsets': offsets,
        'viewport_bounds': [
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        ],
        'stitched_content_height': written,
        'header_footer': 'each retained once',
        'scroll_latest_overlay': 'excluded from middle strips',
      }),
    );
    return true;
  } finally {
    for (final f in frames) {
      f.dispose();
    }
    p.jumpTo(original);
    await tester.pumpAndSettle();
  }
}

/// PDF uses a transformed document, not Flutter ScrollPosition. Walk its real
/// visible document rect and stitch the rendered viewport at measured offsets.
Future<void> _captureLongDocument(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  PdfViewerController controller, {
  String name = 'native-media-pdf-full-document',
}) async {
  final original = controller.value.clone();
  final zoom = controller.currentZoom;
  final viewport = tester.getRect(find.byType(PdfViewer));
  final logicalWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final documentHeight = controller.documentSize.height;
  final viewportHeight = controller.visibleRect.height;
  final centerX = controller.visibleRect.center.dx;
  final frames = <ui.Image>[];
  final offsets = <double>[];
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  var written = 0.0;
  var firstTop = 0.0;
  var pixelRatio = 1.0;
  Rect? bounds;
  try {
    for (var index = 0; index < 30; index++) {
      final top = (index * viewportHeight * .75).clamp(
        0.0,
        (documentHeight - viewportHeight).clamp(0.0, documentHeight),
      );
      await controller.goTo(
        controller.calcMatrixFor(
          Offset(centerX, top + viewportHeight / 2),
          zoom: zoom,
        ),
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      final bytes = await binding.takeScreenshot('$name-scroll-$index');
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      frames.add(image);
      pixelRatio = image.width / logicalWidth;
      bounds ??= Rect.fromLTRB(
        viewport.left * pixelRatio,
        viewport.top * pixelRatio,
        viewport.right * pixelRatio,
        viewport.bottom * pixelRatio,
      );
      if (index == 0) {
        firstTop = controller.visibleRect.top;
        expect(firstTop, lessThanOrEqualTo(.5), reason: 'Include document top');
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Paint(),
        );
      }
      final offset =
          (controller.visibleRect.top - firstTop) * zoom * pixelRatio;
      offsets.add(offset);
      final start = (written - offset).clamp(0.0, bounds.height);
      final count = bounds.height - start;
      if (count > 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, bounds.top + start, image.width.toDouble(), count),
          Rect.fromLTWH(0, bounds.top + written, image.width.toDouble(), count),
          Paint(),
        );
        written += count;
      }
      if (controller.visibleRect.bottom >= documentHeight - .5) break;
    }
    expect(
      controller.visibleRect.bottom,
      greaterThanOrEqualTo(documentHeight - .5),
    );
    expect(offsets.length, greaterThan(1));
    final last = frames.last;
    final bottom = last.height - bounds!.bottom;
    canvas.drawImageRect(
      last,
      Rect.fromLTWH(0, bounds.bottom, last.width.toDouble(), bottom),
      Rect.fromLTWH(0, bounds.top + written, last.width.toDouble(), bottom),
      Paint(),
    );
    final picture = recorder.endRecording();
    final stitched = await picture.toImage(
      last.width,
      (bounds.top + written + bottom).ceil(),
    );
    picture.dispose();
    final data = await stitched.toByteData(format: ui.ImageByteFormat.png);
    stitched.dispose();
    final directory = await getApplicationDocumentsDirectory();
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    await File('${directory.path}/$name.json').writeAsString(
      jsonEncode({
        'kind': 'actual-native-PDF-viewer-measured-scroll-stitch',
        'page_count': controller.pageCount,
        'document_height': documentHeight,
        'first_visible_top': firstTop,
        'last_visible_bottom': controller.visibleRect.bottom,
        'zoom': zoom,
        'pixel_ratio': pixelRatio,
        'pixel_offsets': offsets,
        'viewport_bounds': [
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        ],
        'stitched_content_height': written,
        'header_footer': 'each retained once',
      }),
    );
  } finally {
    for (final image in frames) {
      image.dispose();
    }
    await controller.goTo(original, duration: Duration.zero);
    await tester.pumpAndSettle();
  }
}

Future<PdfViewer> _waitForReadyPdf(WidgetTester tester) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final finder = find.byType(PdfViewer);
    if (finder.evaluate().isEmpty) continue;
    final viewer = tester.widget<PdfViewer>(finder);
    if (viewer.controller?.isReady == true) return viewer;
  }
  fail('PDFium did not make the viewer ready.');
}
