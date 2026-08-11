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

const forwardHeadAnalyzerVersion = 'forward_head_cva_v5';
const forwardHeadThresholdVersion = 'cva_50deg_visual_tendency_v1';

class ForwardHeadFrameInspection {
  const ForwardHeadFrameInspection({
    required this.status,
    this.side,
    this.missingRegions = const [],
  });

  final ForwardHeadFrameStatus status;
  final String? side;
  final List<String> missingRegions;

  bool get accepted => status == ForwardHeadFrameStatus.accepted;
}

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

/// Estimates a side-view craniovertebral angle from a tolerant rolling window.
///
/// Short landmark or framing losses pause useful sampling instead of erasing it.
/// A result is emitted only after the window contains enough accepted samples,
/// enough elapsed time, and the configured accepted-frame ratio.
class ForwardHeadAnalyzer {
  ForwardHeadAnalyzer({
    this.minimumStableFor = const Duration(seconds: 4),
    this.minimumSamples = 20,
    this.minimumLandmarkConfidence = 0.5,
    this.forwardTendencyBelowDegrees = 50,
    Duration maximumSampleGap = const Duration(seconds: 4),
    Duration? interruptionGracePeriod,
    this.samplingWindow = const Duration(seconds: 10),
    this.minimumAcceptedRatio = 0.6,
    this.maximumShoulderSpanToTorsoRatio = 0.55,
    this.maximumShoulderSpanToHeadLengthRatio = 0.8,
  }) : maximumSampleGap = maximumSampleGap,
       interruptionGracePeriod = interruptionGracePeriod ?? maximumSampleGap,
       assert(minimumAcceptedRatio >= 0 && minimumAcceptedRatio <= 1),
       assert(!samplingWindow.isNegative),
       assert(!minimumStableFor.isNegative);

  final Duration minimumStableFor;
  final int minimumSamples;
  final double minimumLandmarkConfidence;
  final double forwardTendencyBelowDegrees;

  /// Kept as a public compatibility alias for callers that configured the old
  /// contiguous-window implementation.
  final Duration maximumSampleGap;
  final Duration interruptionGracePeriod;
  final Duration samplingWindow;
  final double minimumAcceptedRatio;
  final double maximumShoulderSpanToTorsoRatio;
  final double maximumShoulderSpanToHeadLengthRatio;

  final List<_SamplingObservation> _window = <_SamplingObservation>[];
  Duration? _lastObservationAt;
  Duration? _invalidSince;
  double _maximumReportedProgress = 0;
  ForwardHeadFrameStatus _lastFrameStatus =
      ForwardHeadFrameStatus.insufficientLandmarks;
  ForwardHeadFrameInspection _lastInspection = const ForwardHeadFrameInspection(
    status: ForwardHeadFrameStatus.insufficientLandmarks,
  );

  ForwardHeadFrameStatus get lastFrameStatus => _lastFrameStatus;
  ForwardHeadFrameInspection get lastInspection => _lastInspection;
  int get sampleCount => _accepted.length;
  int get observedFrameCount => _window.length;
  double get acceptedRatio =>
      _window.isEmpty ? 0 : sampleCount / _window.length;
  Duration get stableDuration {
    final accepted = _accepted;
    return accepted.length < 2
        ? Duration.zero
        : accepted.last.at - accepted.first.at;
  }

  double? get rollingMedianDegrees {
    final angles = _angles;
    return angles.isEmpty ? null : _median(angles);
  }

  double? get angleDispersionDegrees {
    final angles = _angles;
    return angles.isEmpty ? null : _medianAbsoluteDeviation(angles);
  }

  String? get dominantSide => _accepted.isEmpty ? null : _dominantSide();
  double get samplingProgress {
    final sampleProgress = minimumSamples <= 0
        ? 1.0
        : sampleCount / minimumSamples;
    final durationProgress = minimumStableFor.inMilliseconds <= 0
        ? 1.0
        : stableDuration.inMilliseconds / minimumStableFor.inMilliseconds;
    final ratioProgress = minimumAcceptedRatio <= 0
        ? 1.0
        : acceptedRatio / minimumAcceptedRatio;
    final current = math
        .min(sampleProgress, math.min(durationProgress, ratioProgress))
        .clamp(0, 1)
        .toDouble();
    _maximumReportedProgress = math.max(_maximumReportedProgress, current);
    return _maximumReportedProgress;
  }

