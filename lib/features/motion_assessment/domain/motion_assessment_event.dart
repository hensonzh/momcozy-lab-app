enum MotionAssessmentEventPriority {
  safety('safety'),
  userSpeech('user_speech'),
  phaseAction('phase_action'),
  framing('framing'),
  progress('progress');

  const MotionAssessmentEventPriority(this.value);

  final String value;
}

class MotionAssessmentEventFactory {
  MotionAssessmentEventFactory({required this.assessmentId});

  final String assessmentId;
  int _sequence = 0;

  Map<String, Object?> create({
    required String type,
    required int stateRevision,
    required Map<String, Object?> facts,
    required bool requiresVoiceResponse,
    String? dedupeKey,
  }) {
    final sequence = ++_sequence;
    final normalizedType = type.trim();
    return <String, Object?>{
      'schema_version': 'motion_assessment.event.v4',
      'event_id': '$assessmentId:$sequence',
      'assessment_id': assessmentId,
      'sequence': sequence,
      'type': normalizedType,
      'priority': _priorityFor(normalizedType).value,
      'requires_voice_response': requiresVoiceResponse,
      'dedupe_key': dedupeKey?.trim().isNotEmpty == true
          ? dedupeKey!.trim()
          : normalizedType,
      'state_revision': stateRevision,
      'facts': Map<String, Object?>.unmodifiable(facts),
    };
  }

  MotionAssessmentEventPriority _priorityFor(String type) {
    if (type.startsWith('safety_') || type == 'multiple_people') {
      return MotionAssessmentEventPriority.safety;
    }
    if (type == 'user_speech_completed') {
      return MotionAssessmentEventPriority.userSpeech;
    }
    if (type == 'framing_incomplete' || type == 'person_not_detected') {
      return MotionAssessmentEventPriority.framing;
    }
    if (type == 'sampling_progress') {
      return MotionAssessmentEventPriority.progress;
    }
    return MotionAssessmentEventPriority.phaseAction;
  }
}

class MotionAssessmentEventGate {
  MotionAssessmentEventGate({
    this.cooldown = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration cooldown;
  final DateTime Function() _now;
  final Map<String, DateTime> _lastSentAt = <String, DateTime>{};

  bool shouldSend({required String type, required String dedupeKey}) {
    if (type.startsWith('safety_') || type == 'user_speech_completed') {
      return true;
    }
    final normalizedKey = '${type.trim()}:${dedupeKey.trim()}';
    final timestamp = _now();
    final previous = _lastSentAt[normalizedKey];
    if (previous != null && timestamp.difference(previous) < cooldown) {
      return false;
    }
    _lastSentAt[normalizedKey] = timestamp;
    return true;
  }
}
