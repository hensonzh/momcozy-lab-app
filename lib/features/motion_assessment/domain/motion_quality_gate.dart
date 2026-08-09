import 'dart:math' as math;

import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';

enum MotionQualityPhase {
  calibrating,
  framing,
  ready,
  checkingMultiplePeople,
  pausedMultiplePeople,
  reacquiring,
  targetChanged,
}

enum MotionGuidanceDirective {
  adjustFraming,
  singlePersonReady,
  askOthersToLeave,
  assessmentResumed,
  confirmRecalibration,
}

class MotionQualityDecision {
  const MotionQualityDecision({
    required this.phase,
    required this.acceptFrame,
    this.directive,
    this.target,
  });

  final MotionQualityPhase phase;
  final bool acceptFrame;
  final MotionGuidanceDirective? directive;
  final MotionPose? target;
}

/// Deterministic, on-device quality gate for the assessment frame stream.
///
/// A frame is accepted only after one person has remained stable. When two or
/// more poses are detected, assessment frames are dropped immediately; the
/// user-facing pause directive is emitted once after the configured debounce.
class MotionQualityGate {
  MotionQualityGate({
    this.singlePersonStableFor = const Duration(seconds: 1),
    this.multiplePeopleStableFor = const Duration(milliseconds: 400),
    this.maximumCenterDrift = 0.22,
    this.maximumScaleRatioChange = 0.45,
    this.minimumLandmarkConfidence = 0.45,
    this.frameEdgeMargin = 0.02,
  });

  final Duration singlePersonStableFor;
  final Duration multiplePeopleStableFor;
  final double maximumCenterDrift;
  final double maximumScaleRatioChange;
  final double minimumLandmarkConfidence;
  final double frameEdgeMargin;

  MotionQualityPhase _phase = MotionQualityPhase.calibrating;
  Duration? _singleSince;
  Duration? _multipleSince;
  MotionPose? _target;
  bool _multiplePromptEmitted = false;
  bool _targetChangedPromptEmitted = false;
  bool _framingPromptEmitted = false;
  bool _recalibrationRequested = false;

  MotionQualityDecision evaluate(MotionPoseObservation observation) {
    final poses = observation.poses;
    final now = observation.timestamp;

    if (_phase == MotionQualityPhase.targetChanged &&
        !_recalibrationRequested) {
      return _decision(
        MotionQualityPhase.targetChanged,
        directive: _emitTargetChangedPrompt(),
      );
    }
    if (_recalibrationRequested) {
      _resetForCalibration();
    }

    if (poses.length >= 2) {
      _singleSince = null;
      _multipleSince ??= now;
      final persisted = now - _multipleSince! >= multiplePeopleStableFor;
      _phase = persisted
          ? MotionQualityPhase.pausedMultiplePeople
          : MotionQualityPhase.checkingMultiplePeople;
      final directive = persisted && !_multiplePromptEmitted
          ? MotionGuidanceDirective.askOthersToLeave
          : null;
      if (directive != null) _multiplePromptEmitted = true;
      return _decision(_phase, directive: directive);
    }

    _multipleSince = null;
    if (poses.isEmpty) {
      _singleSince = null;
      if (_target == null) {
        _phase = MotionQualityPhase.calibrating;
      } else {
        _phase = MotionQualityPhase.reacquiring;
      }
      return _decision(_phase);
    }

    final candidate = poses.single;
    if (!_hasCompleteBody(candidate)) {
      _singleSince = null;
      _phase = MotionQualityPhase.framing;
      final directive = _framingPromptEmitted
          ? null
          : MotionGuidanceDirective.adjustFraming;
      _framingPromptEmitted = true;
      return _decision(_phase, directive: directive);
    }
    _framingPromptEmitted = false;

    if (_target != null && !_matchesTarget(candidate, _target!)) {
      _phase = MotionQualityPhase.targetChanged;
      _singleSince = null;
      return _decision(_phase, directive: _emitTargetChangedPrompt());
    }

    if (_phase == MotionQualityPhase.ready && _target != null) {
      _target = candidate;
      return _decision(
        MotionQualityPhase.ready,
        acceptFrame: true,
        target: candidate,
      );
    }

    _singleSince ??= now;
    final stable = now - _singleSince! >= singlePersonStableFor;
    if (!stable) {
      _phase = _target == null
          ? MotionQualityPhase.calibrating
          : MotionQualityPhase.reacquiring;
      return _decision(_phase, target: candidate);
    }

    final wasReacquiring = _target != null;
    _target = candidate;
    _phase = MotionQualityPhase.ready;
    _singleSince = null;
    final directive = wasReacquiring
        ? MotionGuidanceDirective.assessmentResumed
        : MotionGuidanceDirective.singlePersonReady;
    _multiplePromptEmitted = false;
    return _decision(
      _phase,
      acceptFrame: true,
      directive: directive,
      target: candidate,
    );
  }

