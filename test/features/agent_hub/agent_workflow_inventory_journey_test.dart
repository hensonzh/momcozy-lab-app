import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
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
  bool failClipboard = false;
  Future<void> mount(
    WidgetTester tester, {
    void Function(AgentWorkflowInventoryTransport)? prepare,
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
          onArtifactAction: (action) =>
              dispatchAgentArtifactAction(context, action),
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
        'test/goldens/ui_inventory/agent-workflow-journey-$state-$suffix.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/agent-workflow-journey-$state-$suffix.png',
      ),
    );
    final row = {
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Authenticated More → tap Cozymate bottom navigation',
      'evidence':
          'Actual MomCozyFlutterApp/createMomCozyRouter/AgentHubPage via public agentHubBuilder; production SSE parser, runner with default retries, cancel client and profile repository; isolated SSE/control/ticket HTTP and voice dependencies; production action client and support ticket repository. History disabled as in default local build; no remote model request.',
      'test':
          'test/features/agent_hub/agent_workflow_inventory_journey_test.dart',
    };
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File(
        '$output/journeys/agent-workflow-journey-$state-$suffix.json',
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

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder field(String artifact, String id) => find.descendant(
    of: key('agent-artifact-form-field-$artifact-$id'),
    matching: find.byType(TextFormField),
  );
  Future<void> edit(WidgetTester tester, Finder target, String value) async {
    await tester.ensureVisible(target);
    await tester.enterText(target, value);
    await frame(tester);
  }

  Future<void> openForm(
    WidgetTester tester, {
    bool ticket = false,
    String? scenario,
  }) async {
    final prefix = scenario ?? (ticket ? 'ticket' : 'intake');
    if (ticket) {
      await send(tester, '我需要设备使用方面的售后支持。');
    } else {
      await tap(tester, find.text('产后康复评估'));
      expect(transport.requests.single.message, contains('产后身体恢复评估'));
    }
    await capture(
      tester,
      '$prefix-request',
      ticket
          ? 'Type and send a support request'
          : 'Tap recovery assessment shortcut → actual preset request sent',
    );
    transport.publish(0, 'artifact.created', 1, {
      'artifact_type': 'form',
      'schema_version': '1.0',
      'form': {
        'id': ticket ? 'support_ticket' : 'lactation_support_intake',
        'title': ticket ? '售后支持信息' : '恢复支持信息',
        'submit_label': '提交信息',
        'fields': ticket
            ? [
                {
                  'id': 'issue_summary',
                  'label': '问题说明',
                  'type': 'textarea',
                  'required': true,
                },
                {
                  'id': 'issue_type',
                  'label': '问题类型',
                  'type': 'select',
                  'options': ['设备故障', '使用帮助'],
                  'default_value': '使用帮助',
                },
                {'id': 'user_contact', 'label': '联系邮箱', 'type': 'text'},
              ]
            : [
                {
                  'id': 'notes',
                  'label': '基本信息｜补充说明',
                  'type': 'textarea',
                  'required': true,
                },
                {
                  'id': 'time',
                  'label': '偏好｜沟通时间',
                  'type': 'radio',
                  'options': ['上午', '晚上'],
                },
                {
                  'id': 'followup',
                  'label': '偏好｜跟进方式',
                  'type': 'select',
                  'options': ['简短沟通', '详细交流'],
                },
                {
                  'id': 'date',
                  'label': '偏好｜开始日期',
                  'type': 'date',
                  'default_value': '2026-09-12',
                },
                {
                  'id': 'concerns',
                  'label': '关注事项',
                  'type': 'multi_select',
                  'options': ['休息', '其它'],
                  'allow_other_input': true,
                },
              ],
      },
    }, artifactId: ticket ? 'ticket' : 'intake');
    await frame(tester);
    expect(find.byType(AgentArtifactFormDialog), findsNothing);
    await finish(tester, 0, '请补充以下信息；这些是隔离的测试示例。', first: 2);
    await capture(
      tester,
      '$prefix-auto-loading',
      'Assistant completes → live form entry waiting to auto-open',
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await frame(tester);
    expect(find.byType(AgentArtifactFormDialog), findsOneWidget);
    await capture(
      tester,
      '$prefix-auto-open',
      'Production one-second presentation timer → form dialog',
    );
  }

  for (final width in [393.0, 320.0]) {
    testWidgets(
      'inventory workflow intake controls and accepted submission $width',
      (tester) async {
        await mount(tester, width: width, textScale: width == 320 ? 2 : 1);
        await openForm(tester);
        final submit = key('agent-artifact-form-submit-intake');
        final cancel = key('agent-artifact-form-cancel-intake');
        await tap(tester, submit);
        expect(transport.requests, hasLength(1));
        expect(find.text('请补充：补充说明'), findsOneWidget);
        await capture(
          tester,
          'intake-validation',
          'Submit empty required notes → inline validation',
        );
        await edit(tester, field('intake', 'notes'), '希望了解今天的恢复状态。\n仅用于界面盘点。');
        await tap(tester, find.text('上午'));
        await tap(tester, find.byType(DropdownButtonFormField<String>));
        await capture(tester, 'intake-dropdown', 'Open follow-up dropdown');
        await tap(tester, find.text('详细交流').last);
        await tap(tester, field('intake', 'date'));
        await capture(tester, 'intake-date-picker', 'Open form date picker');
        final ok = MaterialLocalizations.of(
          tester.element(find.byType(DatePickerDialog)),
        ).okButtonLabel;
        final dateInput = find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextFormField),
        );
        if (dateInput.evaluate().isNotEmpty) {
          await edit(tester, dateInput, '2026/09/20');
        } else {
          await tap(tester, find.text('20').last);
        }
        await capture(
          tester,
          'intake-date-selected',
          'Select day 20 in September 2026',
        );
        await tap(tester, find.text(ok));
        await tap(tester, find.text('其它'));
        await edit(
          tester,
          key('agent-artifact-form-other-intake-concerns'),
          '日常安排',
        );
        await capture(
          tester,
          'intake-filled',
          'Enter notes, radio, dropdown, date and other concern',
        );
        await tap(tester, cancel);
        expect(find.byType(AgentArtifactFormDialog), findsNothing);
        await capture(
          tester,
          'intake-cancelled',
          'Cancel form → entry remains in conversation',
        );
        await tap(tester, key('agent-artifact-form-entry-intake'));
        expect(
          tester.widget<TextFormField>(field('intake', 'notes')).initialValue,
          contains('仅用于界面盘点'),
        );
        await capture(
          tester,
          'intake-draft-return',
          'Reopen form → draft values retained',
        );
        await tap(tester, submit);
        expect(transport.requests, hasLength(2));
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        final submission =
            transport.requests.last.metadata['form_submission'] as Map;
        expect((submission['values'] as Map)['date'], '2026-09-20');
        await capture(
          tester,
          'intake-submitting',
          'Submit → synthetic SSE request awaits server run signal',
        );
        transport.emit(1, 'run.started', 1, {});
        await frame(tester);
        expect(find.byType(AgentArtifactFormDialog), findsNothing);
        await capture(
          tester,
          'intake-accepted',
          'Server run starts → dialog closes and submitted entry retained',
        );
        await finish(tester, 1, '信息已收到，可以继续交流。', first: 2);
        await capture(tester, 'intake-reply', 'Follow-up response completes');
        // The submitted form lives above the latest response in the transcript.
        await tester.scrollUntilVisible(
          key('agent-artifact-form-entry-intake'),
          -180,
          scrollable: find
              .descendant(
                of: key('agent-chat-scroll-view'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tap(tester, key('agent-artifact-form-entry-intake'));
        expect(submit, findsNothing);
        await capture(
          tester,
          'intake-readonly',
          'Open submitted form → read-only values',
        );
        await tap(tester, cancel);
        await capture(
          tester,
          'intake-readonly-return',
          'Close read-only form → same conversation',
        );
      },
    );
  }

  testWidgets('inventory workflow support ticket retry and submitted detail', (
    tester,
  ) async {
    await mount(tester);
    await openForm(tester, ticket: true);
    final submit = key('agent-artifact-form-submit-ticket');
    await edit(tester, field('ticket', 'issue_summary'), '测试设备的使用说明问题。');
    await edit(
      tester,
      field('ticket', 'user_contact'),
      'inventory@example.invalid',
    );
    transport.ticketGate = Completer<void>();
    transport.failTicket = true;
    await tap(tester, submit);
    expect(transport.ticketBodies, hasLength(1));
    expect(transport.requests, hasLength(1));
    await capture(
      tester,
      'ticket-submitting',
      'Submit support form → production ticket repository HTTP pending',
    );
    transport.ticketGate!.complete();
    await frame(tester);
    expect(find.text('提交失败，请重试'), findsOneWidget);
    await capture(
      tester,
      'ticket-failed',
      'HTTP 503 → error with form draft retained',
    );
    transport.ticketGate = Completer<void>();
    transport.failTicket = false;
    await tap(tester, submit);
    expect(transport.ticketKeys[0], transport.ticketKeys[1]);
    await capture(
      tester,
      'ticket-retrying',
      'Retry same ticket body and idempotency key',
    );
    transport.ticketGate!.complete();
    await frame(tester);
    expect(find.byType(AgentArtifactFormDialog), findsNothing);
    expect(transport.requests, hasLength(1));
    await capture(
      tester,
      'ticket-submitted',
      'Ticket accepted → local confirmation message without model request',
    );
    await tester.scrollUntilVisible(
      key('agent-artifact-form-entry-ticket'),
      -180,
      scrollable: find
          .descendant(
            of: key('agent-chat-scroll-view'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tap(tester, key('agent-artifact-form-entry-ticket'));
    expect(submit, findsNothing);
    await capture(
      tester,
      'ticket-readonly',
      'Open submitted ticket form → read-only',
    );
    await tap(tester, key('agent-artifact-form-cancel-ticket'));
    await capture(
      tester,
      'ticket-return',
      'Close ticket detail → retained conversation',
    );
  });

  testWidgets(
    'inventory workflow milk shortcut artifact routes and latest button',
    (tester) async {
      await mount(tester, width: 320, textScale: 2);
      await tap(tester, find.text('奶量分析'));
      expect(transport.requests.single.message, '帮我分析最近的奶量记录，告诉我可以先关注哪些变化。');
      await capture(
        tester,
        'milk-request',
        'Tap milk analysis shortcut → preset question sent',
      );
      transport.publish(0, 'artifact.created', 1, {
        'artifact_type': 'rich_text',
        'title': '记录入口',
        'content': '以下入口用于查看当前记录。',
        'steps': ['泌乳记录包含每次保存的内容。', '身体记录用于回顾今日状态。'],
        'actions': [
          {'kind': 'route', 'label': '查看泌乳记录', 'value': '/me/lactation'},
          {'kind': 'route', 'label': '查看身体记录', 'value': '/me/diary'},
        ],
      }, artifactId: 'record-links');
      await finish(tester, 0, '可以从记录详情了解变化。', first: 2);
      await capture(
        tester,
        'milk-result',
        'Response completes → actionable record card',
      );
      await tester.drag(key('agent-chat-scroll-view'), const Offset(0, 500));
      await frame(tester);
      expect(key('agent-scroll-latest-button'), findsOneWidget);
      await capture(
        tester,
        'latest-off-bottom',
        'Scroll towards earlier messages → latest-message button appears',
      );
      await tap(tester, key('agent-scroll-latest-button'));
      await tester.pumpAndSettle();
      expect(key('agent-scroll-latest-button'), findsNothing);
      await capture(
        tester,
        'latest-returned',
        'Tap latest-message button → scroll to newest response',
      );
      await tap(tester, find.text('查看泌乳记录'));
      await capture(
        tester,
        'milk-history',
        'Tap artifact link → actual lactation history',
        route: '/me/lactation',
      );
      await tap(tester, find.byTooltip('关闭泌乳记录'));
      if (router.state.uri.path != '/') {
        await tap(tester, key('bottom-nav-cozymate'));
      }
      await capture(
        tester,
        'milk-return',
        'Cozymate tab → original response and artifact retained',
      );
      await tap(tester, find.text('查看身体记录'));
      await capture(
        tester,
        'diary-history',
        'Tap artifact link → actual mother diary',
        route: '/me/diary',
      );
      await tap(tester, find.byTooltip('关闭记录'));
      if (router.state.uri.path != '/') {
        await tap(tester, key('bottom-nav-cozymate'));
      }
      await capture(
        tester,
        'diary-return',
        'Cozymate tab → original conversation retained',
      );
    },
  );

  testWidgets('inventory workflow intake transport failure and retry', (
    tester,
  ) async {
    await mount(tester);
    await openForm(tester, scenario: 'retry-intake');
    await edit(tester, field('intake', 'notes'), '保留这份测试草稿。');
    final submit = key('agent-artifact-form-submit-intake');
    transport.failConnections = true;
    await tap(tester, submit);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(transport.requests, hasLength(5));
    expect(find.text('提交失败，请重试'), findsOneWidget);
    await capture(
      tester,
      'retry-intake-failed',
      'Three SSE retries exhausted before acceptance → editable form failure',
    );
    final originalKey = transport.requests[1].idempotencyKey;
    transport.failConnections = false;
    await tap(tester, submit);
    expect(transport.requests.last.idempotencyKey, originalKey);
    await capture(
      tester,
      'retry-intake-pending',
      'Retry form → same data and idempotency key',
    );
    final index = transport.requests.length - 1;
    transport.emit(index, 'run.started', 1, {});
    await frame(tester);
    expect(find.byType(AgentArtifactFormDialog), findsNothing);
    await capture(
      tester,
      'retry-intake-accepted',
      'Retried run accepted → form closes',
    );
    await finish(tester, index, '重试提交已收到。', first: 2);
    await capture(
      tester,
      'retry-intake-completed',
      'Retried response completes',
    );
  });

  for (final reject in [false, true]) {
    for (final fails in [false, true]) {
      testWidgets('inventory workflow action $reject failure $fails', (
        tester,
      ) async {
        await mount(tester);
        final operation = reject ? 'reject' : 'confirm';
        final prefix = '$operation-${fails ? 'failure' : 'success'}';
        await send(tester, '请处理这个隔离的测试日程。');
        transport.publish(0, 'action.confirmation_required', 1, {
          'action_type': 'schedule_task_delete',
          'summary': '删除测试日程',
          'preview_payload': {
            'title': '删除测试日程',
            'target': '测试日程',
            'before': '2026-09-13 14:00',
            'after': '删除',
            'date': '2026-09-13',
            'timezone': 'Asia/Shanghai',
            'impact_scope': '仅此任务',
          },
        }, actionId: 'schedule-delete');
        await finish(tester, 0, '请确认是否执行上述变更。', first: 2);
        await capture(
          tester,
          '$prefix-preview',
          'Receive authoritative action preview → controls available',
        );
        final button = key('agent-action-$operation-schedule-delete');
        transport.actionStatus = fails ? 503 : 200;
        transport.actionResult = reject ? 'rejected' : 'applied';
        transport.actionGate = Completer<void>();
        await tap(tester, button);
        await capture(
          tester,
          '$prefix-pending',
          'Tap action $operation → HTTP pending',
        );
        transport.actionGate!.complete();
        await frame(tester);
        expect(button, findsNothing);
        expect(
          transport.controls.last.path,
          '/v1/agent/actions/schedule-delete/$operation',
        );
        expect(transport.requests, hasLength(1));
        await capture(
          tester,
          '$prefix-result',
          fails
              ? 'HTTP 503 → failed action; confirm/reject controls disappear, no retry entry'
              : 'HTTP 200 → authoritative ${transport.actionResult} state',
        );
        await tap(tester, key('bottom-nav-more'));
        await capture(
          tester,
          '$prefix-away',
          'More tab after action result',
          route: '/more',
        );
        await tap(tester, key('bottom-nav-cozymate'));
        await capture(
          tester,
          '$prefix-return',
          'Return to Cozymate → action result retained',
        );
      });
    }
  }
}
