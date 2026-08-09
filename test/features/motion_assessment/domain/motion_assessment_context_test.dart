import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';

void main() {
  test('serializes bounded strong semantics without raw pose data', () {
    final snapshot = MotionAssessmentContextSnapshot(
      assessmentId: 'assessment-1',
      sequence: 7,
      observedAtMs: 2150,
      target: 'forward_head',
      phase: 'sampling',
      elapsedMs: 2150,
      personCount: 1,
      targetLocked: true,
      continuity: 'continuous',
      fullBodyVisible: true,
      missingRegions: const [],
      distance: 'acceptable',
      requiredView: 'side',
      detectedView: 'side',
      detectedSide: 'left',
      alignmentQuality: 'accepted',
      samplingState: 'collecting',
      validSamples: 9,
      requiredSamples: 12,
      stableDurationMs: 1500,
      requiredDurationMs: 2000,
      samplingProgress: 0.75,
      rejectionReasons: const [],
      measurementStatus: 'provisional',
      metric: 'craniovertebral_angle',
      rollingMedian: 48.1,
      dispersion: 1.3,
      unit: 'degrees',
      multiplePeople: false,
      targetChanged: false,
      discomfortReported: false,
      recommendedAction: 'hold_still',
      guidanceReason: 'stable_samples_needed',
    );

    final json = snapshot.toJson();
    expect(json['schema_version'], 'motion_assessment.context.v2');
    expect((json['sampling']! as Map)['progress'], 0.75);
    expect((json['measurement']! as Map)['rolling_median'], 48.1);
    expect(snapshot.toRealtimeInstructions(), contains('本地质量门是权威来源'));
    expect(json.toString(), isNot(contains('landmarks')));
    expect(json.toString(), isNot(contains('video')));
  });
}
