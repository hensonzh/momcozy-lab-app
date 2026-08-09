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

  test(
    'avatar review stays gated until one of four candidates is confirmed',
    () async {
      final transport = FixtureApiJsonTransportByPath(
        const {
          '/v1/onboarding/me': {
            'status': 'avatar_review',
            'current_step': 'review',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_continue_with_default': true,
            'avatar': {
              'id': 'generation-id',
              'stage': 'postpartum',
              'status': 'succeeded',
              'error_code': '',
              'created_at': '2026-08-09T00:00:00Z',
              'candidates': [
                {'id': 'candidate-1', 'file_id': 'file-1', 'position': 1},
                {'id': 'candidate-2', 'file_id': 'file-2', 'position': 2},
                {'id': 'candidate-3', 'file_id': 'file-3', 'position': 3},
                {'id': 'candidate-4', 'file_id': 'file-4', 'position': 4},
              ],
            },
          },
        },
        writeResponsesByPath: const {
          '/v1/onboarding/me/complete': {
            'status': 'completed',
            'current_step': 'done',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'selected_avatar_file_id': 'file-2',
          },
        },
      );
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'avatar-review-user',
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

      expect(controller.requiresOnboardingFor('avatar-review-user'), isTrue);
      expect(transport.postedBodies, isEmpty);
      expect(controller.hasAvatarSelection, isFalse);

      controller.selectDefaultAvatar();
      expect(controller.defaultAvatarSelected, isTrue);
      expect(controller.selectedAvatarCandidateId, isNull);

      controller.selectAvatarCandidate('candidate-2');
      expect(controller.hasAvatarSelection, isTrue);
      expect(controller.defaultAvatarSelected, isFalse);
      expect(await controller.confirmAvatarSelection(), isTrue);
      expect(transport.lastBody, {
        'avatar_candidate_id': 'candidate-2',
        'use_default_avatar': false,
      });
      expect(controller.requiresOnboardingFor('avatar-review-user'), isFalse);

      controller.dispose();
      runtimeController.dispose();
    },
  );
}