  ForwardHeadFrameInspection inspect(
    MotionPose pose, {
    required int inputWidth,
    required int inputHeight,
  }) {
    if (inputWidth <= 0 || inputHeight <= 0) {
      return _recordInspection(
        const ForwardHeadFrameInspection(
          status: ForwardHeadFrameStatus.invalidFrameSize,
        ),
      );
    }
    final sideViewStatus = _sideViewStatus(
      pose,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    if (sideViewStatus != ForwardHeadFrameStatus.accepted) {
      return _recordInspection(
        ForwardHeadFrameInspection(
          status: sideViewStatus,
          missingRegions:
              sideViewStatus == ForwardHeadFrameStatus.insufficientLandmarks
              ? _missingSideRegions(pose)
              : const [],
        ),
      );
    }
    final sidePose = _selectSide(pose);
    if (sidePose == null) {
      return _recordInspection(
        ForwardHeadFrameInspection(
          status: ForwardHeadFrameStatus.insufficientLandmarks,
          missingRegions: _missingSideRegions(pose),
        ),
      );
    }
    return _recordInspection(
      ForwardHeadFrameInspection(
        status: ForwardHeadFrameStatus.accepted,
        side: sidePose.side,
      ),
    );
  }

  ForwardHeadResult? add(
    MotionPose pose, {
    required Duration at,
    required int inputWidth,
    required int inputHeight,
  }) {
    final inspection = inspect(
      pose,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    if (!inspection.accepted) {
      _recordRejected(at, inspection.status, inspection: inspection);
      return null;
    }
    final sidePose = _selectSide(pose);
    if (sidePose == null) {
      _recordRejected(at, ForwardHeadFrameStatus.insufficientLandmarks);
      return null;
    }
    final horizontal =
        (sidePose.ear.x - sidePose.shoulder.x).abs() * inputWidth;
    final vertical = (sidePose.shoulder.y - sidePose.ear.y).abs() * inputHeight;
    if (horizontal < 1 && vertical < 1) {
      _recordRejected(at, ForwardHeadFrameStatus.insufficientLandmarks);
      return null;
    }
    final angle = math.atan2(vertical, horizontal) * 180 / math.pi;
    _prepareForObservation(at);
    _invalidSince = null;
    _lastFrameStatus = ForwardHeadFrameStatus.accepted;
    _window.add(
      _SamplingObservation.accepted(
        at: at,
        angle: angle,
        side: sidePose.side,
        confidence: sidePose.confidence,
      ),
    );
    _lastObservationAt = at;
    _pruneWindow(at);

    if (sampleCount < minimumSamples ||
        stableDuration < minimumStableFor ||
        acceptedRatio < minimumAcceptedRatio) {
      return null;
    }

    final angles = _angles;
    final median = _median(angles);
    final dispersion = _medianAbsoluteDeviation(angles);
    final classification = median < forwardTendencyBelowDegrees
        ? ForwardHeadClassification.forwardTendency
        : ForwardHeadClassification.neutralRange;
    return ForwardHeadResult(
      metric: 'craniovertebral_angle',
      valueDegrees: median,
      classification: classification,
      sampleCount: sampleCount,
      sampleDuration: stableDuration,
      userMessage: classification == ForwardHeadClassification.forwardTendency
          ? '当前画面呈现头部前移倾向，建议结合更多角度与专业评估综合判断。'
          : '当前画面的头颈位置处于参考范围，请继续保持自然站姿。',
      side: _dominantSide(),
      angleDispersionDegrees: dispersion,
      measurementQualityScore: _measurementQualityScore(dispersion),
    );
  }

  void rejectFrame({Duration? at}) {
    if (at == null) {
      reset();
      _lastFrameStatus = ForwardHeadFrameStatus.interrupted;
      return;
    }
    _recordRejected(at, ForwardHeadFrameStatus.interrupted);
  }

  void reset() {
    _clearWindow();
    _lastFrameStatus = ForwardHeadFrameStatus.insufficientLandmarks;
    _lastInspection = const ForwardHeadFrameInspection(
      status: ForwardHeadFrameStatus.insufficientLandmarks,
    );
  }

  void _recordRejected(
    Duration at,
    ForwardHeadFrameStatus status, {
    ForwardHeadFrameInspection? inspection,
  }) {
    final rejectionInspection =
        inspection ?? ForwardHeadFrameInspection(status: status);
    _prepareForObservation(at);
    _invalidSince ??= at;
    _window.add(_SamplingObservation.rejected(at: at));
    _lastObservationAt = at;
    _lastFrameStatus = status;
    _lastInspection = rejectionInspection;
    _pruneWindow(at);
    if (at - _invalidSince! >= interruptionGracePeriod) {
      _clearWindow(lastObservationAt: at);
      _invalidSince = at;
      _lastFrameStatus = status;
      _lastInspection = rejectionInspection;
    }
  }

  void _prepareForObservation(Duration at) {
    final previous = _lastObservationAt;
    if (previous != null &&
        (at < previous || at - previous > interruptionGracePeriod)) {
      _clearWindow();
    }
  }

  void _pruneWindow(Duration now) {
    if (samplingWindow == Duration.zero) return;
    final earliest = now - samplingWindow;
    _window.removeWhere((sample) => sample.at < earliest);
  }

  List<_SamplingObservation> get _accepted =>
      _window.where((sample) => sample.accepted).toList(growable: false);

  List<double> get _angles =>
      _accepted.map((sample) => sample.angle!).toList(growable: false);

  ForwardHeadFrameStatus _sideViewStatus(
    MotionPose pose, {
    required int inputWidth,
    required int inputHeight,
  }) {
    final leftShoulder = pose.landmark(MotionPoseLandmarkType.leftShoulder);
    final rightShoulder = pose.landmark(MotionPoseLandmarkType.rightShoulder);
    final leftReliable =
        leftShoulder?.isReliable(
          minimumConfidence: minimumLandmarkConfidence,
        ) ==
        true;
    final rightReliable =
        rightShoulder?.isReliable(
          minimumConfidence: minimumLandmarkConfidence,
        ) ==
        true;
    if (leftReliable != rightReliable) {
      return ForwardHeadFrameStatus.accepted;
    }
    if (!leftReliable) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }

    final shoulderSpan = _pixelDistance(
      leftShoulder!,
      rightShoulder!,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
    );
    final leftHip = pose.landmark(MotionPoseLandmarkType.leftHip);
    final rightHip = pose.landmark(MotionPoseLandmarkType.rightHip);
    final hipsReliable =
        leftHip?.isReliable(minimumConfidence: minimumLandmarkConfidence) ==
            true &&
        rightHip?.isReliable(minimumConfidence: minimumLandmarkConfidence) ==
            true;
    if (hipsReliable) {
      final leftTorso = _pixelDistance(
        leftShoulder,
        leftHip!,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
      );
      final rightTorso = _pixelDistance(
        rightShoulder,
        rightHip!,
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

    final headLengths = <double>[];
    for (final pair in [
      (pose.landmark(MotionPoseLandmarkType.leftEar), leftShoulder),
      (pose.landmark(MotionPoseLandmarkType.rightEar), rightShoulder),
    ]) {
      final ear = pair.$1;
      final shoulder = pair.$2;
      if (ear?.isReliable(minimumConfidence: minimumLandmarkConfidence) !=
          true) {
        continue;
      }
      headLengths.add(
        _pixelDistance(
          ear!,
          shoulder,
          inputWidth: inputWidth,
          inputHeight: inputHeight,
        ),
      );
    }
    if (headLengths.isEmpty) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }
    final headLength = headLengths.reduce((a, b) => a + b) / headLengths.length;
    if (headLength < 1) {
      return ForwardHeadFrameStatus.insufficientLandmarks;
    }
    return shoulderSpan / headLength <= maximumShoulderSpanToHeadLengthRatio
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
      ),
      _sideCandidate(
        pose,
        side: 'right',
        earType: MotionPoseLandmarkType.rightEar,
        shoulderType: MotionPoseLandmarkType.rightShoulder,
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
  }) {
    final ear = pose.landmark(earType);
    final shoulder = pose.landmark(shoulderType);
    if (ear == null || shoulder == null) return null;
    final landmarks = [ear, shoulder];
    if (!landmarks.every(
      (value) => value.isReliable(minimumConfidence: minimumLandmarkConfidence),
    )) {
      return null;
    }
    final confidence = landmarks
        .map((value) => value.confidenceScore)
        .reduce(math.min);
    return _ForwardHeadSidePose(
      side: side,
      ear: ear,
      shoulder: shoulder,
      confidence: confidence,
    );
  }

  List<String> _missingSideRegions(MotionPose pose) {
    List<String> missingForSide({
      required MotionPoseLandmarkType ear,
      required MotionPoseLandmarkType shoulder,
    }) {
      bool unavailable(MotionPoseLandmarkType type) {
        final point = pose.landmark(type);
        return point == null ||
            !point.isReliable(minimumConfidence: minimumLandmarkConfidence);
      }

      return <String>[
        if (unavailable(ear)) 'ear',
        if (unavailable(shoulder)) 'shoulder',
      ];
    }

    final left = missingForSide(
      ear: MotionPoseLandmarkType.leftEar,
      shoulder: MotionPoseLandmarkType.leftShoulder,
    );
    final right = missingForSide(
      ear: MotionPoseLandmarkType.rightEar,
      shoulder: MotionPoseLandmarkType.rightShoulder,
    );
    return List.unmodifiable(left.length <= right.length ? left : right);
  }

  ForwardHeadFrameInspection _recordInspection(
    ForwardHeadFrameInspection inspection,
  ) {
    _lastFrameStatus = inspection.status;
    return _lastInspection = inspection;
  }

  String _dominantSide() {
    final sides = _accepted.map((sample) => sample.side);
    final left = sides.where((value) => value == 'left').length;
    final right = sampleCount - left;
    return right > left ? 'right' : 'left';
  }

  double _measurementQualityScore(double dispersion) {
    final accepted = _accepted;
    final confidence = accepted.isEmpty
        ? 0.0
        : accepted.map((sample) => sample.confidence!).reduce((a, b) => a + b) /
              accepted.length;
    final dispersionScore = (1 - dispersion / 10).clamp(0, 1).toDouble();
    final sampleScore = minimumSamples <= 0
        ? 1.0
        : (sampleCount / minimumSamples).clamp(0, 1).toDouble();
    final durationScore = minimumStableFor.inMilliseconds <= 0
        ? 1.0
        : (stableDuration.inMilliseconds / minimumStableFor.inMilliseconds)
              .clamp(0, 1)
              .toDouble();
    return (confidence * 0.35 +
            dispersionScore * 0.25 +
            sampleScore * 0.15 +
            durationScore * 0.15 +
            acceptedRatio * 0.10)
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

  void _clearWindow({Duration? lastObservationAt}) {
    _window.clear();
    _lastObservationAt = lastObservationAt;
    _invalidSince = null;
    _maximumReportedProgress = 0;
  }
}

class _SamplingObservation {
  const _SamplingObservation._({
    required this.at,
    required this.accepted,
    this.angle,
    this.side,
    this.confidence,
  });

  const _SamplingObservation.accepted({
    required Duration at,
    required double angle,
    required String side,
    required double confidence,
  }) : this._(
         at: at,
         accepted: true,
         angle: angle,
         side: side,
         confidence: confidence,
       );

  const _SamplingObservation.rejected({required Duration at})
    : this._(at: at, accepted: false);

  final Duration at;
  final bool accepted;
  final double? angle;
  final String? side;
  final double? confidence;
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
