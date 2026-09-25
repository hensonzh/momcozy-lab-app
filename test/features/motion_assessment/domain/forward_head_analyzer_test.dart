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
      expect(result.userMessage, isNot(contains('diagnosis')));
      expect(result.userMessage, contains('This view suggests'));
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

  test('accepts a reliable near side when far-side landmarks are absent', () {
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
        includeFarSideLandmarks: false,
      ),
      at: Duration.zero,
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNotNull);
    expect(result!.side, 'left');
  });

  test(
    'measures forward head posture without making hips a hard dependency',
    () {
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
          includeHips: false,
        ),
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 1000,
      );

      expect(result, isNotNull);
      expect(result!.valueDegrees, closeTo(45, 0.2));
    },
  );

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
        farSideVisibility: 0.3,
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

  test('keeps useful samples across a brief rejected frame', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumStableFor: const Duration(seconds: 2),
      minimumSamples: 3,
      samplingWindow: const Duration(seconds: 4),
      interruptionGracePeriod: const Duration(milliseconds: 1500),
      minimumAcceptedRatio: 0.7,
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
    analyzer.rejectFrame(at: const Duration(milliseconds: 1500));
    final result = analyzer.add(
      pose,
      at: const Duration(seconds: 2),
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(result, isNotNull);
    expect(result!.sampleCount, 3);
    expect(analyzer.acceptedRatio, 0.75);
  });

  test(
    'restarts only after an interruption persists beyond the grace period',
    () {
      final analyzer = ForwardHeadAnalyzer(
        minimumStableFor: const Duration(seconds: 2),
        minimumSamples: 3,
        samplingWindow: const Duration(seconds: 4),
        interruptionGracePeriod: const Duration(seconds: 1),
      );
      final pose = _sidePose(
        earX: 0.70,
        earY: 0.40,
        shoulderX: 0.50,
        shoulderY: 0.60,
      );

      analyzer.add(
        pose,
        at: Duration.zero,
        inputWidth: 1000,
        inputHeight: 1000,
      );
      analyzer.add(
        pose,
        at: const Duration(milliseconds: 500),
        inputWidth: 1000,
        inputHeight: 1000,
      );
      analyzer.rejectFrame(at: const Duration(milliseconds: 750));
      analyzer.rejectFrame(at: const Duration(seconds: 2));

      expect(analyzer.sampleCount, 0);
      expect(analyzer.samplingProgress, 0);

      for (final milliseconds in [2500, 3500]) {
        expect(
          analyzer.add(
            pose,
            at: Duration(milliseconds: milliseconds),
            inputWidth: 1000,
            inputHeight: 1000,
          ),
          isNull,
        );
      }
      final result = analyzer.add(
        pose,
        at: const Duration(milliseconds: 4500),
        inputWidth: 1000,
        inputHeight: 1000,
      );
      expect(result, isNotNull);
      expect(result!.sampleCount, 3);
    },
  );

  test('sampling progress never moves backwards during one rolling window', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumStableFor: const Duration(seconds: 2),
      minimumSamples: 3,
      samplingWindow: const Duration(seconds: 4),
      interruptionGracePeriod: const Duration(seconds: 1),
      minimumAcceptedRatio: 0.7,
    );
    final pose = _sidePose(
      earX: 0.70,
      earY: 0.40,
      shoulderX: 0.50,
      shoulderY: 0.60,
    );

    analyzer.add(pose, at: Duration.zero, inputWidth: 1000, inputHeight: 1000);
    analyzer.add(
      pose,
      at: const Duration(seconds: 1),
      inputWidth: 1000,
      inputHeight: 1000,
    );
    final beforeInterruption = analyzer.samplingProgress;
    analyzer.rejectFrame(at: const Duration(milliseconds: 1250));

    expect(analyzer.samplingProgress, greaterThanOrEqualTo(beforeInterruption));
  });

  test(
    'production sampling tolerates realistic side confidence and brief dropouts',
    () {
      final analyzer = ForwardHeadAnalyzer();
      ForwardHeadResult? result;

      for (var index = 0; index < 25; index += 1) {
        final nearConfidence = const {6, 7, 15}.contains(index) ? 0.35 : 0.55;
        result =
            analyzer.add(
              _sidePose(
                earX: 0.70,
                earY: 0.40,
                shoulderX: 0.50,
                shoulderY: 0.60,
                visibility: nearConfidence,
                farSideVisibility: 0.3,
              ),
              at: Duration(milliseconds: index * 200),
              inputWidth: 1000,
              inputHeight: 1000,
            ) ??
            result;
      }

      expect(result, isNotNull);
      expect(result!.sampleCount, greaterThanOrEqualTo(20));
      expect(analyzer.acceptedRatio, greaterThanOrEqualTo(0.6));
    },
  );

  test('a short two-second loss pauses instead of erasing useful samples', () {
    final analyzer = ForwardHeadAnalyzer(
      minimumLandmarkConfidence: 0.5,
      minimumStableFor: const Duration(seconds: 4),
      minimumSamples: 20,
      samplingWindow: const Duration(seconds: 10),
      minimumAcceptedRatio: 0.6,
    );
    final pose = _sidePose(
      earX: 0.70,
      earY: 0.40,
      shoulderX: 0.50,
      shoulderY: 0.60,
      visibility: 0.55,
      farSideVisibility: 0.3,
    );

    for (var index = 0; index < 10; index += 1) {
      analyzer.add(
        pose,
        at: Duration(milliseconds: index * 200),
        inputWidth: 1000,
        inputHeight: 1000,
      );
    }
    for (var index = 10; index < 22; index += 1) {
      analyzer.rejectFrame(at: Duration(milliseconds: index * 200));
    }
    ForwardHeadResult? result;
    for (var index = 22; index < 32; index += 1) {
      result =
          analyzer.add(
            pose,
            at: Duration(milliseconds: index * 200),
            inputWidth: 1000,
            inputHeight: 1000,
          ) ??
          result;
    }

    expect(result, isNotNull);
    expect(result!.sampleCount, 20);
  });

  test('reports the exact side region that prevents capture', () {
    final analyzer = ForwardHeadAnalyzer();

    final inspection = analyzer.inspect(
      _sidePose(
        earX: 0.70,
        earY: 0.40,
        shoulderX: 0.50,
        shoulderY: 0.60,
        visibility: 0.8,
        nearEarVisibility: 0.3,
        farSideVisibility: 0.3,
      ),
      inputWidth: 1000,
      inputHeight: 1000,
    );

    expect(inspection.status, ForwardHeadFrameStatus.insufficientLandmarks);
    expect(inspection.missingRegions, contains('ear'));
  });
}

