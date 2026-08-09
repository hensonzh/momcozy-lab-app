import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

void main() {
  test(
    'returns a stable side-view craniovertebral angle without diagnosing',
    () {
      final analyzer = ForwardHeadAnalyzer(
        minimumStableFor: const Duration(seconds: 2),
        minimumSamples: 3,
        maximumSampleGap: const Duration(milliseconds: 1100),
      );
      final pose = _sidePose(
        earX: 0.70,
        earY: 0.40,
        shoulderX: 0.50,
        shoulderY: 0.60,
      );

      expect(
        analyzer.add(
          pose,
          at: Duration.zero,
          inputWidth: 1000,
          inputHeight: 1000,
        ),
        isNull,
      );
      expect(
        analyzer.add(
          pose,
          at: const Duration(seconds: 1),
          inputWidth: 1000,
          inputHeight: 1000,
        ),
        isNull,
      );
      final result = analyzer.add(
        pose,
        at: const Duration(seconds: 2),
        inputWidth: 1000,
        inputHeight: 1000,
      );

      expect(result, isNotNull);
      expect(result!.metric, 'craniovertebral_angle');
      expect(result.valueDegrees, closeTo(45, 0.2));
      expect(result.side, 'left');
      expect(result.classification, ForwardHeadClassification.forwardTendency);
      expect(result.userMessage, isNot(contains('确诊')));
      expect(result.userMessage, contains('当前画面'));
    },
  );

  test('uses the reliable right side when the left side is occluded', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumStableFor: Duration.zero,
      minimumSamples: 1,
    );

    final result = analyzer.add(
      _sidePose(
        earX: 0.7,
        earY: 0.4,
        shoulderX: 0.5,
        shoulderY: 0.6,
        visibility: 0.2,
        includeReliableRightSide: true,
      ),
      at: Duration.zero,
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNotNull);
    expect(result!.side, 'right');
    expect(result.valueDegrees, closeTo(45, 0.2));
  });

  test('rejects frames when side landmarks are not sufficiently visible', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumStableFor: Duration.zero,
      minimumSamples: 1,
    );

    final result = analyzer.add(
      _sidePose(
        earX: 0.7,
        earY: 0.4,
        shoulderX: 0.5,
        shoulderY: 0.6,
        visibility: 0.3,
      ),
      at: Duration.zero,
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNull);
  });

  test(
    'uses input dimensions so the angle is independent of frame aspect ratio',
    () {
      final landscapeAnalyzer = ForwardHeadAnalyzer(
        minimumStableFor: Duration.zero,
        minimumSamples: 1,
      );
      final portraitAnalyzer = ForwardHeadAnalyzer(
        minimumStableFor: Duration.zero,
        minimumSamples: 1,
      );

      final landscape = landscapeAnalyzer.add(
        _sidePose(earX: 0.60, earY: 0.40, shoulderX: 0.50, shoulderY: 0.60),
        at: Duration.zero,
        inputWidth: 2000,
        inputHeight: 1000,
      );
      final portrait = portraitAnalyzer.add(
        _sidePose(earX: 0.70, earY: 0.50, shoulderX: 0.50, shoulderY: 0.60),
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 2000,
      );

      expect(landscape, isNotNull);
      expect(portrait, isNotNull);
      expect(landscape!.valueDegrees, closeTo(45, 0.2));
      expect(portrait!.valueDegrees, closeTo(45, 0.2));
    },
  );

  test(
    'rejects a front-facing pose until the shoulders indicate a side view',
    () {
      final analyzer = ForwardHeadAnalyzer(
        minimumStableFor: Duration.zero,
        minimumSamples: 1,
      );

      final result = analyzer.add(
        _sidePose(
          earX: 0.55,
          earY: 0.40,
          shoulderX: 0.35,
          shoulderY: 0.60,
          rightShoulderX: 0.65,
          rightHipX: 0.62,
        ),
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 1000,
      );

      expect(result, isNull);
      expect(analyzer.lastFrameStatus, ForwardHeadFrameStatus.needsSideView);
    },
  );

  test('restarts the stable window after a rejected frame', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumStableFor: const Duration(seconds: 2),
      minimumSamples: 3,
      maximumSampleGap: const Duration(milliseconds: 1100),
    );
    final pose = _sidePose(
      earX: 0.70,
      earY: 0.40,
      shoulderX: 0.50,
      shoulderY: 0.60,
    );

    expect(
      analyzer.add(
        pose,
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 1000,
      ),
      isNull,
    );
    expect(
      analyzer.add(
        pose,
        at: const Duration(seconds: 1),
        inputWidth: 1000,
        inputHeight: 1000,
      ),
      isNull,
    );
    analyzer.rejectFrame();

    for (final second in [3, 4]) {
      expect(
        analyzer.add(
          pose,
          at: Duration(seconds: second),
          inputWidth: 1000,
          inputHeight: 1000,
        ),
        isNull,
      );
    }
    final result = analyzer.add(
      pose,
      at: const Duration(seconds: 5),
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNotNull);
    expect(result!.sampleCount, 3);
  });
}

MotionPose _sidePose({
  required double earX,
  required double earY,
  required double shoulderX,
  required double shoulderY,
  double visibility = 0.95,
  bool includeReliableRightSide = false,
  double rightShoulderX = 0.50,
  double rightHipX = 0.50,
}) {
  return MotionPose(
    centerX: 0.5,
    centerY: 0.5,
    bodyScale: 0.55,
    landmarks: {
      MotionPoseLandmarkType.leftEar: MotionPoseLandmark(
        x: earX,
        y: earY,
        z: 0,
        visibility: visibility,
        presence: visibility,
      ),
      MotionPoseLandmarkType.leftShoulder: MotionPoseLandmark(
        x: shoulderX,
        y: shoulderY,
        z: 0,
        visibility: visibility,
        presence: visibility,
      ),
      MotionPoseLandmarkType.leftHip: MotionPoseLandmark(
        x: 0.5,
        y: 0.85,
        z: 0,
        visibility: visibility,
        presence: visibility,
      ),
      ...{
        MotionPoseLandmarkType.rightEar: const MotionPoseLandmark(
          x: 0.3,
          y: 0.4,
          z: 0,
          visibility: 0.95,
          presence: 0.95,
        ),
        MotionPoseLandmarkType.rightShoulder: MotionPoseLandmark(
          x: rightShoulderX,
          y: 0.6,
          z: 0,
          visibility: 0.95,
          presence: 0.95,
        ),
        MotionPoseLandmarkType.rightHip: MotionPoseLandmark(
          x: rightHipX,
          y: 0.85,
          z: 0,
          visibility: includeReliableRightSide ? 0.95 : visibility,
          presence: includeReliableRightSide ? 0.95 : visibility,
        ),
      },
    },
  );
}
