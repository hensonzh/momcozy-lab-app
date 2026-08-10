import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_event.dart';

void main() {
  test('builds a versioned bounded semantic event envelope', () {
    final factory = MotionAssessmentEventFactory(assessmentId: 'assessment-1');

    final event = factory.create(
      type: 'turn_to_other_side',
      stateRevision: 7,
      facts: const {'completed_segments': 1, 'required_segments': 2},
      requiresVoiceResponse: true,
    );

    expect(event['schema_version'], 'motion_assessment.event.v4');
    expect(event['assessment_id'], 'assessment-1');
    expect(event['sequence'], 1);
    expect(event['event_id'], 'assessment-1:1');
    expect(event['priority'], 'phase_action');
    expect(event['requires_voice_response'], isTrue);
    expect(event['state_revision'], 7);
    expect(event['facts'], {'completed_segments': 1, 'required_segments': 2});
    expect(event, isNot(contains('raw_landmarks')));
  });

  test('deduplicates repeated framing events but never suppresses safety', () {
    var now = DateTime.utc(2026, 8, 10);
    final gate = MotionAssessmentEventGate(
      cooldown: const Duration(seconds: 2),
      now: () => now,
    );

    expect(
      gate.shouldSend(type: 'framing_incomplete', dedupeKey: 'framing'),
      isTrue,
    );
    expect(
      gate.shouldSend(type: 'framing_incomplete', dedupeKey: 'framing'),
      isFalse,
    );
    expect(
      gate.shouldSend(type: 'safety_stop', dedupeKey: 'dizziness'),
      isTrue,
    );
    expect(
      gate.shouldSend(type: 'safety_stop', dedupeKey: 'dizziness'),
      isTrue,
    );

    now = now.add(const Duration(seconds: 2));
    expect(
      gate.shouldSend(type: 'framing_incomplete', dedupeKey: 'framing'),
      isTrue,
    );
  });
}
