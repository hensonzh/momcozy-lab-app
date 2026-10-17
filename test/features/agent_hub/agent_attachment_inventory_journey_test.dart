import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
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
import '../../support/agent_attachment_inventory_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentAttachmentInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  bool failClipboard = false;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentAttachmentInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    failClipboard = false;
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
    transport = AgentAttachmentInventoryTransport();
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
        multipartTransport: transport,
        mediaContentRepository: MediaContentRepository(
          baseUri: Uri.parse('https://inventory.invalid/'),
          connector: transport,
        ),

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
      agentHubBuilder: (context, uri, extra) {
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
          greetingProfileLoader:
              api.agentHubProfileRepository.fetchGreetingProfile,
          requestBuilder: (message) =>
              buildSessionAgentHubRequest(message, session: api.currentSession),

          mediaRepository: api.mediaRepository,
          pickImage: transport.pickImage,
          pickDocument: transport.pickDocument,
          loadImageThumbnail: api.mediaContentRepository.loadImageThumbnail,
          loadImageContent: api.mediaContentRepository.loadImage,
          onApplicationEvent: api.handleAgentApplicationEvent,
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
        'assets/images/mom/milk-hero.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.tap(find.byKey(const ValueKey('bottom-nav-momcozy ai')));
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
      transport.releaseMediaGates();
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

  Future<void> verifyState(WidgetTester tester, {String route = '/'}) async {
    // Commit edits and finish the input hint's fade without settling spinners.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
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

  Future<void> choose(WidgetTester tester, String source) async {
    await tap(tester, find.byKey(const ValueKey('agent-attachment-button')));
    await tap(tester, find.byKey(ValueKey('agent-attachment-$source-button')));
  }

  Future<void> decodeImages(WidgetTester tester) async {
    await frame(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await frame(tester);
  }

  Future<void> dismissNotice(WidgetTester tester, String state) async {
    if (find.byType(SnackBar).evaluate().isEmpty) return;
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.drag(find.byType(SnackBar), const Offset(0, 180));
      await frame(tester);
    }
    expect(find.byType(SnackBar), findsNothing);
    await verifyState(tester);
  }

  for (final width in [393.0, 320.0]) {
    testWidgets(
      'inventory attachment upload removal and tab retention $width',
      (tester) async {
        await mount(tester, width: width, textScale: width == 320 ? 2 : 1);
        await tester.enterText(input, 'Keep this unsent draft');
        final uploadGate = Completer<void>();
        transport.uploadGate = uploadGate;
        await choose(tester, 'photo');
        expect(transport.uploads.length, 1);
        expect(tester.widget<TextField>(input).enabled, isFalse);
        await verifyState(tester);
        uploadGate.complete();
        transport.uploadGate = null;
        await decodeImages(tester);
        expect(
          find.byKey(const ValueKey('agent-image-attachment-0')),
          findsOneWidget,
        );
        await verifyState(tester);
        await tap(tester, find.byKey(const ValueKey('bottom-nav-more')));
        await verifyState(tester, route: '/more');
        await tap(tester, find.byKey(const ValueKey('bottom-nav-momcozy ai')));
        expect(
          tester.widget<TextField>(input).controller!.text,
          'Keep this unsent draft',
        );
        expect(
          find.byKey(const ValueKey('agent-image-attachment-0')),
          findsOneWidget,
        );
        await verifyState(tester);
        final deleteGate = Completer<void>();
        transport.deleteGate = deleteGate;
        transport.deleteStatus = 503;
        await tap(
          tester,
          find.byKey(const ValueKey('agent-remove-image-button')),
        );
        await verifyState(tester);
        deleteGate.complete();
        transport.deleteGate = null;
        await frame(tester);
        expect(find.text('附件清理失败，已保留草稿，请重试。'), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-image-attachment-0')),
          findsNothing,
        );
        expect(tester.widget<TextField>(input).enabled, isNot(false));
        transport.deleteStatus = 200;
        await tester.pump(const Duration(seconds: 30));
        await frame(tester);
        expect(transport.deleteRequests.length, 2);
        expect(transport.deleteKeys.toSet().length, 1);
        expect(
          find.byKey(const ValueKey('agent-image-attachment-0')),
          findsNothing,
        );
        expect(
          tester.widget<TextField>(input).controller!.text,
          'Keep this unsent draft',
        );
        await verifyState(tester);
      },
    );

    testWidgets('inventory attachment mixed send and image viewer $width', (
      tester,
    ) async {
      await mount(tester, width: width, textScale: width == 320 ? 2 : 1);
      await choose(tester, 'camera');
      await decodeImages(tester);
      await choose(tester, 'file');
      await decodeImages(tester);
      expect(transport.uploads.length, 2);
      await verifyState(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-file-attachment-0')),
      );
      await frame(tester);
      await verifyState(tester);
      await send(tester, 'Review these isolated attachments');
      expect(transport.requests.single.images.length, 1);
      expect(transport.requests.single.files.length, 1);
      expect(transport.deleteRequests, isEmpty);
      await verifyState(tester);
      await finish(tester, 0, 'The example attachments were received.');
      await decodeImages(tester);
      await verifyState(tester);
      final sentImage = find.byKey(const ValueKey('agent-sent-image-0'));
      if (sentImage.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          sentImage,
          -200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('agent-chat-scroll-view')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await frame(tester);
      }
      await tap(tester, sentImage);
      await decodeImages(tester);
      expect(find.byKey(const ValueKey('agent-image-stage')), findsOneWidget);
      await verifyState(tester);
      final stage = find.byKey(const ValueKey('agent-image-stage'));
      final center = tester.getCenter(stage);
      final first = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await first.moveTo(center - const Offset(80, 0));
      await second.moveTo(center + const Offset(80, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await frame(tester);
      expect(
        tester
            .widget<InteractiveViewer>(stage)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await verifyState(tester);
      await tester.drag(stage, const Offset(70, 100));
      await frame(tester);
      await verifyState(tester);
      await tap(tester, find.byKey(const ValueKey('agent-sent-image-close')));
      expect(find.byKey(const ValueKey('agent-image-stage')), findsNothing);
      await verifyState(tester);
      await tap(tester, find.byKey(const ValueKey('agent-sent-file-0')));
      expect(
        find.byKey(const ValueKey('agent-sent-image-close')),
        findsNothing,
      );
      expect(router.state.uri.path, '/');
      await verifyState(tester);
    });
  }

  testWidgets('inventory attachment picker cancellation and failure', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(input, 'Unchanged draft');
    for (final source in ['camera', 'photo', 'file']) {
      final gate = Completer<void>();
      transport.pickerGate = gate;
      transport.cancelPick = true;
      await choose(tester, source);
      await verifyState(tester);
      gate.complete();
      transport.pickerGate = null;
      await frame(tester);
      expect(transport.uploads, isEmpty);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Unchanged draft',
      );
      await verifyState(tester);
    }
    transport.cancelPick = false;
    transport.failPick = true;
    await choose(tester, 'camera');
    expect(find.text('Image upload failed. Try again.'), findsOneWidget);
    await verifyState(tester);
    await dismissNotice(tester, 'camera-failure-dismissed');
    await choose(tester, 'file');
    expect(find.text('File upload failed. Try again.'), findsOneWidget);
    await verifyState(tester);
    expect(transport.uploads, isEmpty);
  });

  testWidgets(
    'inventory attachment PDF validation upload retry and file only send',
    (tester) async {
      await mount(tester);
      for (final mode in ['unsupported', 'oversized', 'empty']) {
        transport.documentMode = mode;
        await choose(tester, 'file');
        await frame(tester);
        expect(transport.uploads, isEmpty);
        if (mode == 'unsupported') {
          expect(
            find.text('Only PDF files are supported for now.'),
            findsOneWidget,
          );
        }
        if (mode == 'oversized') {
          expect(find.text('Files must be 10 MB or smaller.'), findsOneWidget);
        }
        await verifyState(tester);
        await dismissNotice(tester, 'pdf-$mode-notice-dismissed');
      }
      transport.documentMode = 'pdf';
      transport.failUpload = true;
      await choose(tester, 'file');
      expect(transport.uploads.length, 1);
      expect(
        find.byKey(const ValueKey('agent-file-attachment-0')),
        findsNothing,
      );
      await verifyState(tester);
      await dismissNotice(tester, 'pdf-upload-failure-dismissed');
      transport.failUpload = false;
      await choose(tester, 'file');
      expect(transport.uploads.length, 2);
      await verifyState(tester);
      await tap(tester, sendButton);
      expect(transport.requests.single.message, 'Please review this file');
      expect(transport.requests.single.files.length, 1);
      await finish(tester, 0, 'The isolated PDF request is complete.');
      await verifyState(tester);
    },
  );

  testWidgets('inventory attachment image upload failure and preview retry', (
    tester,
  ) async {
    await mount(tester);
    transport.failUpload = true;
    await choose(tester, 'photo');
    expect(find.text('Image upload failed. Try again.'), findsOneWidget);
    await verifyState(tester);
    await dismissNotice(tester, 'image-upload-failure-dismissed');
    transport.failUpload = false;
    transport.brokenImage = true;
    await choose(tester, 'photo');
    await decodeImages(tester);
    await verifyState(tester);
    await tap(tester, sendButton);
    expect(transport.requests.single.message, 'Please look at this image');
    await finish(tester, 0, 'The isolated image request is complete.');
    await tap(tester, find.byKey(const ValueKey('agent-sent-image-0')));
    await decodeImages(tester);
    expect(
      find.byKey(const ValueKey('media-viewer-load-error')),
      findsOneWidget,
    );
    await verifyState(tester);
    transport.contentStatus = 503;
    await tap(tester, find.byKey(const ValueKey('media-viewer-retry')));
    expect(transport.contentRequests.length, 1);
    await verifyState(tester);
    transport.contentStatus = 200;
    final gate = Completer<void>();
    transport.contentGate = gate;
    await tap(tester, find.byKey(const ValueKey('media-viewer-retry')));
    expect(find.byKey(const ValueKey('media-viewer-loading')), findsOneWidget);
    await verifyState(tester);
    gate.complete();
    transport.contentGate = null;
    await decodeImages(tester);
    expect(find.byKey(const ValueKey('agent-image-stage')), findsOneWidget);
    expect(transport.contentRequests.length, 2);
    await verifyState(tester);
    await tap(tester, find.byKey(const ValueKey('agent-sent-image-close')));
    await verifyState(tester);
  });
}
