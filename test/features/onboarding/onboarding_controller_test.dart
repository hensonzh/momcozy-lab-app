import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('authenticated new user is held at the onboarding gate', () async {
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
    final controller = OnboardingController(
      runtimeController: runtimeController,
    );

    await controller.load();

    expect(controller.phase, OnboardingGatePhase.ready);
    expect(controller.isResolvedFor('new-user'), isTrue);
    expect(controller.requiresOnboardingFor('new-user'), isTrue);
    controller.dispose();
    runtimeController.dispose();
  });

  test('grandfathered or completed user passes the onboarding gate', () async {
    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'completed',
          'current_step': 'done',
          'profile_confirmed': true,
        }),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'existing-user',
          babyId: 'baby',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final controller = OnboardingController(
      runtimeController: runtimeController,
    );

    await controller.load();

    expect(controller.requiresOnboardingFor('existing-user'), isFalse);
    controller.dispose();
    runtimeController.dispose();
  });
}
