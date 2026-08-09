import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';

void main() {
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

  test('requires a complete body before calibration can finish', () {
    final gate = MotionQualityGate(
      singlePersonStableFor: const Duration(seconds: 1),
    );

    final framing = gate.evaluate(
      _observation(0, [_pose(centerX: 0.5, includeAnkle: false)]),
    );
    expect(framing.phase, MotionQualityPhase.framing);
    expect(framing.acceptFrame, isFalse);
    expect(framing.directive, MotionGuidanceDirective.adjustFraming);

    final stillFraming = gate.evaluate(
      _observation(1200, [_pose(centerX: 0.5, includeAnkle: false)]),
    );
    expect(stillFraming.acceptFrame, isFalse);
    expect(stillFraming.directive, isNull);

    expect(
      gate.evaluate(_observation(1300, [_pose(centerX: 0.5)])).acceptFrame,
      isFalse,
    );
    expect(
      gate.evaluate(_observation(2300, [_pose(centerX: 0.5)])).acceptFrame,
      isTrue,
    );
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
    final gate = _readyGate();

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
}

MotionQualityGate _readyGate() {
  final gate = MotionQualityGate(
    singlePersonStableFor: const Duration(seconds: 1),
    multiplePeopleStableFor: const Duration(milliseconds: 400),
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
  bool includeAnkle = true,
}) {
  const reliable = MotionPoseLandmark(
    x: 0.5,
    y: 0.5,
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
      MotionPoseLandmarkType.leftShoulder: reliable,
      MotionPoseLandmarkType.leftHip: reliable,
      MotionPoseLandmarkType.leftKnee: reliable,
      if (includeAnkle)
        MotionPoseLandmarkType.leftAnkle: const MotionPoseLandmark(
          x: 0.5,
          y: 0.92,
          z: 0,
          visibility: 0.95,
          presence: 0.95,
        ),
    },
  );
}
