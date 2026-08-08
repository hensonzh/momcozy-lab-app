import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('authenticated new user is redirected outside the app shell', (
    tester,
  ) async {
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
          userId: 'new-user',
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

    expect(
      find.byKey(const ValueKey('onboarding-stage-fertility')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('postpartum path collects delivery and one shared infant set', (
    tester,
  ) async {
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
          userId: 'new-postpartum-user',
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
    final postpartum = find.byKey(
      const ValueKey('onboarding-stage-postpartum'),
    );
    await tester.ensureVisible(postpartum);
    await tester.tap(postpartum);
    final stageContinue = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(stageContinue);
    await tester.tap(stageContinue);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-display-name')),
      'Mia',
    );
    await tester.enterText(find.byKey(const ValueKey('onboarding-age')), '32');
    final basicsContinue = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(basicsContinue);
    await tester.tap(basicsContinue);
    await tester.pumpAndSettle();

    expect(find.text('Tell us about your delivery'), findsOneWidget);
    expect(find.text('Delivery date'), findsOneWidget);
    expect(find.text('Weeks (optional)'), findsOneWidget);
    expect(find.text('Delivery method (optional)'), findsOneWidget);
    expect(find.text('Number of babies'), findsOneWidget);
    expect(find.text('Baby 1'), findsOneWidget);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });
}
