import 'package:momcozy_flutter_app/domain/shared/feeding_methods.dart';
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
    final repository = OnboardingApiRepository(transport: transport);
    final result = await repository.resetForRelease('1.0.0+27');
    expect(transport.lastPath, onboardingReleaseResetEndpoint);
    expect(result.status, OnboardingReleaseResetStatus.reset);
    expect(result.releaseId, '1.0.0+27');
  });

  test('required state blocks entry; confirmed profile allows entry', () {
    final required = OnboardingState.fromMap(const {
      'status': 'required',
      'profile_confirmed': false,
    });
    final confirmed = OnboardingState.fromMap(const {
      'status': 'avatar_required', // A previously deployed response.
      'profile_confirmed': true,
      'can_enter_app': false,
      'primary_infant_id': 'baby-1',
    });
    expect(required.canEnterApp, isFalse);
    expect(confirmed.canEnterApp, isTrue);
    expect(confirmed.status, OnboardingStatus.completed);
    expect(confirmed.primaryInfantId, 'baby-1');
  });

  test('feeding method selection is multi-select with exclusive unknown', () {
    expect(toggleFeedingMethod([], 'direct'), ['direct']);
    expect(toggleFeedingMethod(['direct'], 'formula'), ['direct', 'formula']);
    expect(toggleFeedingMethod(['direct', 'formula'], 'unknown'), ['unknown']);
    expect(toggleFeedingMethod(['unknown'], 'expressed'), ['expressed']);
    expect(toggleFeedingMethod(['direct'], 'direct'), ['direct']);
  });

  test('contradictory or malformed gate responses do not unlock the app', () {
    for (final response in [
      <String, Object?>{'status': 'completed', 'profile_confirmed': false},
      <String, Object?>{'status': 'required', 'profile_confirmed': 'true'},
      <String, Object?>{'status': 'unknown', 'profile_confirmed': false},
    ]) {
      expect(() => OnboardingState.fromMap(response), throwsFormatException);
    }
  });

  test(
    'rejects an overlong name or missing delivery date before transport',
    () {
      final draft = OnboardingProfileDraft(
        displayName: 'M' * 121,
        age: 32,
        deliveryCount: 1,
        gestationWeeks: 39,
        gestationDays: 0,
        feedingMethods: ['direct', 'formula'],
      );
      expect(() => draft.toMap(), throwsFormatException);
      draft.displayName = 'Mia';
      expect(() => draft.toMap(), throwsFormatException);
    },
  );

  test('first delivery cannot persist a previous cesarean history', () {
    final draft = OnboardingProfileDraft(
      displayName: 'Mia',
      age: 32,
      deliveryDate: DateTime(2026, 7, 19),
      deliveryCount: 2,
      hasCesareanHistory: true,
      deliveryType: 'cesarean',
      gestationWeeks: 39,
      gestationDays: 2,
      feedingMethods: ['direct', 'formula'],
    );
    draft.setDeliveryCount(1);
    expect(draft.hasCesareanHistory, isNull);
    expect(draft.toMap()['has_cesarean_history'], false);
    expect(draft.toMap()['delivery_type'], 'cesarean');
    expect(draft.toMap()['delivery_count'], 1);
  });

  test('prior cesarean history is independent of this delivery method', () {
    final draft = OnboardingProfileDraft(
      displayName: 'Mia',
      deliveryDate: DateTime(2026, 7, 19),
      deliveryCount: 2,
      hasCesareanHistory: false,
      deliveryType: 'cesarean',
      gestationWeeks: 39,
      gestationDays: 2,
      feedingMethods: ['direct', 'formula'],
    );
    expect(draft.toMap()['has_cesarean_history'], false);
    expect(draft.toMap()['delivery_type'], 'cesarean');
  });

  test(
    'requires gestational weeks, days and feeding mode for profile save',
    () {
      final draft = OnboardingProfileDraft(
        displayName: 'Mia',
        deliveryDate: DateTime(2026, 7, 19),
        deliveryCount: 1,
      );
      expect(() => draft.toMap(), throwsFormatException);
      draft.gestationWeeks = 39;
      draft.gestationDays = 0;
      draft.feedingMethods.addAll(['direct', 'formula']);
      expect(draft.toMap()['gestation_days'], 0);
      expect(draft.toMap()['feeding_methods'], ['direct', 'formula']);
    },
  );

  test(
    'serializes postpartum delivery and infant set on profile save',
    () async {
      final transport = FixtureApiJsonTransport(const {
        'status': 'completed',
        'profile_confirmed': true,
      });
      final repository = OnboardingApiRepository(transport: transport);
      final state = await repository.confirmProfile(
        OnboardingProfileDraft(
          displayName: 'Mia',
          age: 32,
          deliveryDate: DateTime(2026, 7, 19),
          deliveryCount: 2,
          hasCesareanHistory: true,
          deliveryType: 'cesarean',
          gestationWeeks: 39,
          gestationDays: 2,
          feedingMethods: ['direct', 'formula'],
          infantCount: 2,
          infants: [
            OnboardingInfantDraft(nickname: 'A', sex: 'female'),
            OnboardingInfantDraft(nickname: 'B'),
          ],
        ),
      );
      expect(transport.lastPath, '$onboardingMeEndpoint/profile');
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastBody, {
        'stage': 'postpartum',
        'display_name': 'Mia',
        'age': 32,
        'delivery_date': '2026-07-19',
        'client_timezone_offset_minutes':
            DateTime.now().timeZoneOffset.inMinutes,
        'delivery_count': 2,
        'has_cesarean_history': true,
        'delivery_type': 'cesarean',
        'gestation_weeks': 39,
        'gestation_days': 2,
        'feeding_methods': ['direct', 'formula'],
        'infant_count': 2,
        'infants': [
          {'nickname': 'A', 'sex': 'female'},
          {'nickname': 'B', 'sex': null},
        ],
      });
      expect(state.canEnterApp, isTrue);
    },
  );
}
