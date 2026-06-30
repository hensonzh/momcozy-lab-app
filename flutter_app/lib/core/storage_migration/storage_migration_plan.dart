import 'dart:convert';

class StorageMigrationPlan {
  StorageMigrationPlan({
    required this.scopedKeyValue,
    required this.chatMessages,
    required this.calibration,
    required this.deviceRepository,
    required this.deleteLegacyKeys,
    required this.diagnostics,
    required this.migrationVersion,
  });

  final Map<String, Object?> scopedKeyValue;
  final List<Map<String, Object?>> chatMessages;
  final Map<String, Object?>? calibration;
  final Map<String, Object?> deviceRepository;
  final Map<String, List<String>> deleteLegacyKeys;
  final List<Map<String, Object?>> diagnostics;
  final int migrationVersion;
}

StorageMigrationPlan buildStorageMigrationPlan(Map<String, Object?> fixture) {
  final legacy = _record(fixture['legacy']) ?? const {};
  final local = _stringMap(_record(legacy['localStorage']));
  final session = _stringMap(_record(legacy['sessionStorage']));
  final capacitor = _stringMap(_record(legacy['capacitorPreferences']));
  final context = _record(fixture['context']) ?? const {};
  final diagnostics = <Map<String, Object?>>[];
  final deleteLegacyKeys = <String, List<String>>{};

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
  final resolvedStage = _validMomStage(storedStage)
      ? storedStage!
      : (_validMomStage(_string(context['envDefaultMomStage']))
            ? _string(context['envDefaultMomStage'])!
            : 'postpartum');
  if (storedStage != null && !_validMomStage(storedStage)) {
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
    'calibration.promptDisabled':
        local['calibration_prompt_disabled'] == 'true',
    'calibration.declineCount': _safeInt(local['calibration_decline_count']),
    'preferences.volumeUnit': _validVolumeUnit(local['volume-unit'])
        ? local['volume-unit']!
        : 'mL',
    'notifications.backgroundNotifyOnboardingDone':
        capacitor['mmc_background_notify_onboarding_done'] == '1',
    'notifications.scheduleReminderOn':
        capacitor['mmc_schedule_reminder_on'] == '1',
  };
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
    scoped['status.careStage'] = _validMomStage(careStage)
        ? careStage
        : 'postpartum';
  }

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

  return StorageMigrationPlan(
    scopedKeyValue: scoped,
    chatMessages: chatMessages ?? const [],
    calibration: calibration,
    deviceRepository: devices ?? const {'L': null, 'R': null},
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

String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int _safeInt(String? value) {
  final parsed = int.tryParse(value ?? '');
  return parsed == null || parsed < 0 ? 0 : parsed;
}

bool _validGear(int value) => value >= 1 && value <= 15;

bool _validMomStage(String? value) =>
    value == 'pregnancy' || value == 'postpartum';

bool _validVolumeUnit(String? value) => value == 'mL' || value == 'oz';
