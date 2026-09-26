import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'new user is gated until profile is saved; infant selection follows',
    () async {
      final transport = FixtureApiJsonTransportByPath(
        const {
          '/v1/onboarding/me': {
            'status': 'required',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: const {
          '/v1/onboarding/me/profile': {
            'status': 'avatar_required',
            'profile_confirmed': true,
            'can_enter_app': false,
            'primary_infant_id': 'baby-1',
          },
        },
      );
      final runtime = _runtime(transport);
      final selected = <String>[];
      final controller = OnboardingController(
        runtimeController: runtime,
        onPrimaryInfantSelected: (id) async => selected.add(id),
      );
      await controller.load();
      expect(controller.requiresOnboardingFor('new-user'), isTrue);
      expect(await controller.confirmProfile(_draft()), isTrue);
      expect(controller.requiresOnboardingFor('new-user'), isFalse);
      expect(selected, ['baby-1']);
      expect(transport.mutationPaths, ['/v1/onboarding/me/profile']);
      controller.dispose();
      runtime.dispose();
    },
  );

  test('rejected save retains required state and draft for retry', () async {
    final transport = FixtureApiJsonTransportByPath(
      const {
        '/v1/onboarding/me': {'status': 'required', 'profile_confirmed': false},
      },
      writeResponsesByPath: const {
        '/v1/onboarding/me/profile': {
          'status': 'required',
          'profile_confirmed': false,
        },
      },
    );
    final runtime = _runtime(transport);
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    expect(await controller.confirmProfile(_draft()), isFalse);
    expect(controller.requiresOnboardingFor('new-user'), isTrue);
    expect(controller.errorMessage, isNotEmpty);
    controller.dispose();
    runtime.dispose();
  });

  test('already-confirmed profile passes the onboarding gate', () async {
    final transport = FixtureApiJsonTransportByPath(const {
      '/v1/onboarding/me': {
        'status': 'avatar_generating',
        'profile_confirmed': true,
        'can_enter_app': false,
      },
    });
    final runtime = _runtime(transport);
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    expect(controller.state?.status, OnboardingStatus.completed);
    expect(controller.requiresOnboardingFor('new-user'), isFalse);
    controller.dispose();
    runtime.dispose();
  });
}

OnboardingProfileDraft _draft() => OnboardingProfileDraft(
  displayName: 'Mia',
  age: 32,
  deliveryDate: DateTime(2026, 9, 20),
  deliveryCount: 1,
);

MomCozyRuntimeController _runtime(FixtureApiJsonTransportByPath transport) =>
    MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
