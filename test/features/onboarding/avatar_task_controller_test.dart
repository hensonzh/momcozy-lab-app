import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'global avatar task restores, reaches review, and clears after selection',
    () async {
      final responses = <String, Map<String, Object?>>{
        onboardingMeEndpoint: _generatingState,
      };
      final transport = FixtureApiJsonTransportByPath(
        responses,
        writeResponsesByPath: {
          '$onboardingMeEndpoint/complete': _completedState,
        },
      );
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'avatar-task-user',
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
        completionDisplayDuration: Duration.zero,
      );

      expect(taskController.status, AvatarTaskStatus.generating);
      expect(taskController.isVisible, isTrue);

      responses[onboardingMeEndpoint] = _reviewState;
      await taskController.refresh();

      expect(taskController.status, AvatarTaskStatus.reviewRequired);
      expect(taskController.isVisible, isTrue);

      onboardingController.selectAvatarCandidate('candidate-2');
      expect(await onboardingController.confirmAvatarSelection(), isTrue);
      expect(taskController.status, AvatarTaskStatus.completed);

      await Future<void>.delayed(Duration.zero);

      expect(taskController.status, AvatarTaskStatus.hidden);
      expect(taskController.isVisible, isFalse);

      taskController.dispose();
      onboardingController.dispose();
      runtimeController.dispose();
    },
  );

  test(
    'account switch clears the previous user avatar task immediately',
    () async {
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport(_generatingState),
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'first-avatar-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'first-access',
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
      expect(taskController.status, AvatarTaskStatus.generating);
      expect(taskController.generationId, 'generation-id');

      runtimeController.replaceRuntime(
        MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport(const {
            'status': 'required',
            'current_step': 'profile',
            'profile_confirmed': false,
          }),
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'second-avatar-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'second-access',
          ),
        ),
      );

      expect(taskController.status, AvatarTaskStatus.hidden);
      expect(taskController.generationId, isNull);

      taskController.dispose();
      onboardingController.dispose();
      runtimeController.dispose();
    },
  );
}

const _generatingState = <String, Object?>{
  'status': 'avatar_generating',
  'current_step': 'generating',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': false,
  'avatar': {
    'id': 'generation-id',
    'stage': 'postpartum',
    'status': 'generating',
    'error_code': '',
    'created_at': '2026-08-09T00:00:00Z',
    'candidates': <Object?>[],
  },
};

const _reviewState = <String, Object?>{
  'status': 'avatar_review',
  'current_step': 'review',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': false,
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
};

const _completedState = <String, Object?>{
  'status': 'completed',
  'current_step': 'done',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': true,
  'selected_avatar_file_id': 'file-2',
};
