import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/frontal_posture_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

void main() {
  test(
    'measures shoulder asymmetry and trunk lateral lean from a front view',
    () {
      final analyzer = FrontalPostureAnalyzer(
        minimumStableFor: Duration.zero,
        minimumSamples: 1,
      );

      final result = analyzer.add(
        _frontPose(
          leftShoulderX: 0.34,
          leftShoulderY: 0.43,
          rightShoulderX: 0.78,
          rightShoulderY: 0.51,
          leftHipX: 0.44,
          rightHipX: 0.56,
        ),
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 1000,
      );

      expect(result, isNotNull);
      expect(
        result!.shoulderClassification,
        ShoulderHeightClassification.asymmetryTendency,
      );
      expect(result.higherShoulder, 'left');
      expect(
        result.trunkClassification,
        TrunkLateralLeanClassification.lateralLeanTendency,
      );
      expect(result.userMessage, isNot(contains('确诊')));
    },
  );

  test('rejects a side view for frontal measurements', () {
    final analyzer = FrontalPostureAnalyzer(
      minimumStableFor: Duration.zero,
      minimumSamples: 1,
    );

    final result = analyzer.add(
      _frontPose(
        leftShoulderX: 0.49,
        leftShoulderY: 0.45,
        rightShoulderX: 0.51,
        rightShoulderY: 0.45,
        leftHipX: 0.49,
        rightHipX: 0.51,
      ),
      at: Duration.zero,
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNull);
    expect(analyzer.lastFrameStatus, FrontalPostureFrameStatus.needsFrontView);
  });

  test('returns reference classifications for a level centered pose', () {
    final analyzer = FrontalPostureAnalyzer(
      minimumStableFor: Duration.zero,
      minimumSamples: 1,
    );

    final result = analyzer.add(
      _frontPose(
        leftShoulderX: 0.28,
        leftShoulderY: 0.45,
        rightShoulderX: 0.72,
        rightShoulderY: 0.45,
        leftHipX: 0.42,
        rightHipX: 0.58,
      ),
      at: Duration.zero,
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNotNull);
    expect(
      result!.shoulderClassification,
      ShoulderHeightClassification.referenceRange,
    );
    expect(
      result.trunkClassification,
      TrunkLateralLeanClassification.referenceRange,
    );
  });
}

MotionPose _frontPose({
  required double leftShoulderX,
  required double leftShoulderY,
  required double rightShoulderX,
  required double rightShoulderY,
  required double leftHipX,
  required double rightHipX,
}) {
  const confidence = 0.95;
  MotionPoseLandmark point(double x, double y) => MotionPoseLandmark(
    x: x,
    y: y,
    z: 0,
    visibility: confidence,
    presence: confidence,
  );
  return MotionPose(
    centerX: 0.5,
    centerY: 0.5,
    bodyScale: 0.6,
    landmarks: {
      MotionPoseLandmarkType.leftShoulder: point(leftShoulderX, leftShoulderY),
      MotionPoseLandmarkType.rightShoulder: point(
        rightShoulderX,
        rightShoulderY,
      ),
      MotionPoseLandmarkType.leftHip: point(leftHipX, 0.78),
      MotionPoseLandmarkType.rightHip: point(rightHipX, 0.78),
    },
  );
}
