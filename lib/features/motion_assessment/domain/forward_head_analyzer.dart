import 'dart:math' as math;

import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

enum ForwardHeadClassification { neutralRange, forwardTendency }

enum ForwardHeadFrameStatus {
  accepted,
  insufficientLandmarks,
  needsSideView,
  invalidFrameSize,
  interrupted,
}

const forwardHeadAnalyzerVersion = 'forward_head_cva_v2';
const forwardHeadThresholdVersion = 'cva_50deg_visual_tendency_v1';

class ForwardHeadResult {
  const ForwardHeadResult({
    required this.metric,
    required this.valueDegrees,
    required this.classification,
    required this.userMessage,
    required this.sampleCount,
    required this.sampleDuration,
    required this.side,
    required this.angleDispersionDegrees,
    required this.measurementQualityScore,
  });

  final String metric;
  final double valueDegrees;
  final ForwardHeadClassification classification;
  final String userMessage;
  final int sampleCount;
  final Duration sampleDuration;
  final String side;
  final double angleDispersionDegrees;
  final double measurementQualityScore;
}

/// Estimates the side-view craniovertebral angle from accepted local poses.
///
/// It deliberately reports a visual tendency for the current frame rather than
/// a clinical diagnosis.
class ForwardHeadAnalyzer {
  ForwardHeadAnalyzer({
    this.minimumStableFor = const Duration(seconds: 2),
    this.minimumSamples = 12,
    this.minimumLandmarkConfidence = 0.65,
    this.forwardTendencyBelowDegrees = 50,
    this.maximumSampleGap = const Duration(milliseconds: 350),
    this.maximumShoulderSpanToTorsoRatio = 0.55,
  });

  final Duration minimumStableFor;
  final int minimumSamples;
  final double minimumLandmarkConfidence;
  final double forwardTendencyBelowDegrees;
  final Duration maximumSampleGap;
  final double maximumShoulderSpanToTorsoRatio;

  final List<double> _angles = <double>[];
  final List<String> _sides = <String>[];
  final List<double> _confidences = <double>[];
  Duration? _startedAt;
  Duration? _lastSampleAt;
  ForwardHeadFrameStatus _lastFrameStatus =
      ForwardHeadFrameStatus.insufficientLandmarks;

  ForwardHeadFrameStatus get lastFrameStatus => _lastFrameStatus;
  int get sampleCount => _angles.length;
  Duration get stableDuration => _startedAt == null || _lastSampleAt == null
      ? Duration.zero
      : _lastSampleAt! - _startedAt!;
  double? get rollingMedianDegrees => _angles.isEmpty ? null : _median(_angles);
  double? get angleDispersionDegrees =>
      _angles.isEmpty ? null : _medianAbsoluteDeviation(_angles);
  String? get dominantSide => _sides.isEmpty ? null : _dominantSide();
  double get samplingProgress {
    final sampleProgress = minimumSamples <= 0
        ? 1.0
        : _angles.length / minimumSamples;
    final durationProgress = minimumStableFor.inMilliseconds <= 0
        ? 1.0
        : stableDuration.inMilliseconds / minimumStableFor.inMilliseconds;
    return math.min(sampleProgress, durationProgress).clamp(0, 1).toDouble();
  }

  ForwardHeadResult? add(
    MotionPose pose, {
    required Duration at,
    required int inputWidth,
    required int inputHeight,
  }) {
    if (inputWidth <= 0 || inputHeight <= 0) {
      _reject(ForwardHeadFrameStatus.invalidFrameSize);
      return null;
    }
    final previousSampleAt = _lastSampleAt;
    if (previousSampleAt != null &&
        (at < previousSampleAt || at - previousSampleAt > maximumSampleGap)) {
      _clearWindow();
    }
    final sideViewStatus = _sideViewStatus(
      pose,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    if (sideViewStatus != ForwardHeadFrameStatus.accepted) {
      _reject(sideViewStatus);
      return null;
    }
    final sidePose = _selectSide(pose);
    if (sidePose == null) {
      _reject(ForwardHeadFrameStatus.insufficientLandmarks);
      return null;
    }
    final ear = sidePose.ear;
    final shoulder = sidePose.shoulder;

    final horizontal = (ear.x - shoulder.x).abs() * inputWidth;
    final vertical = (shoulder.y - ear.y).abs() * inputHeight;
    if (horizontal < 1 && vertical < 1) {
      _reject(ForwardHeadFrameStatus.insufficientLandmarks);
      return null;
    }
    final angle = math.atan2(vertical, horizontal) * 180 / math.pi;
    _startedAt ??= at;
    _lastSampleAt = at;
    _lastFrameStatus = ForwardHeadFrameStatus.accepted;
    _angles.add(angle);
    _sides.add(sidePose.side);
    _confidences.add(sidePose.confidence);

    if (_angles.length < minimumSamples ||
        at - _startedAt! < minimumStableFor) {
      return null;
    }

    final median = _median(_angles);
    final dispersion = _medianAbsoluteDeviation(_angles);
    final classification = median < forwardTendencyBelowDegrees
        ? ForwardHeadClassification.forwardTendency
        : ForwardHeadClassification.neutralRange;
    return ForwardHeadResult(
      metric: 'craniovertebral_angle',
      valueDegrees: median,
      classification: classification,
      sampleCount: _angles.length,
      sampleDuration: stableDuration,
      userMessage: classification == ForwardHeadClassification.forwardTendency
          ? '当前画面呈现头部前移倾向，建议结合更多角度与专业评估综合判断。'
          : '当前画面的头颈位置处于参考范围，请继续保持自然站姿。',
      side: _dominantSide(),
      angleDispersionDegrees: dispersion,
      measurementQualityScore: _measurementQualityScore(dispersion),
    );
  }

  ForwardHeadFrameStatus _sideViewStatus(
    MotionPose pose, {
    required int inputWidth,
    required int inputHeight,
  }) {
    final leftShoulder = pose.landmark(MotionPoseLandmarkType.leftShoulder);
    final rightShoulder = pose.landmark(MotionPoseLandmarkType.rightShoulder);
    final leftHip = pose.landmark(MotionPoseLandmarkType.leftHip);
    final rightHip = pose.landmark(MotionPoseLandmarkType.rightHip);
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }

    final leftReliable =
        leftShoulder.isReliable(minimumConfidence: minimumLandmarkConfidence) &&
        leftHip.isReliable(minimumConfidence: minimumLandmarkConfidence);
    final rightReliable =
        rightShoulder.isReliable(
          minimumConfidence: minimumLandmarkConfidence,
        ) &&
        rightHip.isReliable(minimumConfidence: minimumLandmarkConfidence);
    if (leftReliable != rightReliable) {
      return ForwardHeadFrameStatus.accepted;
    }
    if (!leftReliable) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }

