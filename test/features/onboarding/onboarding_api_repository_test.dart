import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('requests an idempotent cloud reset for the current release', () async {
    final transport = FixtureApiJsonTransport(const {
      'status': 'reset',
      'release_id': '1.0.0+27',
      'deleted_file_count': 3,
      'object_cleanup_queued': true,
    });
    final repository = OnboardingApiRepository(
      transport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );

    final result = await repository.resetForRelease('1.0.0+27');

    expect(transport.lastPath, onboardingReleaseResetEndpoint);
    expect(transport.lastBody, {'release_id': '1.0.0+27'});
    expect(result.status, OnboardingReleaseResetStatus.reset);
    expect(result.deletedFileCount, 3);
    expect(result.objectCleanupQueued, isTrue);
  });

  test('maps required onboarding state', () async {
    final repository = OnboardingApiRepository(
      transport: FixtureApiJsonTransport(const {
        'status': 'required',
        'current_step': 'profile',
        'profile_confirmed': false,
      }),
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );

    final state = await repository.fetchState();

    expect(state.status, OnboardingStatus.required);
    expect(state.profileConfirmed, isFalse);
    expect(state.canEnterApp, isFalse);
    expect(state.avatarSetupCompleted, isFalse);
  });

  test('preserves the avatar worker phase for truthful progress UI', () {
    for (final (raw, expected) in const [
      ('queued', OnboardingAvatarGenerationPhase.queued),
      ('generating', OnboardingAvatarGenerationPhase.generating),
    ]) {
      final state = OnboardingState.fromMap({
        'status': 'avatar_generating',
        'current_step': 'generating',
        'current_stage': 'postpartum',
        'profile_confirmed': true,
        'can_enter_app': true,
        'avatar_setup_completed': false,
        'avatar': {
          'id': 'generation-$raw',
          'stage': 'postpartum',
          'status': raw,
          'error_code': '',
          'created_at': '2026-08-09T00:00:00Z',
          'candidates': <Object?>[],
        },
      });

      expect(state.status, OnboardingStatus.avatarGenerating);
      expect(state.avatar?.phase, expected);
      expect(state.canEnterApp, isTrue);
      expect(state.avatarSetupCompleted, isFalse);
    }
  });

  test('serializes one shared postpartum delivery and infant set', () async {
    final transport = FixtureApiJsonTransport(const {
      'status': 'avatar_required',
      'current_step': 'avatar',
      'current_stage': 'postpartum',
      'profile_confirmed': true,
    });
    final repository = OnboardingApiRepository(
      transport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );
    final draft = OnboardingProfileDraft(
      stage: OnboardingCareStage.postpartum,
      displayName: 'Mia',
      age: 32,
      deliveryDate: DateTime(2026, 7, 19),
      gestationalWeeks: 39,
      gestationalDays: 2,
      deliveryType: 'cesarean',
      infantCount: 2,
      infants: [
        OnboardingInfantDraft(nickname: 'A', sex: 'female'),
        OnboardingInfantDraft(nickname: 'B'),
      ],
    );

    final state = await repository.confirmProfile(draft);

    expect(transport.lastPath, '$onboardingMeEndpoint/profile');
    expect(transport.lastMethod, 'PUT');
    expect(transport.lastBody, {
      'stage': 'postpartum',
      'display_name': 'Mia',
      'age': 32,
      'delivery_date': '2026-07-19',
      'delivery_gestational_age': {'weeks': 39, 'days': 2},
      'delivery_type': 'cesarean',
      'infant_count': 2,
      'infants': [
        {'nickname': 'A', 'sex': 'female'},
        {'nickname': 'B', 'sex': null},
      ],
    });
    expect(state.status, OnboardingStatus.avatarRequired);
  });

  test('serializes the current pregnancy week instead of a due date', () async {
    final transport = FixtureApiJsonTransport(const {
      'status': 'avatar_required',
      'current_step': 'avatar',
      'current_stage': 'pregnancy',
      'profile_confirmed': true,
    });
    final repository = OnboardingApiRepository(
      transport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );
    final draft = OnboardingProfileDraft(
      stage: OnboardingCareStage.pregnancy,
      displayName: 'Mia',
      age: 32,
      currentGestationalWeek: 24,
      expectedInfantCount: 2,
    );

    await repository.confirmProfile(draft);

    expect(transport.lastBody, {
      'stage': 'pregnancy',
      'display_name': 'Mia',
      'age': 32,
      'current_gestational_week': 24,
      'expected_infant_count': 2,
    });
    expect(transport.lastBody, isNot(contains('expected_due_date')));
  });

  test('uploads portrait to dedicated endpoint before generation', () async {
    final multipart = FixtureApiMultipartTransport(const {
      'id': 'portrait-file-id',
    });
    final repository = OnboardingApiRepository(
      transport: FixtureApiJsonTransport(const {}),
      multipartTransport: multipart,
    );

    final id = await repository.uploadPortrait(
      OnboardingPortrait(
        bytes: Uint8List.fromList([1, 2, 3]),
        name: 'me.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    expect(id, 'portrait-file-id');
    expect(multipart.lastPath, '$onboardingMeEndpoint/portrait');
    expect(multipart.lastFile?.mimeType, 'image/jpeg');
    expect(multipart.lastFile?.sizeBytes, 3);
  });

  test(
    'maps four avatar candidates and completes with one candidate',
    () async {
      final transport = FixtureApiJsonTransport(const {
        'status': 'completed',
        'current_step': 'done',
        'profile_confirmed': true,
        'can_enter_app': true,
        'avatar_setup_completed': true,
        'selected_avatar_file_id': 'output-id',
        'avatar': {
          'id': 'generation-id',
          'status': 'succeeded',
          'stage': 'postpartum',
          'error_code': '',
          'created_at': '2026-08-09T00:00:00Z',
          'candidates': [
            {'id': 'candidate-1', 'file_id': 'file-1', 'position': 1},
            {'id': 'candidate-2', 'file_id': 'file-2', 'position': 2},
            {'id': 'candidate-3', 'file_id': 'file-3', 'position': 3},
            {'id': 'candidate-4', 'file_id': 'file-4', 'position': 4},
          ],
        },
      });
      final repository = OnboardingApiRepository(
        transport: transport,
        multipartTransport: FixtureApiMultipartTransport(const {}),
      );

      final state = await repository.completeWithAvatar('candidate-2');

      expect(transport.lastPath, '$onboardingMeEndpoint/complete');
      expect(transport.lastBody, {
        'avatar_candidate_id': 'candidate-2',
        'use_default_avatar': false,
      });
      expect(state.isCompleted, isTrue);
      expect(state.avatar?.candidates, hasLength(4));
      expect(state.avatar?.candidates[1].fileId, 'file-2');
    },
  );

  test('completes with the explicit MomCozy default selection', () async {
    final transport = FixtureApiJsonTransport(const {
      'status': 'completed',
      'current_step': 'done',
      'profile_confirmed': true,
      'can_enter_app': true,
      'avatar_setup_completed': true,
    });
    final repository = OnboardingApiRepository(
      transport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );

    await repository.completeWithDefault();

    expect(transport.lastBody, {
      'avatar_candidate_id': null,
      'use_default_avatar': true,
    });
  });
}
