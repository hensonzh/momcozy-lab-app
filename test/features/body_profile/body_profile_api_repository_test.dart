import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/body_profile/data/body_profile_api_repository.dart';
import 'package:momcozy_flutter_app/features/body_profile/domain/body_profile.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('maps and saves only confirmed body profile values', () async {
    final transport = FixtureApiJsonTransport({
      'owner_user_id': 'user-001',
      'urine_leakage': 'sometimes',
      'lower_abdominal_pain': 'rare',
      'pelvic_floor_strength': 3,
      'diastasis_severity': 'mild',
      'daily_impact_description': 'Occasional tightness.',
      'pain_areas': [
        {
          'id': 'pain-001',
          'zone': 'lower_abdomen',
          'intensity': 4,
          'sensation': 'aching',
          'pattern': '',
        },
      ],
      'has_confirmed_data': true,
      'recovery_score': null,
      'updated_at': '2026-08-08T08:00:00Z',
    });
    final repository = BodyProfileApiRepository(transport: transport);

    final profile = await repository.fetchProfile();

    expect(transport.lastPath, bodyProfileMeEndpoint);
    expect(profile.urineLeakage, RecoveryFrequency.sometimes);
    expect(profile.pelvicFloorStrength, 3);
    expect(profile.painAreas.single.zone, PainZone.lowerAbdomen);
    expect(profile.recoveryScore, isNull);

    await repository.saveProfile(profile);

    expect(transport.lastMethod, 'PUT');
    expect(transport.lastPath, bodyProfileMeEndpoint);
    expect(transport.lastBody, {
      'urine_leakage': 'sometimes',
      'lower_abdominal_pain': 'rare',
      'pelvic_floor_strength': 3,
      'diastasis_severity': 'mild',
      'daily_impact_description': 'Occasional tightness.',
      'pain_areas': [
        {
          'zone': 'lower_abdomen',
          'intensity': 4,
          'sensation': 'aching',
          'pattern': '',
        },
      ],
    });
  });
}
