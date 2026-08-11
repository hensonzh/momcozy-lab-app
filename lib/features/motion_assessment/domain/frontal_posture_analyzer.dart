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

class FrontalPostureFrameInspection {
  const FrontalPostureFrameInspection({
    required this.status,
    this.missingRegions = const [],
  });

  final FrontalPostureFrameStatus status;
  final List<String> missingRegions;

  bool get accepted => status == FrontalPostureFrameStatus.accepted;
}

const frontalPostureAnalyzerVersion = 'frontal_posture_v3';
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
    this.minimumStableFor = const Duration(seconds: 4),
    this.minimumSamples = 20,
    this.minimumLandmarkConfidence = 0.5,
    this.minimumAcceptedRatio = 0.6,
    this.samplingWindow = const Duration(seconds: 10),
    this.interruptionGracePeriod = const Duration(seconds: 4),
    this.minimumShoulderSpanToTorsoRatio = 0.65,
    this.minimumShoulderSpanOfFrame = 0.12,
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
  final double minimumShoulderSpanOfFrame;
  final double shoulderAsymmetryThresholdDegrees;
  final double trunkLeanThresholdDegrees;

  final List<_FrontalSample> _window = [];
  Duration? _lastObservationAt;
  Duration? _invalidSince;
  double _maximumProgress = 0;
  FrontalPostureFrameStatus _lastFrameStatus =
      FrontalPostureFrameStatus.insufficientLandmarks;
  FrontalPostureFrameInspection _lastInspection =
      const FrontalPostureFrameInspection(
        status: FrontalPostureFrameStatus.insufficientLandmarks,
      );

  FrontalPostureFrameStatus get lastFrameStatus => _lastFrameStatus;
  FrontalPostureFrameInspection get lastInspection => _lastInspection;
  int get sampleCount => _window.where((sample) => sample.accepted).length;
  int get observedFrameCount => _window.length;
  double get acceptedRatio =>
      _window.isEmpty ? 0 : sampleCount / _window.length;
  Duration get stableDuration {
    final accepted = _window.where((sample) => sample.accepted).toList();
    return accepted.length < 2
        ? Duration.zero
        : accepted.last.at - accepted.first.at;
  }

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
    bool assessShoulderHeight = true,
    bool assessTrunkLean = true,
  }) => inspectDetails(
    pose,
    inputWidth: inputWidth,
    inputHeight: inputHeight,
    assessShoulderHeight: assessShoulderHeight,
    assessTrunkLean: assessTrunkLean,
  ).status;

  FrontalPostureFrameInspection inspectDetails(
    MotionPose pose, {
    required int inputWidth,
    required int inputHeight,
    bool assessShoulderHeight = true,
    bool assessTrunkLean = true,
  }) {
    assert(assessShoulderHeight || assessTrunkLean);
    if (inputWidth <= 0 || inputHeight <= 0) {
      return _recordInspection(FrontalPostureFrameStatus.invalidFrameSize);
    }
    final requireHips = assessTrunkLean;
    final missingRegions = _missingRegions(pose, requireHips: requireHips);
    if (missingRegions.isNotEmpty) {
      return _recordInspection(
        FrontalPostureFrameStatus.insufficientLandmarks,
        missingRegions: missingRegions,
      );
    }
    final points = _points(pose, requireHips: requireHips);
    if (points == null) {
      return _recordInspection(FrontalPostureFrameStatus.insufficientLandmarks);
    }
    final shoulderSpan = _distance(
      points.leftShoulder,
      points.rightShoulder,
      inputWidth,
      inputHeight,
    );
    final frontViewConfirmed = requireHips
        ? _frontViewConfirmedWithTorso(
            points,
            shoulderSpan: shoulderSpan,
            inputWidth: inputWidth,
            inputHeight: inputHeight,
          )
        : shoulderSpan / inputWidth >= minimumShoulderSpanOfFrame;
    if (!frontViewConfirmed) {
      return _recordInspection(FrontalPostureFrameStatus.needsFrontView);
    }
    return _recordInspection(FrontalPostureFrameStatus.accepted);
  }

  FrontalPostureResult? add(
    MotionPose pose, {
    required Duration at,
    required int inputWidth,
    required int inputHeight,
    bool assessShoulderHeight = true,
    bool assessTrunkLean = true,
  }) {
    assert(assessShoulderHeight || assessTrunkLean);
    final inspection = inspectDetails(
      pose,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      assessShoulderHeight: assessShoulderHeight,
      assessTrunkLean: assessTrunkLean,
    );
    if (!inspection.accepted) {
      _reject(at, inspection.status, inspection: inspection);
      return null;
    }
    final points = _points(pose, requireHips: assessTrunkLean)!;
    _prepare(at);
    _invalidSince = null;
    final shoulderAngle = assessShoulderHeight
        ? _lineAngle(
            points.leftShoulder,
            points.rightShoulder,
            inputWidth,
            inputHeight,
          )
        : null;
    final relativeShoulderAngle = shoulderAngle == null
        ? null
        : assessTrunkLean
        ? _normalizedLineDifference(
            shoulderAngle,
            _lineAngle(
              points.leftHip!,
              points.rightHip!,
              inputWidth,
              inputHeight,
            ),
          )
        : shoulderAngle;
    final trunkLean = assessTrunkLean
        ? _trunkLean(points, inputWidth: inputWidth, inputHeight: inputHeight)
        : null;
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
    final shoulder = assessShoulderHeight
        ? _median(accepted.map((sample) => sample.shoulderAngle!).toList())
        : 0.0;
    final trunk = assessTrunkLean
        ? _median(accepted.map((sample) => sample.trunkLean!).toList())
        : 0.0;
    final dispersions = <double>[
      if (assessShoulderHeight)
        _mad(accepted.map((sample) => sample.shoulderAngle!).toList()),
      if (assessTrunkLean)
        _mad(accepted.map((sample) => sample.trunkLean!).toList()),
    ];
    final dispersion = dispersions.reduce(math.max);
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
    _lastInspection = const FrontalPostureFrameInspection(
      status: FrontalPostureFrameStatus.insufficientLandmarks,
    );
  }

  void _reject(
    Duration at,
    FrontalPostureFrameStatus status, {
    FrontalPostureFrameInspection? inspection,
  }) {
    final rejectionInspection =
        inspection ?? FrontalPostureFrameInspection(status: status);
    _prepare(at);
    _invalidSince ??= at;
    _window.add(_FrontalSample.rejected(at));
    _lastObservationAt = at;
    _lastFrameStatus = status;
    _lastInspection = rejectionInspection;
    _prune(at);
    if (at - _invalidSince! >= interruptionGracePeriod) {
      reset();
      _lastObservationAt = at;
      _invalidSince = at;
      _lastFrameStatus = status;
      _lastInspection = rejectionInspection;
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

  _FrontalPoints? _points(MotionPose pose, {required bool requireHips}) {
    final leftShoulder = pose.landmark(MotionPoseLandmarkType.leftShoulder);
    final rightShoulder = pose.landmark(MotionPoseLandmarkType.rightShoulder);
    final leftHip = pose.landmark(MotionPoseLandmarkType.leftHip);
    final rightHip = pose.landmark(MotionPoseLandmarkType.rightHip);
    final points = [
      leftShoulder,
      rightShoulder,
      if (requireHips) leftHip,
      if (requireHips) rightHip,
    ];
    if (points.any(
      (point) =>
          point == null ||
          !point.isReliable(minimumConfidence: minimumLandmarkConfidence),
    )) {
      return null;
    }
    return _FrontalPoints(leftShoulder!, rightShoulder!, leftHip, rightHip);
  }

  List<String> _missingRegions(MotionPose pose, {required bool requireHips}) {
    bool unavailable(MotionPoseLandmarkType type) {
      final point = pose.landmark(type);
      return point == null ||
          !point.isReliable(minimumConfidence: minimumLandmarkConfidence);
    }

    return <String>[
      if (unavailable(MotionPoseLandmarkType.leftShoulder)) 'left_shoulder',
      if (unavailable(MotionPoseLandmarkType.rightShoulder)) 'right_shoulder',
      if (requireHips && unavailable(MotionPoseLandmarkType.leftHip))
        'left_hip',
      if (requireHips && unavailable(MotionPoseLandmarkType.rightHip))
        'right_hip',
    ];
  }

  bool _frontViewConfirmedWithTorso(
    _FrontalPoints points, {
    required double shoulderSpan,
    required int inputWidth,
    required int inputHeight,
  }) {
    final torso =
        (_distance(
              points.leftShoulder,
              points.leftHip!,
              inputWidth,
              inputHeight,
            ) +
            _distance(
              points.rightShoulder,
              points.rightHip!,
              inputWidth,
              inputHeight,
            )) /
        2;
    return torso >= 1 &&
        shoulderSpan / torso >= minimumShoulderSpanToTorsoRatio;
  }

  double _trunkLean(
    _FrontalPoints points, {
    required int inputWidth,
    required int inputHeight,
  }) {
    final shoulderMidX =
        (points.leftShoulder.x + points.rightShoulder.x) / 2 * inputWidth;
    final shoulderMidY =
        (points.leftShoulder.y + points.rightShoulder.y) / 2 * inputHeight;
    final hipMidX = (points.leftHip!.x + points.rightHip!.x) / 2 * inputWidth;
    final hipMidY = (points.leftHip!.y + points.rightHip!.y) / 2 * inputHeight;
    return math.atan2(shoulderMidX - hipMidX, (hipMidY - shoulderMidY).abs()) *
        180 /
        math.pi;
  }

  FrontalPostureFrameInspection _recordInspection(
    FrontalPostureFrameStatus status, {
    List<String> missingRegions = const [],
  }) {
    _lastFrameStatus = status;
    return _lastInspection = FrontalPostureFrameInspection(
      status: status,
      missingRegions: List.unmodifiable(missingRegions),
    );
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
  final MotionPoseLandmark? leftHip;
  final MotionPoseLandmark? rightHip;
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
    required double? shoulderAngle,
    required double? trunkLean,
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
