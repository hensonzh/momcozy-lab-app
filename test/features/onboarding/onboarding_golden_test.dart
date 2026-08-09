import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('new-user stage selection matches the MomCozy visual system', (
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
      matchesGoldenFile('../../goldens/onboarding/stage_selection.png'),
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
}
