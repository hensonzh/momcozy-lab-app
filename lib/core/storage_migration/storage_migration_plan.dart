import 'dart:convert';

class StorageMigrationPlan {
  StorageMigrationPlan({
    required this.scopedKeyValue,
    required this.chatMessages,
    required this.calibration,
    required this.deviceRepository,
    required this.localHistory,
    required this.routeIntentQueue,
    required this.backgroundJobQueue,
    required this.pumpSessionState,
    required this.nativeServiceStore,
    required this.deleteLegacyKeys,
    required this.diagnostics,
    required this.migrationVersion,
  });

  final Map<String, Object?> scopedKeyValue;
  final List<Map<String, Object?>> chatMessages;
  final Map<String, Object?>? calibration;
  final Map<String, Object?> deviceRepository;
  final Map<String, Object?> localHistory;
  final List<Map<String, Object?>> routeIntentQueue;
  final List<Map<String, Object?>> backgroundJobQueue;
  final Map<String, Object?>? pumpSessionState;
  final Map<String, Object?> nativeServiceStore;
  final Map<String, List<String>> deleteLegacyKeys;
  final List<Map<String, Object?>> diagnostics;
  final int migrationVersion;
}

StorageMigrationPlan buildStorageMigrationPlan(Map<String, Object?> fixture) {
  final legacy = _record(fixture['legacy']) ?? const {};
  final local = _stringMap(_record(legacy['localStorage']));
  final session = _stringMap(_record(legacy['sessionStorage']));
  final capacitor = _stringMap(_record(legacy['capacitorPreferences']));
  final android = _stringMap(_record(legacy['androidSharedPreferences']));
  final context = _record(fixture['context']) ?? const {};
  final diagnostics = <Map<String, Object?>>[];
  final deleteLegacyKeys = <String, List<String>>{};
  final routeIntentQueue = <Map<String, Object?>>[];
  final backgroundJobQueue = <Map<String, Object?>>[];
  final localHistory = <String, Object?>{};
  final nativeServiceStore = <String, Object?>{};

  final userId = _trimmed(local['mai_debug_user_id']);
  final resolvedUserId =
      userId ??
      _trimmed(_string(context['envDefaultUserId'])) ??
      _trimmed(_string(context['activeUserId'])) ??
      'anonymous';
  if (userId == null && local.containsKey('mai_debug_user_id')) {
    diagnostics.add(_diagnostic('invalid_runtime_user_id', 'info'));
  }

  final storedStage = _trimmed(local['mai_debug_user_stage']);
  final resolvedStage = _validRuntimeMomStage(storedStage)
      ? storedStage!
      : (_validRuntimeMomStage(_string(context['envDefaultMomStage']))
            ? _string(context['envDefaultMomStage'])!
            : 'postpartum');
  if (storedStage != null && !_validRuntimeMomStage(storedStage)) {
    diagnostics.add(_diagnostic('invalid_runtime_stage', 'info'));
  }

  final localConversation = _trimmed(local['mai_agent_conversation_id']);
  final sessionConversation = _trimmed(session['mai_agent_conversation_id']);
  final conversationId = localConversation ?? sessionConversation;
  if (sessionConversation != null) {
    deleteLegacyKeys['sessionStorage'] = ['mai_agent_conversation_id'];
  }

  final scoped = <String, Object?>{
    'runtime.userId': resolvedUserId,
    'runtime.momStage': resolvedStage,
    'preferences.volumeUnit': _validVolumeUnit(local['volume-unit'])
        ? local['volume-unit']!
        : 'mL',
  };
  if (local.containsKey('calibration_prompt_disabled')) {
    scoped['calibration.promptDisabled'] =
        local['calibration_prompt_disabled'] == 'true';
  }
  if (local.containsKey('calibration_decline_count')) {
    scoped['calibration.declineCount'] = _safeInt(
      local['calibration_decline_count'],
    );
  }
  if (capacitor.containsKey('mmc_background_notify_onboarding_done')) {
    scoped['notifications.backgroundNotifyOnboardingDone'] =
        capacitor['mmc_background_notify_onboarding_done'] == '1';
  }
  if (capacitor.containsKey('mmc_schedule_reminder_on')) {
    scoped['notifications.scheduleReminderOn'] =
        capacitor['mmc_schedule_reminder_on'] == '1';
  }
  final anonymousUserId = _trimmed(local['mai_anonymous_user_id']);
  if (anonymousUserId != null) {
    scoped['runtime.anonymousUserId'] = anonymousUserId;
  }
  if (conversationId != null) {
    scoped['agent.conversationId'] = conversationId;
  }
  final threadId = _trimmed(local['momcozy_conversation_id']);
  if (threadId != null) {
    scoped['agent.threadId'] = threadId;
  }

  if (local.containsKey('momcozy_status_care_stage')) {
    final careStage = _trimmed(local['momcozy_status_care_stage']);
    scoped['status.careStage'] = _validStatusCareStage(careStage)
        ? careStage
        : 'postpartum';
  }

  _readIbclcState(
    local: local,
    context: context,
    scoped: scoped,
    localHistory: localHistory,
    routeIntentQueue: routeIntentQueue,
    deleteLegacyKeys: deleteLegacyKeys,
  );

  _readDevUserSnapshots(
    local: local,
    context: context,
    localHistory: localHistory,
  );

  final chatMessages = _readChatMessages(
    local['mai_agent_hub_chat_messages_v1'],
  );
  if (local.containsKey('mai_agent_hub_chat_messages_v1') &&
      chatMessages == null) {
    diagnostics.add(_diagnostic('invalid_chat_cache_shape', 'info'));
  }

  final calibration = _readCalibration(local['calibration']);
  if (local.containsKey('calibration') && calibration == null) {
    diagnostics.add(_diagnostic('invalid_calibration_payload', 'warn'));
    deleteLegacyKeys
        .putIfAbsent('localStorage', () => <String>[])
        .add('calibration');
  }

  final devices = _readDeviceRepository(local['device_store']);
  if (local.containsKey('device_store') && devices == null) {
    diagnostics.add(_diagnostic('invalid_device_store_json', 'warn'));
  }

  if (local.containsKey('volume-unit') &&
      !_validVolumeUnit(local['volume-unit'])) {
    diagnostics.add(_diagnostic('invalid_volume_unit', 'info'));
  }

  _readOneShotRouteIntents(
    local: local,
    session: session,
    context: context,
    routeIntentQueue: routeIntentQueue,
    backgroundJobQueue: backgroundJobQueue,
    deleteLegacyKeys: deleteLegacyKeys,
  );

  final pumpSessionState = _readPumpRuntimeState(
    local: local,
    session: session,
    android: android,
    context: context,
    nativeServiceStore: nativeServiceStore,
    deleteLegacyKeys: deleteLegacyKeys,
    diagnostics: diagnostics,
  );

  return StorageMigrationPlan(
    scopedKeyValue: scoped,
    chatMessages: chatMessages ?? const [],
    calibration: calibration,
    deviceRepository: devices ?? const {'L': null, 'R': null},
    localHistory: localHistory,
    routeIntentQueue: routeIntentQueue,
    backgroundJobQueue: backgroundJobQueue,
    pumpSessionState: pumpSessionState,
    nativeServiceStore: nativeServiceStore,
    deleteLegacyKeys: deleteLegacyKeys,
    diagnostics: diagnostics,
    migrationVersion: 1,
  );
}

