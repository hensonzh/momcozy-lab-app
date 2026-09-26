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
      find.byKey(const ValueKey('onboarding-display-name')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('retired avatar route returns safely to the app', (tester) async {
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'completed',
          'profile_confirmed': true,
        }),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'existing-user',
          babyId: 'baby-1',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    final router = createMomCozyRouter(
      runtimeController: runtime,
      onboardingController: controller,
      initialLocation: '/avatar/create',
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtime),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
    runtime.dispose();
  });
}
