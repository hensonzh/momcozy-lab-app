import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/storage_migration/storage_migration_dry_run.dart';

import '../../support/fixture_reader.dart';

void main() {
  test(
    'dry-run report summarizes fixture migration without unhandled keys',
    () {
      final fixture = readFixtureMap(
        'storage_migration/p0_valid_core_state.json',
      );

      final report = buildStorageMigrationDryRunReport(
        fixture,
        source: 'p0_valid_core_state.json',
      );
      final json = report.toJson();
      final summary = Map<String, Object?>.from(json['summary']! as Map);

      expect(summary['scopedKeyCount'], 10);
      expect(summary['chatMessageCount'], 3);
      expect(summary['hasCalibration'], isTrue);
      expect(summary['pairedDeviceCount'], 2);
      expect(summary['unhandledLegacyKeyCount'], 0);
      expect(report.unhandledLegacyKeys, isEmpty);
    },
  );

  test('dry-run report accepts raw exported legacy buckets', () {
    final report = buildStorageMigrationDryRunReport({
      'localStorage': {
        'mai_debug_user_id': 'demo-user',
        'unknown_legacy_key': 'left-over',
      },
      'sessionStorage': {'mai_agent_conversation_id': 'session-conv'},
      'capacitorPreferences': {'mmc_schedule_reminder_on': '1'},
    });

    expect(report.plan.scopedKeyValue['runtime.userId'], 'demo-user');
    expect(
      report.plan.scopedKeyValue['notifications.scheduleReminderOn'],
      isTrue,
    );
    expect(report.unhandledLegacyKeys['localStorage'], ['unknown_legacy_key']);
  });
}
