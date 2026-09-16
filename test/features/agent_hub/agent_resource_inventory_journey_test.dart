import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import '../../support/fake_video_player_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/core/routing/external_url_launcher.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../support/mom_inventory_transport.dart';
import '../../support/agent_workflow_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentWorkflowInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  late InventoryLinkLauncher launcher;
  bool failClipboard = false;
  late InventoryAssetConnector assets;
  late FakeVideoPlayerPlatform video;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentWorkflowInventoryTransport)? prepare,
    bool loading = false,
    bool failVideo = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
    failClipboard = false;
    assets = InventoryAssetConnector();
    final priorVideo = VideoPlayerPlatform.instance;
    var failNextMediaVideo = failVideo;
    video = FakeVideoPlayerPlatform(
      initializationFor: (source) {
        if (source.uri?.contains('/v1/assets/inventory-video') == true &&
            failNextMediaVideo) {
          failNextMediaVideo = false;
          return FakeVideoInitialization.failure(
            StateError('isolated initialization failure'),
          );
        }
        return const FakeVideoInitialization.success();
      },
    );
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = priorVideo);
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failClipboard) {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      if (call.method == 'Clipboard.getData') return {'text': clipboard};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    launcher = InventoryLinkLauncher();
    transport = AgentWorkflowInventoryTransport();
    prepare?.call(transport);
    const session = MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'inventory-user',
      babyId: 'inventory-baby',
      locale: 'zh-CN',
      accessToken: 'fixture-access',
      refreshToken: 'fixture-refresh',
    );
    runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        productAssetRepository: ProductAssetRepository(
          baseUri: Uri.parse('https://inventory.invalid'),
          connector: assets,
          tokenProvider: () => 'fixture-asset-token',
        ),
        multipartTransport: FixtureApiMultipartTransport({}),
        agentVoicePlaybackPlayer: ImmediateAgentVoicePlaybackPlayer(),
        session: session,
        supportsSessionAutoRefresh: false,
        now: () => inventoryMomNow,
        timezoneProvider: () async => 'Asia/Shanghai',
      ),
    );
    final store = MemoryMomCozySessionStore(session);
    final platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      sessionStore: store,
      agentHubBuilder: (context, uri, extra, voice) {
        final api = MomCozyRuntimeScope.of(context);
        return AgentHubPage(
          key: const ValueKey('inventory-agent-page'),
          stateCacheKey: api,
          interactionStateStore: createSessionAgentHubInteractionStateStore(
            api.currentSession,
          ),
          runner: AgentStreamRunner(
            SseAgentStreamClient(transport),
            reconnectPolicy: const AgentStreamReconnectPolicy(),
            runStatusReader: transport,
          ),
          cancelClient: AgentStreamCancelClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('https://inventory.invalid/v1/agent/runs'),
            ),
            connector: transport,
          ),
          actionClient: AgentStreamActionClient(
            endpoint: AgentStreamEndpoint(
              uri: Uri.parse('https://inventory.invalid/v1/agent/actions'),
            ),
            connector: transport,
          ),
          supportTicketSubmitter: api.supportTicketRepository.submit,
          greetingProfileLoader:
              api.agentHubProfileRepository.fetchGreetingProfile,
          requestBuilder: (message) =>
              buildSessionAgentHubRequest(message, session: api.currentSession),
          voicePlaybackCoordinator: voice,
          voicePlaybackPlayer: api.agentVoicePlaybackPlayer,
          mediaRepository: api.mediaRepository,
          pickImage: api.agentHubImagePicker,
          pickDocument: api.agentHubDocumentPicker,
          onApplicationEvent: api.handleAgentApplicationEvent,
          onArtifactAction: (action) => dispatchAgentArtifactAction(
            context,
            action,
            externalUrlLauncher: launcher,
          ),
        );
      },
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Long capture visits lazy children. Decode both local images before
      // comparing any viewport so later dialogs see the same loaded page.
      for (final asset in [
        MomCozyAssets.agentAvatar,
        'assets/images/mom_home/cozymate_avatar.png',
        'assets/images/mom_home/expert_group.png',
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.text('Cozymate'));
    if (loading) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
    expect(router.state.uri.path, '/');
    addTearDown(() async {
      for (final gate in transport.readGates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      if (transport.writeGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      launcher.release();
      assets.release();
      transport.disposeStreams();
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> frame(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.restorationId != 'editable' &&
                  (widget.axisDirection == AxisDirection.down ||
                      widget.axisDirection == AxisDirection.up),
            )
            .last,
      );
    } else {
      await tester.ensureVisible(target);
    }
    await frame(tester);
    await tester.tap(target);
    await frame(tester);
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String action, {
    String route = '/',
  }) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    final suffix =
        '${tester.view.physicalSize.width.round()}${tester.platformDispatcher.textScaleFactor > 1 ? '-2x' : ''}';
    final source =
        'test/goldens/ui_inventory/agent-resource-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-resource-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Cozymate bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage through public builder; real SSE parser, runner, artifact mapper and dispatcher, media and Care repositories; only SSE/HTTP bytes, voice, session and video platform isolated. Real image bytes decoded; video texture/native decoder is a platform stub. Default local history flag; no remote requests.',
      'test':
          'test/features/agent_hub/agent_resource_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/agent-resource-journey-$state-$suffix.json',
      );
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  final input = find.byKey(const ValueKey('agent-composer-input'));
  final sendButton = find.byKey(const ValueKey('agent-send-button'));
  Future<void> send(WidgetTester tester, String message) async {
    await tester.enterText(input, message);
    await tap(tester, sendButton);
  }

  Future<void> finish(
    WidgetTester tester,
    int index,
    String message, {
    int? run,
    int first = 1,
  }) async {
    transport.emit(index, 'message.completed', first, {
      'text': message,
    }, run: run);
    transport.emit(index, 'run.completed', first + 1, {}, run: run);
    await frame(tester);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final scrollable = find.byType(Scrollable).first;
      for (
        var attempt = 0;
        attempt < 20 &&
            tester.state<ScrollableState>(scrollable).position.pixels > 0;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, 500));
        await frame(tester);
      }
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    } else {
      await tester.ensureVisible(target);
    }
    await frame(tester);
  }

  Future<void> card(
    WidgetTester tester,
    String state,
    String kind,
    String value,
    String label,
  ) async {
    await send(tester, '请给我一个资料入口。');
    transport.publish(0, 'artifact.created', 1, {
      'artifact_type': 'rich_text',
      'title': '资料与支持',
      'content': '从下方入口继续查看。',
      'actions': [
        {'kind': kind, 'label': label, 'value': value},
      ],
    }, artifactId: 'resource-entry');
    await finish(tester, 0, '你可以从资料卡片继续查看。', first: 2);
    await reveal(tester, find.text(label));
    await capture(
      tester,
      '$state-card',
      'More → Cozymate → send request → real SSE artifact presents $label',
    );
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<void> doubleTapImage(WidgetTester tester, Finder viewer) async {
    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> videoState(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      if (target.evaluate().isNotEmpty) return;
    }
    fail('Video state $key did not appear');
  }

  const media = '/media-viewer';
  final back = find.byKey(const ValueKey('media-return-button'));
  for (final narrow in [false, true]) {
    final width = narrow ? 320.0 : 393.0;
    final scale = narrow ? 2.0 : 1.0;
    testWidgets('inventory agent generic renewal entry and return $width', (
      tester,
    ) async {
      await mount(tester, width: width, textScale: scale);
      await card(tester, 'renew', 'open_url', '/services/renew', '继续查看支持方案');
      await tap(tester, find.text('继续查看支持方案'));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'renew-list',
        'Tap supported internal artifact link → real renewal route without episode parameter',
        route: '/services/renew',
      );
      await tap(tester, find.text('选择').first);
      await capture(
        tester,
        'renew-eligibility',
        'Choose first package → real purchase eligibility',
        route: '/services/renew',
      );
      await tap(tester, find.byTooltip('关闭购买'));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'renew-closed',
        'Close eligibility → selected package retained',
        route: '/services/renew',
      );
      // The dispatcher uses go, so the service back callback falls back to Me.
      final list = find.byType(Scrollable).first;
      while (tester.state<ScrollableState>(list).position.pixels > 0) {
        await tester.drag(list, const Offset(0, 600));
        await tester.pumpAndSettle();
      }
      await tap(tester, find.text('返回'));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'renew-back-mom',
        'Renewal back after artifact context.go → actual /me fallback',
        route: '/me',
      );
      await tap(tester, find.byKey(const ValueKey('bottom-nav-cozymate')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('继续查看支持方案'));
      await capture(
        tester,
        'renew-card-return',
        'Tap Cozymate → original reply and resource card restored',
      );
      expect(transport.requests, hasLength(1));
      await done(tester);
    });

    testWidgets(
      'inventory agent image entry loading retry gestures and return $width',
      (tester) async {
        await mount(tester, width: width, textScale: scale);
        await card(
          tester,
          'image',
          'image',
          '/v1/assets/inventory-image?kind=image',
          '查看示意图片',
        );
        final pending = assets.defer();
        await tap(tester, find.text('查看示意图片'));
        await capture(
          tester,
          'image-loading',
          'Tap stable image asset action → actual viewer waiting for authenticated bytes',
          route: media,
        );
        pending.complete(assets.failure());
        await tester.pumpAndSettle();
        await capture(
          tester,
          'image-error',
          'Image HTTP 503 → retry state in actual viewer',
          route: media,
        );
        assets.response = () async => assets.imageResponse();
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(assets.imageBytes),
            tester.element(find.byType(MaterialApp)),
          ),
        );
        await tap(tester, find.byKey(const ValueKey('media-viewer-retry')));
        await tester.pumpAndSettle();
        final viewer = find.byKey(
          const ValueKey('media-image-interactive-viewer'),
        );
        expect(viewer, findsOneWidget);
        final transform = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!;
        await capture(
          tester,
          'image-loaded',
          'Retry decodes actual local PNG bytes through ProductAssetRepository',
          route: media,
        );
        await doubleTapImage(tester, viewer);
        expect(transform.value.getMaxScaleOnAxis(), 2.5);
        await capture(
          tester,
          'image-zoomed',
          'Double tap actual image → 2.5x zoom',
          route: media,
        );
        final before = transform.value.clone();
        await tester.drag(viewer, const Offset(60, -90));
        await tester.pumpAndSettle();
        expect(transform.value, isNot(before));
        await capture(
          tester,
          'image-panned',
          'Drag zoomed image → translated content',
          route: media,
        );
        await doubleTapImage(tester, viewer);
        expect(transform.value.getMaxScaleOnAxis(), 1);
        await capture(
          tester,
          'image-reset',
          'Double tap zoomed image → reset to fit',
          route: media,
        );
        await tap(tester, back);
        await reveal(tester, find.text('查看示意图片'));
        await capture(
          tester,
          'image-return',
          'Viewer back without pop stack → Cozymate with original image card',
        );
        final calls = assets.requests.length;
        await tap(tester, find.text('查看示意图片'));
        await tester.pumpAndSettle();
        expect(assets.requests, hasLength(calls));
        await capture(
          tester,
          'image-cached',
          'Reopen same image → in-memory cache, no additional asset HTTP',
          route: media,
        );
        await tap(tester, back);
        await done(tester);
      },
    );

    testWidgets(
      'inventory agent PDF entry failure retry and pending return $width',
      (tester) async {
        await mount(tester, width: width, textScale: scale);
        await card(
          tester,
          'pdf',
          'pdf',
          '/v1/assets/inventory-pdf?kind=pdf',
          '阅读资料 PDF',
        );
        final first = assets.defer();
        await tap(tester, find.text('阅读资料 PDF'));
        await capture(
          tester,
          'pdf-loading',
          'Tap stable PDF action → viewer requests authenticated PDF',
          route: media,
        );
        first.complete(assets.failure());
        await tester.pumpAndSettle();
        expect(find.text('PDF 加载失败'), findsOneWidget);
        await capture(
          tester,
          'pdf-error',
          'PDF HTTP 503 → actual retry control',
          route: media,
        );
        final retry = assets.defer();
        await tap(tester, find.byKey(const ValueKey('media-viewer-retry')));
        await capture(
          tester,
          'pdf-retrying',
          'Retry PDF → request pending again',
          route: media,
        );
        await tap(tester, back);
        await reveal(tester, find.text('阅读资料 PDF'));
        await capture(
          tester,
          'pdf-pending-return',
          'Back while PDF read pending → original Cozymate reply',
        );
        retry.complete(assets.failure());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        assets.response = () async => assets.failure(403);
        await tap(tester, find.text('阅读资料 PDF'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'pdf-forbidden',
          'Reopen after failed pending read → asset denied 403, still retryable',
          route: media,
        );
        expect(assets.requests.last.path, '/v1/assets/inventory-pdf');
        await tap(tester, back);
        await done(tester);
      },
    );

    testWidgets('inventory agent video entry retry controls and return $width', (
      tester,
    ) async {
      await mount(tester, width: width, textScale: scale, failVideo: true);
      await card(
        tester,
        'video',
        'video',
        '/v1/assets/inventory-video?kind=video',
        '播放指导视频',
      );
      await tap(tester, find.text('播放指导视频'));
      await videoState(tester, 'product-asset-video-error');
      await capture(
        tester,
        'video-error',
        'Tap stable video action → actual player reports isolated platform initialization failure',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-retry')),
      );
      await videoState(tester, 'product-asset-video-player');
      expect(video.createdSources.where((s) => s.uri != null), hasLength(2));
      final playerId = video.createdSources.length;
      expect(
        video.createdSources.last.uri,
        'https://inventory.invalid/v1/assets/inventory-video',
      );
      expect(
        video.createdSources.last.httpHeaders['Authorization'],
        'Bearer fixture-asset-token',
      );
      await capture(
        tester,
        'video-ready',
        'Retry initializes controller; actual controls rendered, native texture isolated',
        route: media,
      );
      final play = find.byKey(const ValueKey('product-asset-video-play-pause'));
      await tap(tester, play);
      expect(video.playedIds, contains(playerId));
      await capture(
        tester,
        'video-playing',
        'Tap play → controller playing state',
        route: media,
      );
      await tap(tester, play);
      await capture(
        tester,
        'video-paused',
        'Tap pause → playback paused',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-progress')),
      );
      expect(video.seekCommands, isNotEmpty);
      await capture(
        tester,
        'video-seeked',
        'Tap progress → seek position updates',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-volume')),
      );
      expect(video.volumeCommands, contains((playerId, 0.0)));
      await capture(
        tester,
        'video-muted',
        'Mute → volume icon and controller value change',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-fullscreen')),
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        'video-fullscreen',
        'Fullscreen button → actual immersive route; platform orientation request isolated',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-exit-fullscreen')).first,
      );
      await tester.pumpAndSettle();
      await capture(
        tester,
        'video-exit-fullscreen',
        'Exit immersive route → same inline controller and position',
        route: media,
      );
      video.emitError(playerId, StateError('isolated playback interruption'));
      await videoState(tester, 'product-asset-video-error');
      await capture(
        tester,
        'video-runtime-error',
        'Platform playback error → retry state; failed controller disposed',
        route: media,
      );
      await tap(
        tester,
        find.byKey(const ValueKey('product-asset-video-retry')),
      );
      await videoState(tester, 'product-asset-video-player');
      await capture(
        tester,
        'video-recovered',
        'Retry playback error → newly initialized controller',
        route: media,
      );
      await tap(tester, back);
      await reveal(tester, find.text('播放指导视频'));
      await capture(
        tester,
        'video-return',
        'Media back → original card; video controller disposed',
      );
      expect(video.disposedIds, contains(playerId + 1));
      await done(tester);
    });
  }

  testWidgets('inventory malformed media artifact cannot open viewer', (
    tester,
  ) async {
    await mount(tester);
    await card(tester, 'invalid', 'image', '/media-viewer', '查看失效资料');
    await tap(tester, find.text('查看失效资料'));
    expect(router.state.uri.path, '/');
    expect(assets.requests, isEmpty);
    await capture(
      tester,
      'invalid-no-navigation',
      'Tap malformed asset action → stable asset guard ignores it, no missing-resource page forced',
    );
    await done(tester);
  });
}

