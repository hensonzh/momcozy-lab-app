@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('new-user postpartum basics match the MomCozy visual system', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'required',
          'current_step': 'profile',
          'profile_confirmed': false,
        }),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'golden-new-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final router = createMomCozyRouter(
      runtimeController: runtimeController,
      onboardingController: onboardingController,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingPage),
      matchesGoldenFile('../../goldens/onboarding/postpartum_basics.png'),
    );

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('avatar generation wait makes cloud work understandable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'avatar_generating',
          'current_step': 'generating',
          'current_stage': 'postpartum',
          'profile_confirmed': true,
          'can_enter_app': true,
          'avatar_setup_completed': false,
          'can_continue_with_default': true,
          'avatar': {
            'id': 'golden-generation',
            'stage': 'postpartum',
            'status': 'generating',
            'error_code': '',
            'created_at': '2026-08-09T00:00:00Z',
            'candidates': <Object?>[],
          },
        }),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'golden-avatar-generating-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final router = createMomCozyRouter(
      initialLocation: '/onboarding',
      runtimeController: runtimeController,
      onboardingController: onboardingController,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Creating your four options'), findsOneWidget);
    await expectLater(
      find.byType(OnboardingPage),
      matchesGoldenFile('../../goldens/onboarding/avatar_generating.png'),
    );

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('ready avatar task is prominent without blocking app content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'avatar_review',
          'current_step': 'review',
          'current_stage': 'postpartum',
          'profile_confirmed': true,
          'can_enter_app': true,
          'avatar_setup_completed': false,
          'can_continue_with_default': true,
          'avatar': {
            'id': 'golden-ready-generation',
            'stage': 'postpartum',
            'status': 'succeeded',
            'error_code': '',
            'created_at': '2026-08-09T00:00:00Z',
            'candidates': [
              {
                'id': 'candidate-1',
                'file_id': '00000000-0000-4000-8000-000000000001',
                'position': 1,
              },
              {
                'id': 'candidate-2',
                'file_id': '00000000-0000-4000-8000-000000000002',
                'position': 2,
              },
              {
                'id': 'candidate-3',
                'file_id': '00000000-0000-4000-8000-000000000003',
                'position': 3,
              },
              {
                'id': 'candidate-4',
                'file_id': '00000000-0000-4000-8000-000000000004',
                'position': 4,
              },
            ],
          },
        }),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'golden-avatar-ready-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final taskController = AvatarTaskController(
      onboardingController: onboardingController,
      pollInterval: const Duration(days: 1),
    );
    final router = createMomCozyRouter(
      runtimeController: runtimeController,
      onboardingController: onboardingController,
      avatarTaskController: taskController,
      agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) =>
          const Center(child: Text('Your app stays ready to use')),
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your app stays ready to use'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-task-banner')), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('avatar-task-banner')),
      matchesGoldenFile('../../goldens/onboarding/avatar_task_ready.png'),
    );

    router.dispose();
    taskController.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });
}
