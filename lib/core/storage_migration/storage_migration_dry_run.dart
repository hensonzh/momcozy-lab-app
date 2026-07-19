import 'storage_migration_plan.dart';

class StorageMigrationDryRunReport {
  const StorageMigrationDryRunReport({
    required this.source,
    required this.plan,
    required this.unhandledLegacyKeys,
  });

  final String source;
  final StorageMigrationPlan plan;
  final Map<String, List<String>> unhandledLegacyKeys;

  Map<String, Object?> toJson() {
    return {
      'source': source,
      'migrationVersion': plan.migrationVersion,
      'summary': {
        'scopedKeyCount': plan.scopedKeyValue.length,
        'chatMessageCount': plan.chatMessages.length,
        'hasCalibration': plan.calibration != null,
        'pairedDeviceCount': _pairedDeviceCount(plan.deviceRepository),
        'routeIntentCount': plan.routeIntentQueue.length,
        'backgroundJobCount': plan.backgroundJobQueue.length,
        'localHistorySections': plan.localHistory.keys.toList(growable: false),
        'deleteLegacyKeyCount': plan.deleteLegacyKeys.values.fold<int>(
          0,
          (count, keys) => count + keys.length,
        ),
        'diagnosticCount': plan.diagnostics.length,
        'unhandledLegacyKeyCount': unhandledLegacyKeys.values.fold<int>(
          0,
          (count, keys) => count + keys.length,
        ),
      },
      'wouldWrite': {
        'scopedKeyValue': plan.scopedKeyValue,
        'chatMessages': plan.chatMessages,
        if (plan.calibration != null) 'calibration': plan.calibration,
        'deviceRepository': plan.deviceRepository,
        if (plan.localHistory.isNotEmpty) 'localHistory': plan.localHistory,
        if (plan.routeIntentQueue.isNotEmpty)
          'routeIntentQueue': plan.routeIntentQueue,
        if (plan.backgroundJobQueue.isNotEmpty)
          'backgroundJobQueue': plan.backgroundJobQueue,
        if (plan.pumpSessionState != null)
          'pumpSessionState': plan.pumpSessionState,
        if (plan.nativeServiceStore.isNotEmpty)
          'nativeServiceStore': plan.nativeServiceStore,
      },
      'wouldDeleteLegacyKeys': plan.deleteLegacyKeys,
      'diagnostics': plan.diagnostics,
      'unhandledLegacyKeys': unhandledLegacyKeys,
    };
  }
}

StorageMigrationDryRunReport buildStorageMigrationDryRunReport(
  Map<String, Object?> input, {
  String source = 'inline',
}) {
  final fixture = normalizeStorageMigrationInput(input);
  final plan = buildStorageMigrationPlan(fixture);
  return StorageMigrationDryRunReport(
    source: source,
    plan: plan,
    unhandledLegacyKeys: findUnhandledLegacyKeys(fixture, plan),
  );
}

Map<String, Object?> normalizeStorageMigrationInput(
  Map<String, Object?> input,
) {
  if (input['legacy'] is Map) return input;
  return {'legacy': input, 'context': const <String, Object?>{}};
}

Map<String, List<String>> findUnhandledLegacyKeys(
  Map<String, Object?> fixture,
  StorageMigrationPlan plan,
) {
  final legacy = _record(fixture['legacy']) ?? const {};
  return {
    for (final bucket in _knownBuckets)
      if (_unhandledForBucket(bucket, legacy, plan).isNotEmpty)
        bucket: _unhandledForBucket(bucket, legacy, plan),
  };
}

int _pairedDeviceCount(Map<String, Object?> deviceRepository) {
  return deviceRepository.values.whereType<Map>().length;
}

List<String> _unhandledForBucket(
  String bucket,
  Map<String, Object?> legacy,
  StorageMigrationPlan plan,
) {
  final values = _record(legacy[bucket]) ?? const {};
  final handled = _handledKeys[bucket] ?? const <String>{};
  final deleted = plan.deleteLegacyKeys[bucket]?.toSet() ?? const <String>{};
  return values.keys
      .where(
        (key) =>
            !handled.contains(key) &&
            !_isHandledDynamicKey(bucket, key) &&
            !deleted.contains(key),
      )
      .toList(growable: false)
    ..sort();
}

bool _isHandledDynamicKey(String bucket, String key) {
  return bucket == 'localStorage' && key.startsWith('mai_debug_user_data:');
}

Map<String, Object?>? _record(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
}

const _knownBuckets = [
  'localStorage',
  'sessionStorage',
  'capacitorPreferences',
  'androidSharedPreferences',
];

const _handledKeys = <String, Set<String>>{
  'localStorage': {
    'mai_debug_user_id',
    'mai_debug_user_stage',
    'mai_debug_user_ids',
    'mai_anonymous_user_id',
    'mai_agent_hub_chat_messages_v1',
    'mai_agent_conversation_id',
    'momcozy_conversation_id',
    'calibration',
    'calibration_prompt_disabled',
    'calibration_decline_count',
    'device_store',
    'momcozy_status_care_stage',
    'volume-unit',
    'momcozy_user_id',
    'momcozy_ibclc_consult_completed',
    'momcozy_ibclc_consult_completions',
    'momcozy_ibclc_return_to',
    'momcozy_ibclc_return_viewport',
    'calibrationHubNotice',
    'mmc_birth_journey_plan_nav_pending',
    'mmc_birth_journey_plan_card_pending',
    'mmc_milk_plan_nav_pending',
    'mmc_milk_plan_schedule_pending',
    'mmc_pregnancy_diary_nav_pending',
    'mmc_pregnancy_diary_card_pending',
    'mmc_pregnancy_diary_card_label',
    'mmc_milk_analysis_reminder_followup_pending',
    'pump_session_state',
  },
  'sessionStorage': {
    'mai_agent_conversation_id',
    'pump_session_state',
    'pump_session_letdown_counts',
    'pump_session_process_all',
    'pump_completion_notified',
    'mmc_native_summary_body',
    'mmc_status_growth_highlight_pending',
    'mmc_pump_auto_end_off_pump_pending',
  },
  'capacitorPreferences': {
    'mmc_background_notify_onboarding_done',
    'mmc_schedule_reminder_on',
  },
  'androidSharedPreferences': {'PumpAgentNativeStore'},
};