class InventoryAssetConnector implements ProductAssetHttpConnector {
  final imageBytes = File('assets/images/mom/milk-hero.png').readAsBytesSync();
  final requests = <Uri>[];
  final pending = <Completer<ProductAssetHttpResponse>>[];
  late Future<ProductAssetHttpResponse> Function() response = () async =>
      failure();
  Completer<ProductAssetHttpResponse> defer() {
    final value = Completer<ProductAssetHttpResponse>();
    pending.add(value);
    response = () => value.future;
    return value;
  }

  ProductAssetHttpResponse failure([int status = 503]) =>
      ProductAssetHttpResponse(
        statusCode: status,
        statusText: 'Isolated failure',
        contentType: 'application/json',
        body: Uint8List(0),
      );
  ProductAssetHttpResponse imageResponse() => ProductAssetHttpResponse(
    statusCode: 200,
    statusText: 'OK',
    contentType: 'image/png',
    body: imageBytes,
  );
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    requests.add(uri);
    expect(headers['Authorization'], 'Bearer fixture-asset-token');
    return response();
  }

  void release() {
    for (final gate in pending) {
      if (!gate.isCompleted) gate.complete(failure());
    }
  }
}

class InventoryLinkLauncher implements ExternalUrlLauncher {
  final uris = <Uri>[];
  Completer<bool>? gate;
  bool throwOnOpen = false;
  @override
  Future<bool> open(Uri uri) async {
    uris.add(uri);
    if (throwOnOpen) throw StateError('isolated launcher failure');
    return gate == null ? true : await gate!.future;
  }

  void release() {
    if (gate case final g? when !g.isCompleted) g.complete(false);
  }
}
