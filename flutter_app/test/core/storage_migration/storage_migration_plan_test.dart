import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_plan.dart';

import '../../support/fixture_reader.dart';

void main() {
  group('Storage migration fixtures', () {
    test(
      'migrate valid core legacy state while clearing realtime device fields',
      () {
        final fixture = readFixtureMap(
          'storage_migration/p0_valid_core_state.json',
        );
        final expected = Map<String, Object?>.from(fixture['expected']! as Map);
        final plan = buildStorageMigrationPlan(fixture);

        expect(plan.scopedKeyValue, expected['scopedKeyValue']);
        expect(
          plan.chatMessages,
          Map<String, Object?>.from(expected['chatCache']! as Map)['messages'],
        );
        expect(plan.calibration, expected['calibration']);
        expect(plan.deviceRepository, expected['deviceRepository']);
        expect(plan.deleteLegacyKeys, expected['deleteLegacyKeys']);
        expect(plan.migrationVersion, expected['migrationVersion']);
      },
    );

    test('fallback safely when legacy values are malformed', () {
      final fixture = readFixtureMap(
        'storage_migration/p0_invalid_values_fallback.json',
      );
      final expected = Map<String, Object?>.from(fixture['expected']! as Map);
      final plan = buildStorageMigrationPlan(fixture);

      expect(plan.scopedKeyValue, expected['scopedKeyValue']);
      expect(plan.chatMessages, isEmpty);
      expect(plan.calibration, isNull);
      expect(plan.deviceRepository, expected['deviceRepository']);
      expect(plan.deleteLegacyKeys, expected['deleteLegacyKeys']);
      expect(plan.diagnostics, expected['diagnostics']);
      expect(plan.migrationVersion, expected['migrationVersion']);
    });
  });
}