List<Map<String, Object?>>? _readChatMessages(String? raw) {
  final decoded = _decode(raw);
  if (decoded is! List) return null;

  return decoded
      .whereType<Map>()
      .take(50)
      .map((item) {
        final record = Map<String, Object?>.from(item);
        return {
          'id': record['id'],
          'role': record['role'],
          'content': record['content'],
          'timestamp': record['timestamp'],
        };
      })
      .toList(growable: false);
}

Map<String, Object?>? _readCalibration(String? raw) {
  final decoded = _record(_decode(raw));
  if (decoded == null) return null;

  final left = _calibrationSide(_record(decoded['L']));
  final right = _calibrationSide(_record(decoded['R']));
  final maxSafe = decoded['maxSafe'];
  if (left == null || right == null || maxSafe is! int) return null;

  return {
    'L': left,
    'R': right,
    'maxSafe': maxSafe,
    'source': 'legacy-localStorage',
  };
}

Map<String, Object?>? _calibrationSide(Map<String, Object?>? side) {
  if (side == null) return null;
  final stim = side['stimCozy'];
  final deep = side['deepCozy'];
  if (stim is! int || deep is! int) return null;
  if (!_validGear(stim) || !_validGear(deep)) return null;
  return {'stimCozy': stim, 'deepCozy': deep};
}

