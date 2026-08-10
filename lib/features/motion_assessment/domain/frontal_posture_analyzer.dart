import 'dart:math' as math;

import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

enum ShoulderHeightClassification { referenceRange, asymmetryTendency }

enum TrunkLateralLeanClassification { referenceRange, lateralLeanTendency }

enum FrontalPostureFrameStatus {
  accepted,
  insufficientLandmarks,
  needsFrontView,
  invalidFrameSize,
  interrupted,
}

const frontalPostureAnalyzerVersion = 'frontal_posture_v1';
const frontalPostureThresholdVersion = 'frontal_visual_tendency_v1';

class FrontalPostureResult {
  const FrontalPostureResult({
    required this.shoulderHeightDifferenceDegrees,
    required this.shoulderClassification,
    required this.higherShoulder,
    required this.trunkLateralLeanDegrees,
    required this.trunkClassification,
    required this.leanDirection,
    required this.sampleCount,
    required this.sampleDuration,
    required this.angleDispersionDegrees,
    required this.measurementQualityScore,
    required this.userMessage,
  });

  final double shoulderHeightDifferenceDegrees;
  final ShoulderHeightClassification shoulderClassification;
  final String higherShoulder;
  final double trunkLateralLeanDegrees;
  final TrunkLateralLeanClassification trunkClassification;
  final String leanDirection;
  final int sampleCount;
  final Duration sampleDuration;
  final double angleDispersionDegrees;
  final double measurementQualityScore;
  final String userMessage;
}

class FrontalPostureAnalyzer {
  FrontalPostureAnalyzer({
    this.minimumStableFor = const Duration(seconds: 6),
    this.minimumSamples = 30,
    this.minimumLandmarkConfidence = 0.65,
    this.minimumAcceptedRatio = 0.7,
    this.samplingWindow = const Duration(seconds: 8),
    this.interruptionGracePeriod = const Duration(seconds: 2),
    this.minimumShoulderSpanToTorsoRatio = 0.65,
    this.shoulderAsymmetryThresholdDegrees = 3,
    this.trunkLeanThresholdDegrees = 4,
  });

  final Duration minimumStableFor;
  final int minimumSamples;
  final double minimumLandmarkConfidence;
  final double minimumAcceptedRatio;
  final Duration samplingWindow;
  final Duration interruptionGracePeriod;
  final double minimumShoulderSpanToTorsoRatio;
  final double shoulderAsymmetryThresholdDegrees;
  final double trunkLeanThresholdDegrees;

  final List<_FrontalSample> _window = [];
  Duration? _lastObservationAt;
  Duration? _invalidSince;
  double _maximumProgress = 0;
  FrontalPostureFrameStatus _lastFrameStatus =
      FrontalPostureFrameStatus.insufficientLandmarks;

  FrontalPostureFrameStatus get lastFrameStatus => _lastFrameStatus;
  int get sampleCount => _window.where((sample) => sample.accepted).length;
  int get observedFrameCount => _window.length;
  double get acceptedRatio =>
      _window.isEmpty ? 0 : sampleCount / _window.length;
  Duration get stableDuration =>
      _window.length < 2 ? Duration.zero : _window.last.at - _window.first.at;
  double get samplingProgress {
    final samples = minimumSamples <= 0 ? 1.0 : sampleCount / minimumSamples;
    final duration = minimumStableFor.inMilliseconds <= 0
        ? 1.0
        : stableDuration.inMilliseconds / minimumStableFor.inMilliseconds;
    final ratio = minimumAcceptedRatio <= 0
        ? 1.0
        : acceptedRatio / minimumAcceptedRatio;
    final current = math.min(samples, math.min(duration, ratio)).clamp(0, 1);
    _maximumProgress = math.max(_maximumProgress, current.toDouble());
    return _maximumProgress;
  }

