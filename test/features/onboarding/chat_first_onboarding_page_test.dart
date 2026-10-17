import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/chat_first_onboarding_page.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'role entry has no progress and stage starts five-step navigation',
    (tester) async {
      final harness = await _Harness.create(role: 'mother');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.text('你是宝宝的哪位家人？'), findsOneWidget);
      expect(find.text('选择你的角色，有助于我们为你量身定制产品体验。'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-back')), findsNothing);
      expect(find.byKey(const ValueKey('setup-progress')), findsNothing);
      expect(find.text('1/5'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('role-mother')));
      await tester.pumpAndSettle();
      expect(find.text('你现在处于哪个阶段？'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-back')), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-progress')), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('setup-progress')),
          matching: find.byType(Container),
        ),
        findsNWidgets(5),
      );
      await tester.tap(find.byKey(const ValueKey('setup-back')));
      await tester.pumpAndSettle();
      expect(find.text('你是宝宝的哪位家人？'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-progress')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets('role heading and choices sit above center in the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _Harness.create(role: 'mother');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('你是宝宝的哪位家人？')).dy;
    final bottom = tester
        .getBottomLeft(find.byKey(const ValueKey('role-other-family')))
        .dy;
    expect((top + bottom) / 2, inInclusiveRange(240, 360));
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('narrow large-text role and stage remain operable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = await _Harness.create(role: 'mother');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-mother')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('role-other-family')));
    expect(find.byKey(const ValueKey('role-other-family')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('role-mother')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stage-postpartum')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-continue')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('stage-postpartum')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('age-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-continue')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets('non-mother completes role selection and enters conversation', (
    tester,
  ) async {
    final harness = await _Harness.create(role: 'father');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-mother')), findsOneWidget);
    expect(find.byKey(const ValueKey('role-father')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup-continue')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('role-father')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/');
    expect(find.text('聊天首页'), findsOneWidget);
    expect(find.text('欢迎运行已准备'), findsNothing);
    expect(harness.transport.lastBody, {'role': 'father'});
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });

  testWidgets(
    'mother flow keeps five progress segments, concerns, and actual fields',
    (tester) async {
      final harness = await _Harness.create(role: 'mother');
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('role-mother')));
      await tester.pumpAndSettle();
      expect(find.text('你现在处于哪个阶段？'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('stage-unavailable-pregnant')),
      );
      await tester.pump();
      expect(find.textContaining('暂未开放'), findsOneWidget);
      expect(find.text('你现在处于哪个阶段？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stage-postpartum')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pump();
      expect(find.textContaining('请选择年龄'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('age-30')));
      await tester.tap(find.byKey(const ValueKey('delivery-count-2')));
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delivery-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('weeks-38')));
      await tester.pump();
      expect(find.byKey(const ValueKey('gestation-days')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('baby-count-2')));
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      expect(find.text('现在你最在意什么？'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('concern-crying')));
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      expect(find.text('为你推荐'), findsOneWidget);
      expect(find.text('5/5'), findsOneWidget);
      expect(find.byKey(const ValueKey('recommend-record')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setup-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('concern-crying')), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('concern-crying')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('setup-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('stage-postpartum')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stage-postpartum')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setup-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('enter-home')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/');
      expect(find.text('欢迎运行已准备'), findsNothing);
      expect(harness.transport.lastBody, containsPair('role', 'mother'));
      expect(harness.transport.lastBody, containsPair('concerns', ['crying']));
      expect(
        harness.transport.lastBody,
        containsPair('delivery_date', '2026-10-12'),
      );
      for (final key in ['display_name', 'feeding_methods', 'infants']) {
        expect(harness.transport.lastBody!.containsKey(key), isFalse);
      }
      await tester.pumpWidget(const SizedBox());
      harness.dispose();
    },
  );

  testWidgets('late concerns step remains optional before recommendations', (
    tester,
  ) async {
    final harness = await _Harness.create(role: 'mother');
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('role-mother')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stage-postpartum')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('age-30')));
    await tester.tap(find.byKey(const ValueKey('delivery-count-2')));
    await tester.tap(find.byKey(const ValueKey('setup-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delivery-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weeks-38')));
    await tester.tap(find.byKey(const ValueKey('baby-count-1')));
    await tester.tap(find.byKey(const ValueKey('setup-continue')));
    await tester.pumpAndSettle();
    expect(find.text('现在你最在意什么？'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('setup-continue')));
    await tester.pumpAndSettle();
    expect(find.text('为你推荐'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('enter-home')));
    await tester.pumpAndSettle();
    expect(harness.transport.lastBody, containsPair('concerns', <String>[]));
    expect(harness.router.state.uri.path, '/');
    await tester.pumpWidget(const SizedBox());
    harness.dispose();
  });
}

class _Harness {
  _Harness(this.runtime, this.controller, this.router, this.transport);

  final MomCozyRuntimeController runtime;
  final OnboardingController controller;
  final GoRouter router;
  final FixtureApiJsonTransportByPath transport;

  static Future<_Harness> create({required String role}) async {
    final transport = FixtureApiJsonTransportByPath(
      const {
        chatFirstOnboardingEndpoint: {
          'status': 'required',
          'can_enter_app': false,
          'role': null,
          'profile_scope': 'none',
          'primary_infant_id': null,
        },
      },
      writeResponsesByPath: {
        chatFirstOnboardingEndpoint: {
          'status': 'completed',
          'can_enter_app': true,
          'role': role,
          'profile_scope': 'chat_first',
          'primary_infant_id': null,
        },
      },
    );
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-user',
          babyId: '',
          locale: 'zh-CN',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtime,
      chatFirstMode: true,
    );
    await controller.load();
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => Scaffold(
            body: Column(
              children: [
                const Text('聊天首页'),
                if (state.extra is Map &&
                    (state.extra as Map).containsKey('agentAutoRun'))
                  const Text('欢迎运行已准备'),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => ChatFirstOnboardingPage(
            controller: controller,
            now: () => DateTime(2026, 10, 15),
            pickDate: (context, initial) async => DateTime(2026, 10, 12),
          ),
        ),
      ],
    );
    return _Harness(runtime, controller, router, transport);
  }

  Widget app() => MaterialApp.router(routerConfig: router);

  void dispose() {
    router.dispose();
    controller.dispose();
    runtime.dispose();
  }
}
