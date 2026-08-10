import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_capability.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_plan.dart';

void main() {
  test('registry exposes only validated targets as available', () {
    expect(motionAssessmentCapabilities.available.map((item) => item.target), [
      MotionAssessmentTarget.forwardHead,
      MotionAssessmentTarget.shoulderHeightAsymmetry,
      MotionAssessmentTarget.trunkLateralLean,
    ]);
    expect(
      motionAssessmentCapabilities
          .byTarget(MotionAssessmentTarget.gait)
          .unavailableReason,
      'platform_parity_and_protocol_validation_required',
    );
  });

  test('plan groups two frontal targets into one capture step', () {
    final plan = MotionAssessmentPlan.initial().apply(
      action: MotionAssessmentPlanAction.replace,
      targets: const [
        MotionAssessmentTarget.forwardHead,
        MotionAssessmentTarget.shoulderHeightAsymmetry,
        MotionAssessmentTarget.trunkLateralLean,
      ],
      expectedRevision: 0,
    );

    expect(plan.revision, 1);
    expect(plan.confirmed, isFalse);
    expect(plan.captureSteps, hasLength(3));
    expect(plan.captureSteps[0].view, MotionAssessmentCaptureView.side);
    expect(plan.captureSteps[1].requiredSide, 'opposite');
    expect(plan.captureSteps[2].view, MotionAssessmentCaptureView.front);
    expect(plan.captureSteps[2].targets, {
      MotionAssessmentTarget.shoulderHeightAsymmetry,
      MotionAssessmentTarget.trunkLateralLean,
    });
  });

  test('every available project produces a complete capture path', () {
    final expected =
        <MotionAssessmentTarget, List<MotionAssessmentCaptureView>>{
          MotionAssessmentTarget.forwardHead: const [
            MotionAssessmentCaptureView.side,
            MotionAssessmentCaptureView.side,
          ],
          MotionAssessmentTarget.shoulderHeightAsymmetry: const [
            MotionAssessmentCaptureView.front,
          ],
          MotionAssessmentTarget.trunkLateralLean: const [
            MotionAssessmentCaptureView.front,
          ],
        };

    for (final entry in expected.entries) {
      final plan = MotionAssessmentPlan.initial().apply(
        action: MotionAssessmentPlanAction.replace,
        targets: [entry.key],
        expectedRevision: 0,
      );

      expect(
        plan.captureSteps.map((step) => step.view),
        entry.value,
        reason: '${entry.key.wireValue} must not enter an empty wait state',
      );
      expect(
        plan.captureSteps.every((step) => step.targets.contains(entry.key)),
        isTrue,
      );
    }
  });

  test('plan rejects unavailable targets and stale mutations', () {
    final initial = MotionAssessmentPlan.initial();
    expect(
      () => initial.apply(
        action: MotionAssessmentPlanAction.replace,
        targets: const [MotionAssessmentTarget.roundedShoulders],
        expectedRevision: 0,
      ),
      throwsA(
        isA<MotionAssessmentPlanException>().having(
          (error) => error.code,
          'code',
          'assessment_target_unavailable',
        ),
      ),
    );

    final changed = initial.apply(
      action: MotionAssessmentPlanAction.add,
      targets: const [MotionAssessmentTarget.forwardHead],
      expectedRevision: 0,
    );
    expect(
      () => changed.apply(
        action: MotionAssessmentPlanAction.confirm,
        targets: const [],
        expectedRevision: 0,
      ),
      throwsA(
        isA<MotionAssessmentPlanException>().having(
          (error) => error.code,
          'code',
          'plan_revision_conflict',
        ),
      ),
    );
  });
}