Map<String, Object?>? _readDeviceRepository(String? raw) {
  final decoded = _record(_decode(raw));
  if (decoded == null) return null;

  return {
    'L': _deviceSide(_record(decoded['L'])),
    'R': _deviceSide(_record(decoded['R'])),
  };
}

Map<String, Object?>? _deviceSide(Map<String, Object?>? side) {
  if (side == null) return null;
  final deviceId = _trimmed(_string(side['deviceId']));
  if (deviceId == null) return null;

  return {
    'deviceId': deviceId,
    'deviceName': _string(side['deviceName']),
    'paired': true,
    'connected': false,
    'battery': side['battery'] is int ? side['battery'] : null,
    'flangeSize': side['flangeSize'] is int ? side['flangeSize'] : null,
    'sealSize': _string(side['sealSize']),
    'model': _string(side['model']),
    'firmware': _string(side['firmware']),
    'serialNumber': _string(side['serialNumber']),
    'pumpWorkState': 0,
    'pumpScene': 0,
    'realtimeFieldsCleared': true,
  };
}

void _readOneShotRouteIntents({
  required Map<String, String> local,
  required Map<String, String> session,
  required Map<String, Object?> context,
  required List<Map<String, Object?>> routeIntentQueue,
  required List<Map<String, Object?>> backgroundJobQueue,
  required Map<String, List<String>> deleteLegacyKeys,
}) {
  if (local.containsKey('calibrationHubNotice')) {
    final notice = _trimmed(local['calibrationHubNotice']);
    if (notice != null) {
      routeIntentQueue.add({
        'type': 'calibrationHubNotice',
        'payload': {'notice': notice},
        'consume': 'once',
      });
    }
    _markDelete(deleteLegacyKeys, 'localStorage', 'calibrationHubNotice');
  }

  _readPlanNavigationIntent(
    raw: local['mmc_birth_journey_plan_nav_pending'],
    deleteKey: 'mmc_birth_journey_plan_nav_pending',
    defaultTarget: 'status',
    routeIntentQueue: routeIntentQueue,
    deleteLegacyKeys: deleteLegacyKeys,
  );
  if (local.containsKey('mmc_birth_journey_plan_card_pending')) {
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_birth_journey_plan_card_pending',
    );
  }

  _readPlanNavigationIntent(
    raw: local['mmc_milk_plan_nav_pending'],
    deleteKey: 'mmc_milk_plan_nav_pending',
    defaultTarget: 'schedule',
    routeIntentQueue: routeIntentQueue,
    deleteLegacyKeys: deleteLegacyKeys,
  );
  if (local.containsKey('mmc_milk_plan_schedule_pending')) {
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_milk_plan_schedule_pending',
    );
  }

  if (local.containsKey('mmc_pregnancy_diary_nav_pending')) {
    routeIntentQueue.add({
      'type': 'pregnancyDiaryNavigation',
      'target': 'status',
      'consume': 'once',
    });
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_pregnancy_diary_nav_pending',
    );
  }
  if (local.containsKey('mmc_pregnancy_diary_card_pending')) {
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_pregnancy_diary_card_pending',
    );
  }
  if (local.containsKey('mmc_pregnancy_diary_card_label')) {
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_pregnancy_diary_card_label',
    );
  }

  final nativeSummary = _trimmed(session['mmc_native_summary_body']);
  if (nativeSummary != null) {
    routeIntentQueue.add({
      'type': 'nativeSummary',
      'target': 'agentHub',
      'payload': {'body': nativeSummary},
      'consume': 'once',
    });
    _markDelete(deleteLegacyKeys, 'sessionStorage', 'mmc_native_summary_body');
  }

  if (session['mmc_status_growth_highlight_pending'] == '1') {
    routeIntentQueue.add({
      'type': 'growthHighlight',
      'target': 'status',
      'consume': 'once',
    });
    _markDelete(
      deleteLegacyKeys,
      'sessionStorage',
      'mmc_status_growth_highlight_pending',
    );
  }

  if (session['mmc_pump_auto_end_off_pump_pending'] == '1') {
    routeIntentQueue.add({
      'type': 'pumpAutoEndOffPump',
      'target': 'agentHub',
      'consume': 'once',
    });
    _markDelete(
      deleteLegacyKeys,
      'sessionStorage',
      'mmc_pump_auto_end_off_pump_pending',
    );
  }

  final followup = _record(
    _decode(local['mmc_milk_analysis_reminder_followup_pending']),
  );
  if (followup != null) {
    final now = _int(context['now']) ?? DateTime.now().millisecondsSinceEpoch;
    final createdAt = _int(followup['createdAt']) ?? 0;
    final attempts = _int(followup['attempts']) ?? 0;
    const ttlMs = 30 * 60 * 1000;
    if (createdAt > 0 && now - createdAt <= ttlMs && attempts < 3) {
      backgroundJobQueue.add({
        'type': 'milkAnalysisReminderFollowup',
        'taskId': _string(followup['taskId']) ?? '',
        'chatMessageId': _string(followup['chatMessageId']) ?? '',
        'message': _string(followup['message']) ?? '',
        'status': _string(followup['status']) ?? 'pending',
        'attempts': attempts,
        'ttlMs': ttlMs,
      });
    }
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'mmc_milk_analysis_reminder_followup_pending',
    );
  }
}