MotionPose _sidePose({
  required double earX,
  required double earY,
  required double shoulderX,
  required double shoulderY,
  double visibility = 0.95,
  double? nearEarVisibility,
  double? farSideVisibility,
  bool includeReliableRightSide = false,
  bool includeFarSideLandmarks = true,
  bool includeHips = true,
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
        visibility: nearEarVisibility ?? visibility,
        presence: nearEarVisibility ?? visibility,
      ),
      MotionPoseLandmarkType.leftShoulder: MotionPoseLandmark(
        x: shoulderX,
        y: shoulderY,
        z: 0,
        visibility: visibility,
        presence: visibility,
      ),
      if (includeHips)
        MotionPoseLandmarkType.leftHip: MotionPoseLandmark(
          x: 0.5,
          y: 0.85,
          z: 0,
          visibility: visibility,
          presence: visibility,
        ),
      if (includeFarSideLandmarks) ...{
        MotionPoseLandmarkType.rightEar: MotionPoseLandmark(
          x: 0.3,
          y: 0.4,
          z: 0,
          visibility: farSideVisibility ?? 0.95,
          presence: farSideVisibility ?? 0.95,
        ),
        MotionPoseLandmarkType.rightShoulder: MotionPoseLandmark(
          x: rightShoulderX,
          y: 0.6,
          z: 0,
          visibility: farSideVisibility ?? 0.95,
          presence: farSideVisibility ?? 0.95,
        ),
        if (includeHips)
          MotionPoseLandmarkType.rightHip: MotionPoseLandmark(
            x: rightHipX,
            y: 0.85,
            z: 0,
            visibility: includeReliableRightSide
                ? 0.95
                : farSideVisibility ?? visibility,
            presence: includeReliableRightSide
                ? 0.95
                : farSideVisibility ?? visibility,
          ),
      },
    },
  );
}
