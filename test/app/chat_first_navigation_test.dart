import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'chat is sole home; drawer has three destinations and devices uses real owner data',
    (tester) async {
      final harness = await _Harness.create(role: 'father');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/');
      expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-first-workspace')),
        findsOneWidget,
      );
      expect(find.text('宝宝出生 3 天'), findsNothing);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Momcozy AI 工作区'), findsOneWidget);
      expect(find.bySemanticsLabel('和 Momcozy AI 打招呼'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('chat-first-menu')))
            .tooltip,
        '打开侧边栏',
      );
      semantics.dispose();
      await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer-baby')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-mother')), findsOneWidget);
      expect(find.byKey(const ValueKey('drawer-devices')), findsOneWidget);
      expect(find.text('妈妈'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('drawer-mother'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('drawer-baby'))).dy,
        ),
      );
      expect(find.byKey(const ValueKey('drawer-schedule')), findsNothing);
      expect(find.byKey(const ValueKey('drawer-more')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('drawer-devices')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/devices');
      expect(find.textContaining('没有已登记的设备'), findsOneWidget);
      expect(harness.transport.getPaths, contains('/v1/devices/pumps'));
      expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);
      final sectionSemantics = tester.ensureSemantics();
      expect(tester.getSemantics(find.byTooltip('更多服务')).tooltip, '更多服务');
      sectionSemantics.dispose();
      await tester.tap(find.byKey(const ValueKey('section-back-chat')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/');
      await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawer-mother')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/me');
      expect(find.text('妈妈'), findsOneWidget);
      expect(find.textContaining('未填写妈妈资料'), findsOneWidget);
      expect(find.text('Could not load. Please try again.'), findsNothing);
      expect(
        harness.transport.getPaths,
        isNot(contains('/v1/profile/me-experience')),
      );
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets(
    'whiteboard shows only a real saved maternal date; no fake progress for other roles',
    (tester) async {
      final mother = await _Harness.create(
        role: 'mother',
        deliveryDate: '2026-10-12',
      );
      await tester.pumpWidget(mother.app);
      await tester.pumpAndSettle();
      expect(find.text('宝宝出生 3 天'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      mother.dispose();
      final noDate = await _Harness.create(role: 'mother');
      await tester.pumpWidget(noDate.app);
      await tester.pumpAndSettle();
      expect(find.textContaining('宝宝出生'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      noDate.dispose();
    },
  );

  testWidgets('whiteboard uses the profile timezone, not host local day', (
    tester,
  ) async {
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
      timezone: 'Pacific/Honolulu',
      now: () => DateTime.utc(2026, 10, 16, 8, 30),
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    // October 16 UTC is still October 15 in Honolulu.
    expect(find.text('宝宝出生 3 天'), findsOneWidget);
    expect(find.text('宝宝出生 4 天'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('whiteboard refreshes at the account day boundary', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 16, 9, 59);
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
      timezone: 'Pacific/Honolulu',
      now: () => now,
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 3 天'), findsOneWidget);
    now = DateTime.utc(2026, 10, 16, 10, 1);
    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 4 天'), findsOneWidget);
    expect(find.text('宝宝出生 3 天'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('whiteboard reloads a changed profile when chat is reopened', (
    tester,
  ) async {
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 3 天'), findsOneWidget);
    mother.router.go('/me');
    await tester.pumpAndSettle();
    mother.transport.responsesByPath['/v1/profile/lactation'] = {
      'actual_delivery_date': '2026-10-11',
    };
    mother.router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 4 天'), findsOneWidget);
    expect(find.text('宝宝出生 3 天'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('invalid timezone never turns a date into a board fact', (
    tester,
  ) async {
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
      timezone: 'Not/A_Timezone',
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    expect(find.textContaining('宝宝出生'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('compact board and navigation remain usable at 320 and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 3 天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('chat-first-menu'))).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drawer-baby')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('new mother sees only saved chat-first profile facts', (
    tester,
  ) async {
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-mother')));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-12'), findsOneWidget);
    expect(find.text('30 岁'), findsOneWidget);
    expect(find.text('奶量够不够'), findsOneWidget);
    expect(find.text('今天还没有吸奶记录'), findsOneWidget);
    expect(mother.transport.getPaths, contains('/v1/records/pumping'));
    expect(find.textContaining('宝宝档案已创建'), findsNothing);
    expect(mother.transport.getPaths, contains('/v1/profile/me-experience'));
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets('secondary account and privacy pages remain reachable', (
    tester,
  ) async {
    final harness = await _Harness.create(role: 'father');
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer-devices')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('section-more-services')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账号与设置'));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/more');
    expect(find.text('账号详情'), findsOneWidget);
    expect(find.text('隐私'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('申请删除账号'), findsOneWidget);
    expect(find.text('More'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('more-account-details')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/account');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/more');

    await tester.tap(find.byKey(const ValueKey('more-privacy')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/privacy');
    expect(find.text('你的隐私'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('an unknown deep link returns to the chat-first home', (
    tester,
  ) async {
    final harness = await _Harness.create(role: 'father');
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    harness.router.go('/missing-legacy-page');
    await tester.pumpAndSettle();
    expect(find.text('页面不存在'), findsOneWidget);
    await tester.tap(find.text('返回对话'));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/');
    expect(find.text('对话界面'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets(
    'legacy lactation deep link remains usable for a partial mother',
    (tester) async {
      final harness = await _Harness.create(
        role: 'mother',
        deliveryDate: '2026-10-12',
        initialLocation: '/me/lactation',
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/me/lactation');
      expect(find.byType(LactationPage), findsOneWidget);
      expect(harness.transport.getPaths, contains('/v1/lactation/records'));

      await tester.tap(find.byTooltip('Close feeding and pumping records'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/me');
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets('privacy deep link can return to account services', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/privacy',
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/privacy');
    expect(find.text('你的隐私'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('baby deep link shows real empty state and returns to chat', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/baby',
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/baby');
    expect(harness.transport.getPaths, contains('/v1/babies'));
    expect(find.byKey(const ValueKey('chat-first-baby-page')), findsOneWidget);
    expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
    expect(find.text('Add your baby to get started'), findsNothing);
    expect(find.text('Luna'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('section-back-chat')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets(
    'the full baby management route remains reachable from a deep link',
    (tester) async {
      final harness = await _Harness.create(
        role: 'mother',
        initialLocation: '/baby/details',
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/baby/details');
      expect(
        find.byKey(const ValueKey('chat-first-baby-details-page')),
        findsOneWidget,
      );
      expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
      expect(find.text('Add your baby to get started'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('section-back-chat')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/baby');
      expect(
        find.byKey(const ValueKey('chat-first-baby-page')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets('baby knowledge asks via a draft, never an automatic run', (
    tester,
  ) async {
    Object? conversationExtra;
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/baby/details',
      agentHubBuilder: (_, _, extra) {
        conversationExtra = extra;
        return const Center(child: Text('对话界面'));
      },
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(find.text('当前账号还没有宝宝资料'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('baby-knowledge-topic-sleep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('baby-knowledge-ask')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/');
    expect(conversationExtra, {'agentPrefill': '关于宝宝安全睡眠，我想了解哪些基本注意事项？'});
    expect(harness.transport.mutationPaths, isEmpty);
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets(
    'asking the same baby knowledge question again restores its draft',
    (tester) async {
      final seenExtras = <Object?>[];
      final harness = await _Harness.create(
        role: 'father',
        initialLocation: '/baby/details',
        agentHubBuilder: (_, _, extra) {
          seenExtras.add(extra);
          return AgentHubPage(
            chatFirstExperience: true,
            initialComposerText: extra is Map
                ? extra['agentPrefill'] as String?
                : null,
            initialComposerRequestKey: extra,
          );
        },
      );
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      Future<void> ask() async {
        await tester.tap(find.byKey(const ValueKey('baby-details-knowledge')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('baby-knowledge-topic-sleep')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('baby-knowledge-ask')));
        await tester.pumpAndSettle();
      }

      await ask();
      final input = find.byKey(const ValueKey('agent-composer-input'));
      const question = '关于宝宝安全睡眠，我想了解哪些基本注意事项？';
      expect(tester.widget<TextField>(input).controller!.text, question);
      await tester.enterText(input, '');
      await tester.pump();

      harness.router.go('/baby/details');
      await tester.pumpAndSettle();
      await ask();
      expect(seenExtras.last, {'agentPrefill': question});
      expect(tester.widget<TextField>(input).controller!.text, question);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets('notification deep link returns to account services', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/notifications',
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/notifications');
    expect(
      find.byKey(const ValueKey('route-page-/notifications')),
      findsOneWidget,
    );
    expect(harness.transport.getPaths, contains('/v1/notifications'));
    await tester.tap(find.byKey(const ValueKey('notifications-back')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('resource deep link without a target can return to chat', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/media-viewer',
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/media-viewer');
    expect(find.text('No resource to view'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media-return-button')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('chat-first account deletion is explained before confirmation', (
    tester,
  ) async {
    final harness = await _Harness.create(
      role: 'father',
      initialLocation: '/more',
    );
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    final delete = find.byKey(const ValueKey('account-delete'));
    await tester.scrollUntilVisible(delete, 250);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('删除账号？'), findsOneWidget);
    expect(find.textContaining('数据删除会单独处理'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('删除账号？'), findsNothing);
    expect(harness.runtime.currentSession.isAuthenticated, isTrue);
    expect(harness.router.state.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('switching accounts gates entry and clears maternal whiteboard', (
    tester,
  ) async {
    final mother = await _Harness.create(
      role: 'mother',
      deliveryDate: '2026-10-12',
    );
    await tester.pumpWidget(mother.app);
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 3 天'), findsOneWidget);

    final nextTransport = FixtureApiJsonTransportByPath(
      const {
        chatFirstOnboardingEndpoint: {
          'status': 'required',
          'can_enter_app': false,
          'role': null,
          'profile_scope': 'none',
          'primary_infant_id': null,
        },
      },
      writeResponsesByPath: const {
        chatFirstOnboardingEndpoint: {
          'status': 'completed',
          'can_enter_app': true,
          'role': 'father',
          'profile_scope': 'chat_first',
          'primary_infant_id': null,
        },
      },
    );
    mother.runtime.replaceRuntime(
      MomCozyApiRuntime(
        jsonTransport: nextTransport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'different-father',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'other-access',
        ),
        now: () => DateTime(2026, 10, 15),
      ),
    );
    await tester.pumpAndSettle();
    expect(mother.router.state.uri.path, '/onboarding');
    expect(find.byKey(const ValueKey('role-father')), findsOneWidget);
    expect(find.textContaining('宝宝出生'), findsNothing);
    expect(nextTransport.getPaths, contains(chatFirstOnboardingEndpoint));

    await tester.tap(find.byKey(const ValueKey('role-father')));
    await tester.pumpAndSettle();
    expect(mother.router.state.uri.path, '/');
    expect(find.byKey(const ValueKey('chat-first-workspace')), findsOneWidget);
    expect(find.textContaining('宝宝出生'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    mother.dispose();
  });

  testWidgets(
    'narrow large-text home and drawer keep their actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = await _Harness.create(role: 'father');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-workspace')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('chat-first-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer-devices')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('drawer-mother')));
      await tester.pumpAndSettle();
      expect(find.textContaining('未填写妈妈资料'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );
}

class _Harness {
  _Harness(this.runtime, this.controller, this.router, this.transport);

  final MomCozyRuntimeController runtime;
  final OnboardingController controller;
  final dynamic router;
  final FixtureApiJsonTransportByPath transport;

  static Future<_Harness> create({
    required String role,
    String? deliveryDate,
    String? initialLocation,
    MomCozyAgentHubBuilder? agentHubBuilder,
    String timezone = 'Asia/Shanghai',
    DateTime Function()? now,
  }) async {
    final transport = FixtureApiJsonTransportByPath({
      chatFirstOnboardingEndpoint: {
        'status': 'completed',
        'can_enter_app': true,
        'role': role,
        'profile_scope': 'chat_first',
        'primary_infant_id': null,
      },
      '/v1/devices/pumps': const {'items': <Object>[]},
      '/v1/babies': const {'items': <Object>[]},
      '/v1/notifications': const {
        'items': <Object>[],
        'unread_count': 0,
        'next_cursor': null,
      },
      '/v1/lactation/records': const {'items': <Object>[]},
      '/v1/records/pumping': const {'items': <Object>[]},
      '/v1/profile/me': const {'preferred_name': null},
      '/v1/profile/lactation': {'actual_delivery_date': deliveryDate},
      '/v1/profile/me-experience': {
        'profile': {
          'preferred_name': null,
          'age': 30,
          'delivery_count': 2,
          'actual_delivery_date': deliveryDate,
          'gestation_weeks': 39,
          'gestation_days': 0,
          'baby_count': 1,
        },
        'concerns': const [
          {'note': '奶量够不够'},
        ],
        'order': const [],
        'records': const [],
      },
    });
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'sample-user',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
        now: now ?? () => DateTime(2026, 10, 15),
        timezoneProvider: () async => timezone,
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = createMomCozyRouter(
      initialLocation: initialLocation,
      runtimeController: runtime,
      onboardingController: controller,
      chatFirstExperience: true,
      agentHubBuilder:
          agentHubBuilder ?? (_, _, _) => const Center(child: Text('对话界面')),
    );
    return _Harness(runtime, controller, router, transport);
  }

  Widget get app =>
      MomCozyFlutterApp(router: router, runtimeController: runtime);

  void dispose() {
    router.dispose();
    controller.dispose();
    runtime.dispose();
  }
}
