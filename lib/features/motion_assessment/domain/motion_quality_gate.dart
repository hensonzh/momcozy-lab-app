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
  enterFrame,
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
  bool _enterFramePromptEmitted = false;
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
      final directive = _enterFramePromptEmitted
          ? null
          : MotionGuidanceDirective.enterFrame;
      _enterFramePromptEmitted = true;
      return _decision(_phase, directive: directive);
    }

    _enterFramePromptEmitted = false;

    final candidate = poses.single;
    if (!_hasAssessmentRegion(candidate)) {
      _singleSince = null;
      _phase = MotionQualityPhase.framing;
      final directive = _framingPromptEmitted
          ? null
          : MotionGuidanceDirective.adjustFraming;
      _framingPromptEmitted = true;
      return _decision(_phase, directive: directive);
    }
    _framingPromptEmitted = false;
    _enterFramePromptEmitted = false;

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
    final candidateSignature = _assessmentSignature(candidate);
    final targetSignature = _assessmentSignature(target);
    if (candidateSignature == null || targetSignature == null) return false;
    final dx = candidateSignature.x - targetSignature.x;
    final dy = candidateSignature.y - targetSignature.y;
    final centerDistance = math.sqrt(dx * dx + dy * dy);
    final largestScale = math.max(
      candidateSignature.scale,
      targetSignature.scale,
    );
    final scaleChange = largestScale <= 0
        ? 0.0
        : (candidateSignature.scale - targetSignature.scale).abs() /
              largestScale;
    return centerDistance <= maximumCenterDrift &&
        scaleChange <= maximumScaleRatioChange;
  }

  bool _hasAssessmentRegion(MotionPose pose) {
    final headVisible = [
      MotionPoseLandmarkType.nose,
      MotionPoseLandmarkType.leftEar,
      MotionPoseLandmarkType.rightEar,
    ].map(pose.landmark).any(_isVisibleInFrame);
    if (!headVisible) return false;
    return _torsoSideIsVisible(
          pose,
          shoulder: MotionPoseLandmarkType.leftShoulder,
          hip: MotionPoseLandmarkType.leftHip,
        ) ||
        _torsoSideIsVisible(
          pose,
          shoulder: MotionPoseLandmarkType.rightShoulder,
          hip: MotionPoseLandmarkType.rightHip,
        );
  }

  bool _torsoSideIsVisible(
    MotionPose pose, {
    required MotionPoseLandmarkType shoulder,
    required MotionPoseLandmarkType hip,
  }) {
    return [shoulder, hip].map(pose.landmark).every(_isVisibleInFrame);
  }

  ({double x, double y, double scale})? _assessmentSignature(MotionPose pose) {
    final sides = <({double x, double y, double scale})>[];
    for (final pair in const [
      (MotionPoseLandmarkType.leftShoulder, MotionPoseLandmarkType.leftHip),
      (MotionPoseLandmarkType.rightShoulder, MotionPoseLandmarkType.rightHip),
    ]) {
      final shoulder = pose.landmark(pair.$1);
      final hip = pose.landmark(pair.$2);
      if (!_isVisibleInFrame(shoulder) || !_isVisibleInFrame(hip)) continue;
      final dx = shoulder!.x - hip!.x;
      final dy = shoulder.y - hip.y;
      sides.add((
        x: (shoulder.x + hip.x) / 2,
        y: (shoulder.y + hip.y) / 2,
        scale: math.sqrt(dx * dx + dy * dy),
      ));
    }
    if (sides.isEmpty) return null;
    return (
      x: sides.map((side) => side.x).reduce((a, b) => a + b) / sides.length,
      y: sides.map((side) => side.y).reduce((a, b) => a + b) / sides.length,
      scale:
          sides.map((side) => side.scale).reduce((a, b) => a + b) /
          sides.length,
    );
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
