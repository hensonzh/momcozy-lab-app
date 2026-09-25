import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/services/baby/baby_profile_codec.dart';
import 'package:momcozy_flutter_app/services/baby/baby_profiles_api_repository.dart';
import '../../support/fixture_api_transport.dart';

Map<String, Object?> fixture() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/baby_profiles.json',
        ).readAsStringSync(),
      )
      as Map,
);
Map<String, Object?> row() =>
    Map<String, Object?>.from((fixture()['items'] as List).single as Map);

void main() {
  test(
    'canonical profile uses actual date and rejects retired profile facts',
    () {
      final profile = readBabyProfile(row());
      expect(profile.birthDate, LocalDate(2026, 8, 18));
      expect(profile.version, 1);
      expect(profile.feedingMode, FeedingMode.unknown);
      expect(
        () => readBabyProfile({...row(), 'birth_weight_kg': 3.2}),
        throwsFormatException,
      );
      expect(
        () => readBabyProfile({...row(), 'sex': 'intersex'}),
        throwsFormatException,
      );
    },
  );
  test(
    'create and edit use the canonical endpoint, idempotency and current version',
    () async {
      final transport = FixtureApiJsonTransport(row());
      final repo = BabyProfilesApiRepository(transport: transport);
      await repo.save(
        const BabyProfile(id: '', name: 'Baby'),
        timezone: 'Asia/Shanghai',
        idempotencyKey: 'profile-once',
      );
      expect(transport.lastPath, '/v1/babies');
      expect(transport.lastHeaders!['Idempotency-Key'], 'profile-once');
      expect(transport.lastBody!['sex'], 'unspecified');
      final profile = readBabyProfile(row());
      await repo.save(
        profile,
        timezone: 'Asia/Shanghai',
        idempotencyKey: 'unused-for-update',
      );
      expect(transport.lastMethod, 'PUT');
      expect(transport.lastPath, '/v1/babies/${profile.id}');
      expect(transport.lastBody!['expected_version'], 1);
      expect(
        () => repo.save(
          BabyProfile(id: profile.id, name: 'Snapshot'),
          timezone: 'UTC',
          idempotencyKey: 'snapshot',
        ),
        throwsA(isA<ProductFailure>()),
      );
    },
  );
}