  FrontalPostureFrameStatus inspect(
    MotionPose pose, {
    required int inputWidth,
    required int inputHeight,
  }) {
    if (inputWidth <= 0 || inputHeight <= 0) {
      return _lastFrameStatus = FrontalPostureFrameStatus.invalidFrameSize;
    }
    final points = _points(pose);
    if (points == null) {
      return _lastFrameStatus = FrontalPostureFrameStatus.insufficientLandmarks;
    }
    final shoulderSpan = _distance(
      points.leftShoulder,
      points.rightShoulder,
      inputWidth,
      inputHeight,
    );
    final torso =
        (_distance(
              points.leftShoulder,
              points.leftHip,
              inputWidth,
              inputHeight,
            ) +
            _distance(
              points.rightShoulder,
              points.rightHip,
              inputWidth,
              inputHeight,
            )) /
        2;
    if (torso < 1) {
      return _lastFrameStatus = FrontalPostureFrameStatus.insufficientLandmarks;
    }
    if (shoulderSpan / torso < minimumShoulderSpanToTorsoRatio) {
      return _lastFrameStatus = FrontalPostureFrameStatus.needsFrontView;
    }
    return _lastFrameStatus = FrontalPostureFrameStatus.accepted;
  }

  FrontalPostureResult? add(
    MotionPose pose, {
    required Duration at,
    required int inputWidth,
    required int inputHeight,
  }) {
    final status = inspect(
      pose,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    if (status != FrontalPostureFrameStatus.accepted) {
      _reject(at, status);
      return null;
    }
    final points = _points(pose)!;
    _prepare(at);
    _invalidSince = null;
    final shoulderAngle = _lineAngle(
      points.leftShoulder,
      points.rightShoulder,
      inputWidth,
      inputHeight,
    );
    final hipAngle = _lineAngle(
      points.leftHip,
      points.rightHip,
      inputWidth,
      inputHeight,
    );
    final relativeShoulderAngle = _normalizedLineDifference(
      shoulderAngle,
      hipAngle,
    );
    final shoulderMidX =
        (points.leftShoulder.x + points.rightShoulder.x) / 2 * inputWidth;
    final shoulderMidY =
        (points.leftShoulder.y + points.rightShoulder.y) / 2 * inputHeight;
    final hipMidX = (points.leftHip.x + points.rightHip.x) / 2 * inputWidth;
    final hipMidY = (points.leftHip.y + points.rightHip.y) / 2 * inputHeight;
    final trunkLean =
        math.atan2(shoulderMidX - hipMidX, (hipMidY - shoulderMidY).abs()) *
        180 /
        math.pi;
    _window.add(
      _FrontalSample.accepted(
        at: at,
        shoulderAngle: relativeShoulderAngle,
        trunkLean: trunkLean,
      ),
    );
    _lastObservationAt = at;
    _prune(at);
    if (sampleCount < minimumSamples ||
        stableDuration < minimumStableFor ||
        acceptedRatio < minimumAcceptedRatio) {
      return null;
    }

    final accepted = _window.where((sample) => sample.accepted).toList();
    final shoulder = _median(
      accepted.map((sample) => sample.shoulderAngle!).toList(),
    );
    final trunk = _median(accepted.map((sample) => sample.trunkLean!).toList());
    final dispersions = [
      _mad(accepted.map((sample) => sample.shoulderAngle!).toList()),
      _mad(accepted.map((sample) => sample.trunkLean!).toList()),
    ];
    final dispersion = math.max(dispersions[0], dispersions[1]);
    final shoulderClass = shoulder.abs() >= shoulderAsymmetryThresholdDegrees
        ? ShoulderHeightClassification.asymmetryTendency
        : ShoulderHeightClassification.referenceRange;
    final trunkClass = trunk.abs() >= trunkLeanThresholdDegrees
        ? TrunkLateralLeanClassification.lateralLeanTendency
        : TrunkLateralLeanClassification.referenceRange;
    return FrontalPostureResult(
      shoulderHeightDifferenceDegrees: shoulder.abs(),
      shoulderClassification: shoulderClass,
      higherShoulder: shoulder.abs() < shoulderAsymmetryThresholdDegrees
          ? 'balanced'
          : shoulder > 0
          ? 'left'
          : 'right',
      trunkLateralLeanDegrees: trunk.abs(),
      trunkClassification: trunkClass,
      leanDirection: trunk.abs() < trunkLeanThresholdDegrees
          ? 'centered'
          : trunk > 0
          ? 'right'
          : 'left',
      sampleCount: sampleCount,
      sampleDuration: stableDuration,
      angleDispersionDegrees: dispersion,
      measurementQualityScore: (1 - dispersion / 12).clamp(0, 1),
      userMessage:
          shoulderClass == ShoulderHeightClassification.asymmetryTendency ||
              trunkClass == TrunkLateralLeanClassification.lateralLeanTendency
          ? '当前正面画面呈现姿态偏移倾向，建议结合更多观察与专业评估综合判断。'
          : '当前正面画面处于参考范围，请继续保持自然站姿。',
    );
  }

  void rejectFrame({required Duration at}) =>
      _reject(at, FrontalPostureFrameStatus.interrupted);

  void reset() {
    _window.clear();
    _lastObservationAt = null;
    _invalidSince = null;
    _maximumProgress = 0;
    _lastFrameStatus = FrontalPostureFrameStatus.insufficientLandmarks;
  }

  void _reject(Duration at, FrontalPostureFrameStatus status) {
    _prepare(at);
    _invalidSince ??= at;
    _window.add(_FrontalSample.rejected(at));
    _lastObservationAt = at;
    _lastFrameStatus = status;
    _prune(at);
    if (at - _invalidSince! >= interruptionGracePeriod) {
      reset();
      _lastObservationAt = at;
      _invalidSince = at;
      _lastFrameStatus = status;
    }
  }

  void _prepare(Duration at) {
    final previous = _lastObservationAt;
    if (previous != null &&
        (at < previous || at - previous > interruptionGracePeriod)) {
      reset();
    }
  }

  void _prune(Duration at) {
    if (samplingWindow == Duration.zero) return;
    _window.removeWhere((sample) => sample.at < at - samplingWindow);
  }

  _FrontalPoints? _points(MotionPose pose) {
    final leftShoulder = pose.landmark(MotionPoseLandmarkType.leftShoulder);
    final rightShoulder = pose.landmark(MotionPoseLandmarkType.rightShoulder);
    final leftHip = pose.landmark(MotionPoseLandmarkType.leftHip);
    final rightHip = pose.landmark(MotionPoseLandmarkType.rightHip);
    final points = [leftShoulder, rightShoulder, leftHip, rightHip];
    if (points.any(
      (point) =>
          point == null ||
          !point.isReliable(minimumConfidence: minimumLandmarkConfidence),
    )) {
      return null;
    }
    return _FrontalPoints(leftShoulder!, rightShoulder!, leftHip!, rightHip!);
  }

  double _distance(
    MotionPoseLandmark a,
    MotionPoseLandmark b,
    int width,
    int height,
  ) {
    final dx = (a.x - b.x) * width;
    final dy = (a.y - b.y) * height;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _lineAngle(
    MotionPoseLandmark left,
    MotionPoseLandmark right,
    int width,
    int height,
  ) =>
      math.atan2((right.y - left.y) * height, (right.x - left.x) * width) *
      180 /
      math.pi;

  double _normalizedLineDifference(double first, double second) {
    var value = first - second;
    while (value > 90) {
      value -= 180;
    }
    while (value < -90) {
      value += 180;
    }
    return value;
  }

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _mad(List<double> values) {
    final median = _median(values);
    return _median(values.map((value) => (value - median).abs()).toList());
  }
}

class _FrontalPoints {
  const _FrontalPoints(
    this.leftShoulder,
    this.rightShoulder,
    this.leftHip,
    this.rightHip,
  );

  final MotionPoseLandmark leftShoulder;
  final MotionPoseLandmark rightShoulder;
  final MotionPoseLandmark leftHip;
  final MotionPoseLandmark rightHip;
}

class _FrontalSample {
  const _FrontalSample({
    required this.at,
    required this.accepted,
    this.shoulderAngle,
    this.trunkLean,
  });

  factory _FrontalSample.accepted({
    required Duration at,
    required double shoulderAngle,
    required double trunkLean,
  }) => _FrontalSample(
    at: at,
    accepted: true,
    shoulderAngle: shoulderAngle,
    trunkLean: trunkLean,
  );

  factory _FrontalSample.rejected(Duration at) =>
      _FrontalSample(at: at, accepted: false);

  final Duration at;
  final bool accepted;
  final double? shoulderAngle;
  final double? trunkLean;
}