void _readPlanNavigationIntent({
  required String? raw,
  required String deleteKey,
  required String defaultTarget,
  required List<Map<String, Object?>> routeIntentQueue,
  required Map<String, List<String>> deleteLegacyKeys,
}) {
  final decoded = _record(_decode(raw));
  if (decoded == null) return;

  final payload = <String, Object?>{
    'kind': _string(decoded['kind']) ?? '',
    'reason': _string(decoded['reason']) ?? '',
    'label': _string(decoded['label']) ?? '',
  };
  final planId = decoded['planId'];
  if (planId is int) payload['planId'] = planId;

  routeIntentQueue.add({
    'type': 'planNavigation',
    'target': _string(decoded['target']) ?? defaultTarget,
    'payload': payload,
    'consume': 'once',
  });
  _markDelete(deleteLegacyKeys, 'localStorage', deleteKey);
}

Map<String, Object?>? _readPumpRuntimeState({
  required Map<String, String> local,
  required Map<String, String> session,
  required Map<String, String> android,
  required Map<String, Object?> context,
  required Map<String, Object?> nativeServiceStore,
  required Map<String, List<String>> deleteLegacyKeys,
  required List<Map<String, Object?>> diagnostics,
}) {
  final hasLegacyPumpState =
      local.containsKey('pump_session_state') ||
      session.containsKey('pump_session_state');
  if (!hasLegacyPumpState) return null;

  final nativeActive = context['nativeActivePumpSession'];
  if (nativeActive == null) {
    if (android.containsKey('PumpAgentNativeStore')) {
      nativeServiceStore['PumpAgentNativeStore'] = {
        'preserveForNativeCleanup': true,
        'exposeToFlutterAsActiveSession': false,
      };
    }
    if (local.containsKey('pump_session_state')) {
      _markDelete(deleteLegacyKeys, 'localStorage', 'pump_session_state');
    }
    for (final key in [
      'pump_session_state',
      'pump_session_letdown_counts',
      'pump_session_process_all',
      'pump_completion_notified',
    ]) {
      if (session.containsKey(key)) {
        _markDelete(deleteLegacyKeys, 'sessionStorage', key);
      }
    }
    diagnostics.add(
      _diagnostic(
        'ignored_legacy_pump_runtime_without_native_active_session',
        'info',
      ),
    );
    return {
      'state': 'idle',
      'restoredFromLegacyBrowserStorage': false,
      'requiresNativeValidation': true,
    };
  }

  return {
    'state': 'requires_native_restore',
    'restoredFromLegacyBrowserStorage': false,
    'requiresNativeValidation': true,
  };
}

