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

    test('convert pending route keys into one-shot queues', () {
      final fixture = readFixtureMap(
        'storage_migration/p0_one_shot_route_intents.json',
      );
      final expected = Map<String, Object?>.from(fixture['expected']! as Map);
      final plan = buildStorageMigrationPlan(fixture);

      expect(plan.routeIntentQueue, expected['routeIntentQueue']);
      expect(plan.backgroundJobQueue, expected['backgroundJobQueue']);
      expect(plan.deleteLegacyKeys, expected['deleteLegacyKeys']);
      expect(plan.migrationVersion, expected['migrationVersion']);
    });

    test('do not restore browser pump runtime without native validation', () {
      final fixture = readFixtureMap(
        'storage_migration/p0_pump_runtime_not_trusted_without_native_session.json',
      );
      final expected = Map<String, Object?>.from(fixture['expected']! as Map);
      final plan = buildStorageMigrationPlan(fixture);

      expect(plan.pumpSessionState, expected['pumpSessionState']);
      expect(plan.nativeServiceStore, expected['nativeServiceStore']);
      expect(plan.deleteLegacyKeys, expected['deleteLegacyKeys']);
      expect(plan.diagnostics, expected['diagnostics']);
      expect(plan.migrationVersion, expected['migrationVersion']);
    });

    test('migrate retained IBCLC state and dev multi-user snapshots', () {
      final fixture = readFixtureMap(
        'storage_migration/p1_preferences_ibclc_and_multi_user.json',
      );
      final expected = Map<String, Object?>.from(fixture['expected']! as Map);
      final plan = buildStorageMigrationPlan(fixture);

      expect(plan.scopedKeyValue, expected['scopedKeyValue']);
      expect(plan.localHistory, expected['localHistory']);
      expect(plan.routeIntentQueue, expected['routeIntentQueue']);
      expect(plan.deleteLegacyKeys, expected['deleteLegacyKeys']);
      expect(plan.migrationVersion, expected['migrationVersion']);
    });
  });
}
