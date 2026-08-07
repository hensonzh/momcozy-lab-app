import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';
import '../../support/fake_agent_voice.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          return switch (call.method) {
            'read' => null,
            'readAll' => <String, String>{},
            'containsKey' => false,
            'write' || 'delete' || 'deleteAll' => null,
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('Flutter widget regression: 计划', () {
    testWidgets(
      'transfers an Agent plan update into refreshed highlighted schedule UI',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);
        final runtime = _runtime(
          responsesByPath: {
            schedulePlansEndpoint: const {
              'items': [
                {
                  'id': 'milk-plan-widget',
                  'plan_type': 'milk_management',
                  'title': '稳奶计划',
                  'summary': '按当前阶段稳步执行',
                  'status': 'active',
                  'version': 3,
                  'payload': {'postpartum_week': 29, 'phase': '离乳期'},
                },
              ],
            },
            schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
          },
        );

        final router = createMomCozyRouter(initialLocation: '/me');
        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: router,
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: runtime,
          ),
        );
        await tester.pumpAndSettle();

        runtime.milkPlanChangeStore.record(
          const MilkPlanChange(
            eventId: 'schedule-parity-plan-update',
            affectedDateKeys: ['2026-07-05'],
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('bottom-nav-plan')), findsOneWidget);
        expect(runtime.milkPlanChangeStore.hasUnread, isTrue);

        runtime.milkPlanChangeStore.transferNavigationNoticeToPage();
        router.go('/schedule');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('route-page-/schedule')),
          findsOneWidget,
        );
        expect(find.text('稳奶计划执行中'), findsOneWidget);
        expect(
          find.text('已经根据你今天的会议日程，对吸乳排期做了调整哦，记得按时吸奶，有问题随时找我'),
          findsOneWidget,
        );
        expect(find.text('待执行任务'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('schedule-highlighted-date-2026-07-05')),
          findsOneWidget,
        );
        expect(runtime.milkPlanChangeStore.hasUnread, isFalse);
        expect(runtime.milkPlanChangeStore.hasPageNotice, isFalse);
        expect(find.byKey(const ValueKey('bottom-nav-plan')), findsOneWidget);

        await _scrollToText(tester, '奶量计划已按最新权威数据刷新');
        await _scrollToFinder(
          tester,
          find.byKey(const ValueKey('schedule-quick-actions')),
        );
        final quickActions = find.byKey(
          const ValueKey('schedule-quick-actions'),
        );
        expect(
          find.descendant(of: quickActions, matching: find.text('吸奶补录')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: quickActions, matching: find.text('喂养记录')),
          findsOneWidget,
        );
      },
    );

    testWidgets('native schedule intent selects and focuses its linked task', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(routeIntentPlatform.dispose);
      final router = createMomCozyRouter(initialLocation: '/me');

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: _runtime(
            responsesByPath: {
              schedulePlansEndpoint: const {
                'items': [
                  {
                    'id': 'milk-plan-widget',
                    'plan_type': 'milk_management',
                    'title': '稳奶计划',
                    'summary': '按当前阶段稳步执行',
                    'status': 'active',
                    'version': 3,
                  },
                ],
              },
              schedulePumpingRecordsEndpoint: const {'items': <Object?>[]},
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      routeIntentPlatform.dispatchActiveRoute(
        const PendingNativeRoute(
          path: '/schedule?date=2026-07-04&task_id=feeding-afternoon',
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/schedule');
      expect(
        find.byKey(const ValueKey('schedule-highlighted-date-2026-07-04')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('schedule-timeline-task-feeding-afternoon')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Flutter widget regression: 智能体主页', () {
    testWidgets(
      'covers shell nav, top controls, transcript, fade, and composer',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-auto-voice-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-new-session-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-chat-scroll-view')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('agent-top-fade')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-run-transcript')),
          findsOneWidget,
        );
        expect(find.textContaining('嗨，我是 Cozymate'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-composer-bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-attachment-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('agent-composer-input')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('agent-voice-button')), findsNothing);
        expect(find.byKey(const ValueKey('agent-send-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('bottom-nav-agent')), findsOneWidget);
        final agentAvatar = tester.widget<Container>(
          find.byKey(const ValueKey('bottom-nav-agent-avatar')),
        );
        final agentAvatarDecoration = agentAvatar.decoration as BoxDecoration;
        final agentAvatarImage =
            agentAvatarDecoration.image?.image as AssetImage;
        expect(agentAvatarImage.assetName, MomCozyAssets.agentAvatar);

        final imageButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('agent-attachment-button')),
        );
        expect(imageButton.onPressed, isNotNull);
        await tester.enterText(
          find.byKey(const ValueKey('agent-composer-input')),
          '第一行\n第二行\n第三行',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('agent-composer-input')),
              )
              .controller
              ?.text,
          '第一行\n第二行\n第三行',
        );
      },
    );

    testWidgets(
      'replays bottom nav avatar wake animation when entering from another module',
      (tester) async {
        await _setCompactViewport(tester);
        final routeIntentPlatform = FakeRouteIntentPlatform();
        addTearDown(routeIntentPlatform.dispose);

        await tester.pumpWidget(
          MomCozyFlutterApp(
            router: createMomCozyRouter(initialLocation: '/schedule'),
            routeIntentPlatform: routeIntentPlatform,
            apiRuntime: _runtime(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('agent-hub-page')), findsNothing);
        expect(_agentAvatarPresenceScale(tester), closeTo(1, 0.001));
        expect(_agentAvatarWakeMedia(), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await _pumpUntilFinder(tester, _agentAvatarWakeMedia());
        await tester.pump(const Duration(milliseconds: 760));

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(_agentAvatarPresenceScale(tester), greaterThan(1.08));
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-halo'),
          greaterThan(0.2),
        );
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-ring-opacity'),
          greaterThan(0.2),
        );
        expect(_agentAvatarWakeMedia(), findsOneWidget);
        final firstWakeImage = tester.widget<Image>(_agentAvatarWakeMedia());
        expect(firstWakeImage.image, isA<MemoryImage>());
        final firstWakeKey = firstWakeImage.key;

        await tester.pumpAndSettle();
        expect(_agentAvatarPresenceScale(tester), closeTo(1, 0.001));
        expect(
          _opacityForKey(tester, 'bottom-nav-agent-avatar-wake-halo'),
          closeTo(0, 0.001),
        );
        expect(_agentAvatarWakeMedia(), findsNothing);

        await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('bottom-nav-agent')));
        await _pumpUntilFinder(tester, _agentAvatarWakeMedia());
        await tester.pump(const Duration(milliseconds: 760));

        expect(find.byKey(const ValueKey('agent-hub-page')), findsOneWidget);
        expect(_agentAvatarPresenceScale(tester), greaterThan(1.08));
        expect(_agentAvatarWakeMedia(), findsOneWidget);
        final secondWakeImage = tester.widget<Image>(_agentAvatarWakeMedia());
        expect(secondWakeImage.key, isNot(firstWakeKey));
      },
    );

    testWidgets('covers history bubbles, image preview, and latest button', (
      tester,
    ) async {
      await _setCompactViewport(tester);
      final client = _FixtureAgentStreamClient(
        parseAgentJsonl(
          readMigrationFixture('agent_events/text_stream_basic.jsonl'),
        ),
      );
      final history = List<AgentHubHistoryMessage>.generate(
        18,
        (index) => AgentHubHistoryMessage(
          role: index.isEven
              ? AgentHubHistoryRole.user
              : AgentHubHistoryRole.assistant,
          content: index.isEven ? '用户消息 $index' : '助手消息 $index',
        ),
      );

      await tester.pumpWidget(
        _agentHost(
          AgentHubPage(
            runner: AgentStreamRunner(client),
            historyMessages: history,
            pickImage: (_) async => const AgentStreamImageInput(
              dataUrl: 'data:image/png;base64,fixture',
              mimeType: 'image/png',
              name: 'legacy-widget.png',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('agent-history-panel')), findsOneWidget);
      expect(find.text('用户消息 0'), findsOneWidget);
      expect(find.text('助手消息 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-scroll-latest-button')),
        findsNothing,
      );
      expect(find.text('助手消息 17'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-attachment-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-attachment-menu')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-attachment-photo-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsOneWidget,
      );
      expect(find.text('图片 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-remove-image-button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('agent-remove-image-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-image-attachment-chip')),
        findsNothing,
      );
    });
  });
}

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MomCozyApiRuntime _runtime({
  Map<String, Map<String, Object?>>? responsesByPath,
}) {
  return MomCozyApiRuntime(
    jsonTransport: FixtureApiJsonTransportByPath({
      profileMeEndpoint: const {
        'user_id': 'demo-user-fixture',
        'delivery_date': '2026-06-12',
      },
      profileInfantsEndpoint: const {
        'items': [
          {
            'id': 'demo-baby-fixture',
            'owner_user_id': 'demo-user-fixture',
            'infant_name': 'Mia',
            'birth_date': '2026-04-06',
            'sex': 'female',
            'status': 'active',
          },
        ],
      },
      scheduleDayPlanEndpoint: const {
        'items': <Object?>[
          {
            'id': 'pump-morning',
            'owner_user_id': 'demo-user-fixture',
            'task_date': '2026-07-03',
            'task_time': '10:30',
            'title': '泵奶',
            'description': '',
            'status': 'completed',
            'payload': <String, Object?>{},
          },
          {
            'id': 'feeding-afternoon',
            'owner_user_id': 'demo-user-fixture',
            'task_date': '2026-07-03',
            'task_time': '14:00',
            'title': '喂养',
            'description': '',
            'status': 'pending',
            'payload': <String, Object?>{},
          },
          {
            'id': 'summary-evening',
            'owner_user_id': 'demo-user-fixture',
            'task_date': '2026-07-03',
            'task_time': '20:30',
            'title': '晚间复盘',
            'description': '',
            'status': 'pending',
            'payload': <String, Object?>{},
          },
        ],
      },
      ...?responsesByPath,
    }),
    agentVoicePlaybackPlayer: const ImmediateAgentVoicePlaybackPlayer(),
    clientEventClient: const AgentStreamClientEventClient(sent: false),
    multipartTransport: FixtureApiMultipartTransport(const <String, Object?>{
      'status': 200,
      'data': <String, Object?>{
        'text': '',
        'audio_url': '/audio/test-voice.mp3',
      },
    }),
    blePlatform: FakeBlePlatform(initialPermission: BlePermissionState.granted),
    userId: 'demo-user-widget-parity',
    babyId: 'demo-baby-widget-parity',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 3),
  );
}

Widget _agentHost(Widget child) {
  return MaterialApp(
    theme: momCozyTheme(),
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SafeArea(child: child)),
  );
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  await _scrollToFinder(tester, find.text(text));
}

Future<void> _scrollToFinder(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    return;
  }

  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) {
    expect(finder, findsOneWidget);
    return;
  }

  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: scrollable.first,
    duration: const Duration(milliseconds: 50),
    maxScrolls: 18,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFinder(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 20; index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

double _agentAvatarPresenceScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('bottom-nav-agent-avatar-presence-scale')),
  );
  return transform.transform.storage[0];
}

double _opacityForKey(WidgetTester tester, String key) {
  return tester.widget<Opacity>(find.byKey(ValueKey(key))).opacity;
}

Finder _agentAvatarWakeMedia() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('bottom-nav-agent-avatar-wake-media-');
  });
}

class _FixtureAgentStreamClient implements AgentStreamClient {
  _FixtureAgentStreamClient(this.events);

  final List<AgentStreamEvent> events;

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) async* {
    for (final event in events) {
      await Future<void>.delayed(Duration.zero);
      yield event;
    }
  }
}