  void confirmRecalibration() {
    if (_phase == MotionQualityPhase.targetChanged) {
      _recalibrationRequested = true;
    }
  }

  bool _matchesTarget(MotionPose candidate, MotionPose target) {
    final dx = candidate.centerX - target.centerX;
    final dy = candidate.centerY - target.centerY;
    final centerDistance = math.sqrt(dx * dx + dy * dy);
    final largestScale = math.max(candidate.bodyScale, target.bodyScale);
    final scaleChange = largestScale <= 0
        ? 0.0
        : (candidate.bodyScale - target.bodyScale).abs() / largestScale;
    return centerDistance <= maximumCenterDrift &&
        scaleChange <= maximumScaleRatioChange;
  }

  bool _hasCompleteBody(MotionPose pose) {
    final nose = pose.landmark(MotionPoseLandmarkType.nose);
    if (!_isVisibleInFrame(nose)) return false;
    return _sideIsVisible(
          pose,
          shoulder: MotionPoseLandmarkType.leftShoulder,
          hip: MotionPoseLandmarkType.leftHip,
          knee: MotionPoseLandmarkType.leftKnee,
          ankle: MotionPoseLandmarkType.leftAnkle,
        ) ||
        _sideIsVisible(
          pose,
          shoulder: MotionPoseLandmarkType.rightShoulder,
          hip: MotionPoseLandmarkType.rightHip,
          knee: MotionPoseLandmarkType.rightKnee,
          ankle: MotionPoseLandmarkType.rightAnkle,
        );
  }

  bool _sideIsVisible(
    MotionPose pose, {
    required MotionPoseLandmarkType shoulder,
    required MotionPoseLandmarkType hip,
    required MotionPoseLandmarkType knee,
    required MotionPoseLandmarkType ankle,
  }) {
    return [
      shoulder,
      hip,
      knee,
      ankle,
    ].map(pose.landmark).every(_isVisibleInFrame);
  }

  bool _isVisibleInFrame(MotionPoseLandmark? landmark) {
    if (landmark == null ||
        !landmark.isReliable(minimumConfidence: minimumLandmarkConfidence)) {
      return false;
    }
    final upper = 1 - frameEdgeMargin;
    return landmark.x >= frameEdgeMargin &&
        landmark.x <= upper &&
        landmark.y >= frameEdgeMargin &&
        landmark.y <= upper;
  }

  MotionGuidanceDirective? _emitTargetChangedPrompt() {
    if (_targetChangedPromptEmitted) return null;
    _targetChangedPromptEmitted = true;
    return MotionGuidanceDirective.confirmRecalibration;
  }

  void _resetForCalibration() {
    _phase = MotionQualityPhase.calibrating;
    _target = null;
    _singleSince = null;
    _multipleSince = null;
    _multiplePromptEmitted = false;
    _targetChangedPromptEmitted = false;
    _framingPromptEmitted = false;
    _recalibrationRequested = false;
  }

  MotionQualityDecision _decision(
    MotionQualityPhase phase, {
    bool acceptFrame = false,
    MotionGuidanceDirective? directive,
    MotionPose? target,
  }) {
    return MotionQualityDecision(
      phase: phase,
      acceptFrame: acceptFrame,
      directive: directive,
      target: target,
    );
  }
}
