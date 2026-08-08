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

  test('completes with exactly one avatar selection mode', () async {
    final transport = FixtureApiJsonTransport(const {
      'status': 'completed',
      'current_step': 'done',
      'profile_confirmed': true,
      'selected_avatar_file_id': 'output-id',
    });
    final repository = OnboardingApiRepository(
      transport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
    );

    final state = await repository.completeWithAvatar('generation-id');

    expect(transport.lastPath, '$onboardingMeEndpoint/complete');
    expect(transport.lastBody, {
      'avatar_generation_id': 'generation-id',
      'use_default_avatar': false,
    });
    expect(state.isCompleted, isTrue);
  });
}