    final shoulderSpan = _pixelDistance(
      leftShoulder,
      rightShoulder,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    final leftTorso = _pixelDistance(
      leftShoulder,
      leftHip,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    final rightTorso = _pixelDistance(
      rightShoulder,
      rightHip,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    final torsoLength = (leftTorso + rightTorso) / 2;
    if (torsoLength < 1) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }
    return shoulderSpan / torsoLength <= maximumShoulderSpanToTorsoRatio
        ? ForwardHeadFrameStatus.accepted
        : ForwardHeadFrameStatus.needsSideView;
  }

  double _pixelDistance(
    MotionPoseLandmark first,
    MotionPoseLandmark second, {
    required int inputWidth,
    required int inputHeight,
  }) {
    final dx = (first.x - second.x) * inputWidth;
    final dy = (first.y - second.y) * inputHeight;
    return math.sqrt(dx * dx + dy * dy);
  }

  _ForwardHeadSidePose? _selectSide(MotionPose pose) {
    final candidates = [
      _sideCandidate(
        pose,
        side: 'left',
        earType: MotionPoseLandmarkType.leftEar,
        shoulderType: MotionPoseLandmarkType.leftShoulder,
        hipType: MotionPoseLandmarkType.leftHip,
      ),
      _sideCandidate(
        pose,
        side: 'right',
        earType: MotionPoseLandmarkType.rightEar,
        shoulderType: MotionPoseLandmarkType.rightShoulder,
        hipType: MotionPoseLandmarkType.rightHip,
      ),
    ].whereType<_ForwardHeadSidePose>().toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  _ForwardHeadSidePose? _sideCandidate(
    MotionPose pose, {
    required String side,
    required MotionPoseLandmarkType earType,
    required MotionPoseLandmarkType shoulderType,
    required MotionPoseLandmarkType hipType,
  }) {
    final ear = pose.landmark(earType);
    final shoulder = pose.landmark(shoulderType);
    final hip = pose.landmark(hipType);
    if (ear == null || shoulder == null || hip == null) return null;
    final landmarks = [ear, shoulder, hip];
    if (!landmarks.every(
      (value) => value.isReliable(minimumConfidence: minimumLandmarkConfidence),
    )) {
      return null;
    }
    final confidence = landmarks
        .map((value) => math.min(value.visibility, value.presence))
        .reduce(math.min);
    return _ForwardHeadSidePose(
      side: side,
      ear: ear,
      shoulder: shoulder,
      confidence: confidence,
    );
  }

  String _dominantSide() {
    final left = _sides.where((value) => value == 'left').length;
    final right = _sides.length - left;
    return right > left ? 'right' : 'left';
  }

  double _measurementQualityScore(double dispersion) {
    final confidence = _confidences.isEmpty
        ? 0.0
        : _confidences.reduce((a, b) => a + b) / _confidences.length;
    final dispersionScore = (1 - dispersion / 10).clamp(0, 1).toDouble();
    final sampleScore = minimumSamples <= 0
        ? 1.0
        : (_angles.length / minimumSamples).clamp(0, 1).toDouble();
    final durationScore = minimumStableFor.inMilliseconds <= 0
        ? 1.0
        : (stableDuration.inMilliseconds / minimumStableFor.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
    return (confidence * 0.45 +
            dispersionScore * 0.25 +
            sampleScore * 0.15 +
            durationScore * 0.15)
        .clamp(0, 1)
        .toDouble();
  }

  double _median(List<double> values) {
    final sorted = List<double>.of(values)..sort();
    return sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
  }

  double _medianAbsoluteDeviation(List<double> values) {
    final median = _median(values);
    return _median(values.map((value) => (value - median).abs()).toList());
  }

  void rejectFrame() {
    _reject(ForwardHeadFrameStatus.interrupted);
  }

  void reset() {
    _clearWindow();
    _lastFrameStatus = ForwardHeadFrameStatus.insufficientLandmarks;
  }

  void _reject(ForwardHeadFrameStatus status) {
    _clearWindow();
    _lastFrameStatus = status;
  }

  void _clearWindow() {
    _angles.clear();
    _sides.clear();
    _confidences.clear();
    _startedAt = null;
    _lastSampleAt = null;
  }
}

class _ForwardHeadSidePose {
  const _ForwardHeadSidePose({
    required this.side,
    required this.ear,
    required this.shoulder,
    required this.confidence,
  });

  final String side;
  final MotionPoseLandmark ear;
  final MotionPoseLandmark shoulder;
  final double confidence;
}
