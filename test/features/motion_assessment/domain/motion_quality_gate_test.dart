import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';

void main() {
  test('emits one enter-frame directive until a person returns', () {
    final gate = MotionQualityGate(personMissingStableFor: Duration.zero);

    final first = gate.evaluate(_observation(0, const []));
    final repeated = gate.evaluate(_observation(66, const []));

    expect(first.directive, MotionGuidanceDirective.enterFrame);
    expect(repeated.directive, isNull);

    gate.evaluate(_observation(132, [_pose(centerX: 0.5)]));
    final lostAgain = gate.evaluate(_observation(198, const []));
    expect(lostAgain.directive, MotionGuidanceDirective.enterFrame);
  });

  test('requires one stable person before accepting assessment frames', () {
    final gate = MotionQualityGate(
      singlePersonStableFor: const Duration(seconds: 1),
      multiplePeopleStableFor: const Duration(milliseconds: 400),
    );

    expect(
      gate.evaluate(_observation(0, [_pose(centerX: 0.5)])),
      isA<MotionQualityDecision>()
          .having(
            (value) => value.phase,
            'phase',
            MotionQualityPhase.calibrating,
          )
          .having((value) => value.acceptFrame, 'acceptFrame', isFalse),
    );
    expect(
      gate.evaluate(_observation(999, [_pose(centerX: 0.5)])),
      isA<MotionQualityDecision>().having(
        (value) => value.acceptFrame,
        'acceptFrame',
        isFalse,
      ),
    );

    final ready = gate.evaluate(_observation(1000, [_pose(centerX: 0.5)]));
    expect(ready.phase, MotionQualityPhase.ready);
    expect(ready.acceptFrame, isTrue);
    expect(ready.directive, MotionGuidanceDirective.singlePersonReady);
  });

  test(
    'accepts every matching frame after calibration without repeating a directive',
    () {
      final gate = _readyGate();

      final next = gate.evaluate(_observation(1066, [_pose(centerX: 0.51)]));

      expect(next.phase, MotionQualityPhase.ready);
      expect(next.acceptFrame, isTrue);
      expect(next.directive, isNull);
    },
  );

  test('accepts head, shoulder and hip framing without legs or feet', () {
    final gate = MotionQualityGate(
      singlePersonStableFor: const Duration(seconds: 1),
    );

    final calibrating = gate.evaluate(
      _observation(0, [
        _pose(centerX: 0.5, includeKnee: false, includeAnkle: false),
      ]),
    );
    expect(calibrating.phase, MotionQualityPhase.calibrating);
    expect(calibrating.acceptFrame, isFalse);

    final ready = gate.evaluate(
      _observation(1000, [
        _pose(centerX: 0.5, includeKnee: false, includeAnkle: false),
      ]),
    );
    expect(ready.phase, MotionQualityPhase.ready);
    expect(ready.acceptFrame, isTrue);
  });

  test('calibrates from the upper-body region without requiring hips', () {
    final gate = MotionQualityGate(
      singlePersonStableFor: Duration.zero,
      framingIssueStableFor: Duration.zero,
    );

    final ready = gate.evaluate(
      _observation(0, [_pose(centerX: 0.5, includeHip: false)]),
    );
    expect(ready.phase, MotionQualityPhase.ready);
    expect(ready.acceptFrame, isTrue);
  });

  test('keeps the same target when hip landmarks disappear', () {
    final gate = MotionQualityGate(
      singlePersonStableFor: Duration.zero,
      targetMismatchStableFor: Duration.zero,
    );

    final initial = gate.evaluate(
      _observation(0, [_pose(centerX: 0.5, bodyScale: 0.9)]),
    );
    final withoutHips = gate.evaluate(
      _observation(66, [
        _pose(centerX: 0.5, bodyScale: 0.9, includeHip: false),
      ]),
    );

    expect(initial.phase, MotionQualityPhase.ready);
    expect(withoutHips.phase, MotionQualityPhase.ready);
    expect(withoutHips.acceptFrame, isTrue);
    expect(withoutHips.directive, isNull);
  });

  test('drops frames immediately and pauses after multiple people persist', () {
    final gate = _readyGate();

    final checking = gate.evaluate(
      _observation(1100, [_pose(centerX: 0.45), _pose(centerX: 0.8)]),
    );
    expect(checking.phase, MotionQualityPhase.checkingMultiplePeople);
    expect(checking.acceptFrame, isFalse);
    expect(checking.directive, isNull);

    final paused = gate.evaluate(
      _observation(1500, [_pose(centerX: 0.45), _pose(centerX: 0.8)]),
    );
    expect(paused.phase, MotionQualityPhase.pausedMultiplePeople);
    expect(paused.acceptFrame, isFalse);
    expect(paused.directive, MotionGuidanceDirective.askOthersToLeave);

    final duplicate = gate.evaluate(
      _observation(1700, [_pose(centerX: 0.45), _pose(centerX: 0.8)]),
    );
    expect(duplicate.directive, isNull);
  });

  test('resumes only after the same target is stable alone for one second', () {
    final gate = _readyGate();
    gate.evaluate(
      _observation(1100, [_pose(centerX: 0.5), _pose(centerX: 0.82)]),
    );
    gate.evaluate(
      _observation(1500, [_pose(centerX: 0.5), _pose(centerX: 0.82)]),
    );

    final reacquiring = gate.evaluate(
      _observation(1600, [_pose(centerX: 0.51)]),
    );
    expect(reacquiring.phase, MotionQualityPhase.reacquiring);
    expect(reacquiring.acceptFrame, isFalse);

    final resumed = gate.evaluate(_observation(2600, [_pose(centerX: 0.50)]));
    expect(resumed.phase, MotionQualityPhase.ready);
    expect(resumed.acceptFrame, isTrue);
    expect(resumed.directive, MotionGuidanceDirective.assessmentResumed);
  });

  test('does not silently switch to a different person after target loss', () {
    final gate = _readyGate(targetMismatchStableFor: Duration.zero);

    gate.evaluate(_observation(1200, const []));
    gate.evaluate(_observation(2200, const []));
    final changed = gate.evaluate(
      _observation(2300, [_pose(centerX: 0.12, bodyScale: 0.32)]),
    );

    expect(changed.phase, MotionQualityPhase.targetChanged);
    expect(changed.acceptFrame, isFalse);
    expect(changed.directive, MotionGuidanceDirective.confirmRecalibration);

    final stillBlocked = gate.evaluate(
      _observation(3500, [_pose(centerX: 0.12, bodyScale: 0.32)]),
    );
    expect(stillBlocked.phase, MotionQualityPhase.targetChanged);
    expect(stillBlocked.acceptFrame, isFalse);

    gate.confirmRecalibration();
    expect(
      gate
          .evaluate(_observation(3600, [_pose(centerX: 0.12, bodyScale: 0.32)]))
          .phase,
      MotionQualityPhase.calibrating,
    );
    final recalibrated = gate.evaluate(
      _observation(4600, [_pose(centerX: 0.12, bodyScale: 0.32)]),
    );
    expect(recalibrated.phase, MotionQualityPhase.ready);
    expect(recalibrated.acceptFrame, isTrue);
  });

  test('uses hysteresis before declaring that the tracked person changed', () {
    final gate = _readyGate(
      targetMismatchStableFor: const Duration(milliseconds: 800),
    );
    final different = _pose(centerX: 0.12, bodyScale: 0.32);

    final transient = gate.evaluate(_observation(1100, [different]));
    expect(transient.phase, MotionQualityPhase.reacquiring);
    expect(transient.directive, isNull);

    final recovered = gate.evaluate(_observation(1400, [_pose(centerX: 0.5)]));
    expect(recovered.phase, MotionQualityPhase.ready);
    expect(recovered.acceptFrame, isTrue);

    gate.evaluate(_observation(1600, [different]));
    final changed = gate.evaluate(_observation(2400, [different]));
    expect(changed.phase, MotionQualityPhase.targetChanged);
    expect(changed.directive, MotionGuidanceDirective.confirmRecalibration);
  });

  test(
    'planned orientation changes recalibrate without a target-changed alert',
    () {
      final gate = _readyGate(targetMismatchStableFor: Duration.zero);

      gate.beginPlannedRecalibration();
      final recalibrating = gate.evaluate(
        _observation(1100, [_pose(centerX: 0.5, bodyScale: 0.85)]),
      );

      expect(recalibrating.phase, MotionQualityPhase.calibrating);
      expect(recalibrating.directive, isNull);
      final ready = gate.evaluate(
        _observation(2100, [_pose(centerX: 0.5, bodyScale: 0.85)]),
      );
      expect(ready.phase, MotionQualityPhase.ready);
      expect(ready.directive, MotionGuidanceDirective.singlePersonReady);
    },
  );

  test(
    'brief framing loss pauses frames without emitting corrective chatter',
    () {
      final gate = _readyGate(
        framingIssueStableFor: const Duration(milliseconds: 600),
      );
      final cropped = _pose(centerX: 0.5, includeShoulder: false);

      final transient = gate.evaluate(_observation(1100, [cropped]));
      expect(transient.phase, MotionQualityPhase.reacquiring);
      expect(transient.acceptFrame, isFalse);
      expect(transient.directive, isNull);

      final recovered = gate.evaluate(
        _observation(1400, [_pose(centerX: 0.5)]),
      );
      expect(recovered.phase, MotionQualityPhase.ready);
      expect(recovered.acceptFrame, isTrue);
    },
  );
}