void _readIbclcState({
  required Map<String, String> local,
  required Map<String, Object?> context,
  required Map<String, Object?> scoped,
  required Map<String, Object?> localHistory,
  required List<Map<String, Object?>> routeIntentQueue,
  required Map<String, List<String>> deleteLegacyKeys,
}) {
  final retained = context['ibclcFeatureRetained'] == true;
  if (retained) {
    final clientUserId = _trimmed(local['momcozy_user_id']);
    if (clientUserId != null) scoped['ibclc.clientUserId'] = clientUserId;

    final completed = _record(
      _decode(local['momcozy_ibclc_consult_completed']),
    );
    if (completed?['completed'] == true) {
      scoped['ibclc.consultCompleted'] = true;
    }

    final completions = _decode(local['momcozy_ibclc_consult_completions']);
    if (completions is List) {
      localHistory['ibclc.consultCompletions'] = completions
          .whereType<Map>()
          .map((item) {
            final record = Map<String, Object?>.from(item);
            return {
              'completed': record['completed'] == true,
              'completedAt': _string(record['completedAt']) ?? '',
            };
          })
          .toList(growable: false);
    }
  }

  final returnTo = _trimmed(local['momcozy_ibclc_return_to']);
  final viewport = _record(_decode(local['momcozy_ibclc_return_viewport']));
  if (returnTo != null) {
    routeIntentQueue.add({
      'type': 'ibclcReturn',
      'target': returnTo,
      'payload': {'scrollY': _int(viewport?['scrollY']) ?? 0},
      'consume': 'once',
    });
    _markDelete(deleteLegacyKeys, 'localStorage', 'momcozy_ibclc_return_to');
  }
  if (local.containsKey('momcozy_ibclc_return_viewport')) {
    _markDelete(
      deleteLegacyKeys,
      'localStorage',
      'momcozy_ibclc_return_viewport',
    );
  }
}

void _readDevUserSnapshots({
  required Map<String, String> local,
  required Map<String, Object?> context,
  required Map<String, Object?> localHistory,
}) {
  if (context['internalDevBuild'] != true) return;
  final activeUserId = _trimmed(_string(context['activeUserId']));
  final ids = _decode(local['mai_debug_user_ids']);
  if (ids is! List) return;

  final snapshots = <Map<String, Object?>>[];
  for (final id in ids.whereType<String>()) {
    final userId = _trimmed(id);
    if (userId == null || userId == activeUserId) continue;
    final snapshot = _record(_decode(local['mai_debug_user_data:$userId']));
    if (snapshot == null) continue;
    final values = _record(snapshot['values']) ?? const {};
    final migrated = <String>[];
    if (_trimmed(_string(values['mai_agent_conversation_id'])) != null) {
      migrated.add('agent.conversationId');
    }
    if (_trimmed(_string(values['momcozy_conversation_id'])) != null) {
      migrated.add('agent.threadId');
    }
    if (_hasMigratableSnapshotCalibration(_string(values['calibration']))) {
      migrated.add('calibration');
    }
    snapshots.add({
      'userId': userId,
      'momStage': _string(snapshot['momStage']) ?? 'postpartum',
      'valuesMigrated': migrated,
    });
  }
  if (snapshots.isNotEmpty) {
    localHistory['dev.userSnapshots'] = snapshots;
  }
}

bool _hasMigratableSnapshotCalibration(String? raw) {
  final decoded = _record(_decode(raw));
  if (decoded == null) return false;
  return _calibrationSide(_record(decoded['L'])) != null &&
      _calibrationSide(_record(decoded['R'])) != null;
}

Object? _decode(String? raw) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

Map<String, Object?>? _record(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
}

Map<String, String> _stringMap(Map<String, Object?>? map) {
  if (map == null) return const {};
  return {
    for (final entry in map.entries)
      if (entry.value case final String value) entry.key: value,
  };
}

Map<String, Object?> _diagnostic(String code, String severity) {
  return {'code': code, 'severity': severity};
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int _safeInt(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed < 0 ? 0 : parsed;
}

bool _validGear(int value) => value >= 1 && value <= 15;

bool _validRuntimeMomStage(String? value) =>
    value == 'prenatal' || value == 'pregnancy' || value == 'postpartum';

bool _validStatusCareStage(String? value) =>
    value == 'pregnancy' || value == 'postpartum';

bool _validVolumeUnit(String? value) => value == 'mL' || value == 'oz';

void _markDelete(
  Map<String, List<String>> deleteLegacyKeys,
  String bucket,
  String key,
) {
  final keys = deleteLegacyKeys.putIfAbsent(bucket, () => <String>[]);
  if (!keys.contains(key)) keys.add(key);
}
