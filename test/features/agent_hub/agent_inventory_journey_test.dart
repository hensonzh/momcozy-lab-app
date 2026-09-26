import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
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
import '../../support/agent_inventory_transport.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  late AgentInventoryTransport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  String? previous;
  bool failClipboard = false;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentInventoryTransport)? prepare,
    bool loading = false,
    double width = 393,
    double textScale = 1,
  }) async {
    previous = null;
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
    transport = AgentInventoryTransport();
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
        multipartTransport: FixtureApiMultipartTransport({}),

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
          pickImage: api.agentHubImagePicker,
          pickDocument: api.agentHubDocumentPicker,
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
    final source = 'test/goldens/ui_inventory/agent-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Momcozy AI bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage via public agentHubBuilder; production SSE parser, runner with default retries, cancel client and profile repository; isolated SSE/control HTTP/voice dependencies. History disabled as in default local build; no remote model request.',
      'test': 'test/features/agent_hub/agent_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/agent-journey-$state-$suffix.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(row)}\n',
      );
    }
  }

  final input = find.byKey(const ValueKey('agent-composer-input'));
  final sendButton = find.byKey(const ValueKey('agent-send-button'));
  final retry = find.byKey(const ValueKey('agent-retry-button'));
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

  testWidgets('inventory agent default home controls and draft retention', (
    tester,
  ) async {
    await mount(tester);
    expect(
      find.byKey(const ValueKey('agent-conversation-history-button')),
      findsNothing,
    );
    await capture(
      tester,
      'home',
      'More → Momcozy AI; default history entry disabled',
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/cozymate_attachment_camera.png'),
        tester.element(find.byType(AgentComposerBar)),
      ),
    );
    await tap(tester, find.byKey(const ValueKey('agent-attachment-button')));
    await capture(
      tester,
      'attachment-menu',
      'Composer add → supported attachment sources',
    );
    await tester.tapAt(const Offset(30, 180));
    await frame(tester);
    await tester.enterText(input, 'Inventory draft not sent');
    await capture(tester, 'draft', 'Enter unsent composer draft');
  });

  testWidgets('inventory agent real reply and tab retention', (tester) async {
    await mount(tester);
    const question = 'Local inventory message';
    const answer = '**Inventory reply**\n\nThis is isolated test content.';
    await send(tester, question);
    await capture(
      tester,
      'sent-waiting',
      'Send message → waiting for first SSE event',
    );
    expect(transport.requests.single.message, question);
    transport.emit(0, 'run.started', 1, {});
    transport.emit(0, 'message.delta', 2, {'text': '**Inventory reply**'});
    await frame(tester);
    await capture(tester, 'streaming', 'Receive SSE delta → live response');
    await finish(tester, 0, answer, first: 3);
    await capture(tester, 'reply', 'SSE completion → final Markdown response');
    await tap(tester, find.byKey(const ValueKey('bottom-nav-more')));
    await capture(
      tester,
      'tab-more',
      'More tab → agent remains mounted offstage',
      route: '/more',
    );
    await tap(tester, find.byKey(const ValueKey('bottom-nav-momcozy ai')));
    expect(find.text(question), findsOneWidget);
    await capture(
      tester,
      'tab-return',
      'Return to Momcozy AI → existing exchange retained',
    );
  });

  testWidgets(
    'inventory agent connection retries partial resume and terminal failure',
    (tester) async {
      await mount(tester);
      await send(tester, 'Inventory retry request');
      transport.failConnections = true;
      transport.fail(0);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(transport.requests.length, 4);
      expect(retry, findsOneWidget);
      await capture(
        tester,
        'disconnected-empty',
        'Connection fails through three automatic retries → retry UI',
      );
      transport.failConnections = false;
      await tap(tester, retry);
      final first = transport.requests.length - 1;
      expect(
        transport.requests[first].idempotencyKey,
        transport.requests.first.idempotencyKey,
      );
      await capture(
        tester,
        'manual-retry',
        'Manual retry → same idempotency key',
      );
      transport.emit(first, 'run.started', 1, {});
      transport.emit(first, 'message.delta', 2, {
        'text': 'Partial inventory answer',
      });
      await frame(tester);
      await tester.enterText(input, 'Next unsent draft');
      transport.failConnections = true;
      transport.fail(first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await capture(
        tester,
        'disconnected-partial',
        'Retry exhaustion after delta → partial answer and next draft retained',
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Next unsent draft',
      );
      transport.failConnections = false;
      await tap(tester, retry);
      final resumed = transport.requests.length - 1;
      expect(transport.requests.last.runId, 'inventory-run-$first');
      expect(transport.requests.last.afterSequence, 2);
      await finish(
        tester,
        resumed,
        'Partial inventory answer, now complete.',
        run: first,
        first: 3,
      );
      await capture(
        tester,
        'resumed',
        'Retry from message menu → resume cursor and final answer',
      );
      await send(tester, 'Inventory terminal error');
      final failed = transport.requests.length - 1;
      transport.emit(failed, 'run.failed', 1, {
        'code': 'runtime_error',
        'message': 'internal fixture details',
      });
      await frame(tester);
      expect(find.textContaining('internal fixture details'), findsNothing);
      await capture(
        tester,
        'terminal-error',
        'Terminal run failure → safe feedback and editable input',
      );
    },
  );

  for (final acknowledged in [true, false]) {
    testWidgets('inventory agent cancel acknowledged $acknowledged', (
      tester,
    ) async {
      await mount(tester);
      final tag = acknowledged ? 'cancel' : 'cancel-unconfirmed';
      await send(tester, 'Inventory cancellation request');
      transport.emit(0, 'run.started', 1, {});
      transport.emit(0, 'message.delta', 2, {
        'text': 'Partial reply before stopping.',
      });
      await frame(tester);
      transport.cancelStatus = acknowledged ? 200 : 503;
      final gate = Completer<void>();
      transport.cancelGate = gate;
      await tap(tester, find.byTooltip('Stop'));
      await capture(
        tester,
        '$tag-pending',
        'Stop response → cancellation HTTP pending',
      );
      gate.complete();
      transport.cancelGate = null;
      await frame(tester);
      expect(
        transport.controls.single.path.endsWith('/inventory-run-0/cancel'),
        isTrue,
      );
      await capture(
        tester,
        '$tag-finished',
        'Cancellation status ${transport.cancelStatus} → local result',
      );
    });
  }

  for (final width in [393.0, 320.0]) {
    testWidgets('inventory agent long response and manual follow-up $width', (
      tester,
    ) async {
      await mount(tester, width: width, textScale: width == 320 ? 2 : 1);
      await send(tester, 'Please show the inventory example notes.');
      const answer =
          '## Example notes\n\n'
          'This conversation contains isolated test data for reviewing the app interface.\n\n'
          '### Today\n\n'
          '- First entry: a short note.\n- Second entry: another observation.\n- Third entry: a follow-up question.\n\n'
          '### Review\n\n'
          'Each saved entry can be reviewed in its original page. A draft stays editable until it is submitted.\n\n'
          '### Navigation\n\n'
          'The bottom tabs let you move between the conversation, your records and your schedule.\n\n'
          '### Next conversation\n\n'
          'You can select one of the suggestions below or write a different question in the input field.';
      transport.emit(0, 'message.completed', 1, {
        'role': 'assistant',
        'text': answer,
        'quick_replies': [
          {'text': 'Review entries'},
          {'text': 'Show schedule'},
          {'text': 'Ask another question'},
        ],
      });
      transport.emit(0, 'run.completed', 2, {});
      await frame(tester);
      await capture(
        tester,
        'long-reply',
        'Receive long Markdown and quick-reply payload; current page omits quick-reply controls',
      );
      // Production AgentHubPage explicitly passes a null quick-reply callback.
      expect(find.byKey(const ValueKey('agent-quick-reply-0')), findsNothing);
      await send(tester, 'Review entries');
      expect(transport.requests.length, 2);
      expect(transport.requests.last.message, 'Review entries');
      await capture(
        tester,
        'long-followup-sent',
        'Type and send a follow-up → second message in the same conversation',
      );
      await finish(tester, 1, 'The next response is complete.');
      await capture(
        tester,
        'long-followup-completed',
        'Second response completes → two exchanges retained',
      );
    });
  }

  testWidgets('inventory agent stop before run id and profile fallback', (
    tester,
  ) async {
    await mount(
      tester,
      prepare: (api) => api.failingReads.add('/v1/profile/me'),
    );
    await capture(
      tester,
      'profile-fallback',
      'Profile request fails → usable generic greeting and composer',
    );
    await send(tester, 'Stop before first event');
    await tap(tester, find.byTooltip('Stop'));
    expect(transport.controls, isEmpty);
    await capture(
      tester,
      'stop-before-run-id',
      'Stop before server run identifier → local stop',
    );
    await send(tester, 'Start another request');
    expect(transport.requests.length, 2);
    await finish(tester, 1, 'A later request can complete.');
    await capture(
      tester,
      'after-early-stop',
      'Send again after early stop → completed response',
    );
  });
}