MotionQualityGate _readyGate({
  Duration targetMismatchStableFor = const Duration(milliseconds: 800),
  Duration framingIssueStableFor = const Duration(milliseconds: 600),
}) {
  final gate = MotionQualityGate(
    singlePersonStableFor: const Duration(seconds: 1),
    multiplePeopleStableFor: const Duration(milliseconds: 400),
    targetMismatchStableFor: targetMismatchStableFor,
    framingIssueStableFor: framingIssueStableFor,
  );
  gate.evaluate(_observation(0, [_pose(centerX: 0.5)]));
  gate.evaluate(_observation(1000, [_pose(centerX: 0.5)]));
  return gate;
}

MotionPoseObservation _observation(int milliseconds, List<MotionPose> poses) {
  return MotionPoseObservation(
    timestamp: Duration(milliseconds: milliseconds),
    poses: poses,
    inferenceTime: const Duration(milliseconds: 25),
  );
}

MotionPose _pose({
  required double centerX,
  double bodyScale = 0.5,
  bool includeHip = true,
  bool includeShoulder = true,
  bool includeKnee = true,
  bool includeAnkle = true,
}) {
  final shoulder = MotionPoseLandmark(
    x: centerX,
    y: 0.3,
    z: 0,
    visibility: 0.95,
    presence: 0.95,
  );
  final hip = MotionPoseLandmark(
    x: centerX,
    y: 0.3 + bodyScale * 0.5,
    z: 0,
    visibility: 0.95,
    presence: 0.95,
  );
  return MotionPose(
    centerX: centerX,
    centerY: 0.5,
    bodyScale: bodyScale,
    landmarks: {
      MotionPoseLandmarkType.nose: const MotionPoseLandmark(
        x: 0.5,
        y: 0.08,
        z: 0,
        visibility: 0.95,
        presence: 0.95,
      ),
      if (includeShoulder) MotionPoseLandmarkType.leftShoulder: shoulder,
      if (includeHip) MotionPoseLandmarkType.leftHip: hip,
      if (includeKnee)
        MotionPoseLandmarkType.leftKnee: MotionPoseLandmark(
          x: centerX,
          y: 0.72,
          z: 0,
          visibility: 0.95,
          presence: 0.95,
        ),
      if (includeAnkle)
        MotionPoseLandmarkType.leftAnkle: MotionPoseLandmark(
          x: centerX,
          y: 0.92,
          z: 0,
          visibility: 0.95,
          presence: 0.95,
        ),
    },
  );
}
