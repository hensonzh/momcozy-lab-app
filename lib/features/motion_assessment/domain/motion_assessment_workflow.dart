import 'dart:math' as math;

import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

enum MotionAssessmentWorkflowPhase {
  preparing,
  greeting,
  calibrating,
  capturingSegment,
  changingOrientation,
  capturingValidationSegment,
  qualityReview,
  reviewReady,
  awaitingFinishConfirmation,
  finalizing,
  completed,
  failed,
}

enum MotionAssessmentWorkflowAction {
  none,
  requestOrientationChange,
  requestFinishConfirmation,
  continueCapture,
  finalizeCompleted,
  finalizeCancelled,
  rejectConfirmation,
}

class MotionAssessmentWorkflowDecision {
  const MotionAssessmentWorkflowDecision({
    required this.action,
    this.accepted = true,
    this.code = 'accepted',
  });

  final MotionAssessmentWorkflowAction action;
  final bool accepted;
  final String code;
}

class MotionAssessmentWorkflow {
  MotionAssessmentWorkflow({this.requiredSegments = 2})
    : assert(requiredSegments >= 2);

  final int requiredSegments;
  MotionAssessmentWorkflowPhase _phase =
      MotionAssessmentWorkflowPhase.preparing;
  final List<ForwardHeadResult> _segmentResults = <ForwardHeadResult>[];
  final List<Map<String, Object?>> _safetyEvents = <Map<String, Object?>>[];
  String? _finishPromptBaselineAudioItemId;
  final Set<String> _handledConfirmationAudioItemIds = <String>{};
  int _continueCount = 0;

  MotionAssessmentWorkflowPhase get phase => _phase;
  List<ForwardHeadResult> get segmentResults =>
      List<ForwardHeadResult>.unmodifiable(_segmentResults);
  List<Map<String, Object?>> get safetyEvents =>
      List<Map<String, Object?>>.unmodifiable(_safetyEvents);
  int get continueCount => _continueCount;
  bool get isTerminal =>
      _phase == MotionAssessmentWorkflowPhase.completed ||
      _phase == MotionAssessmentWorkflowPhase.failed;

  void beginGreeting() {
    if (_phase == MotionAssessmentWorkflowPhase.preparing) {
      _phase = MotionAssessmentWorkflowPhase.greeting;
    }
  }

  void beginCalibration() {
    if (_phase == MotionAssessmentWorkflowPhase.preparing ||
        _phase == MotionAssessmentWorkflowPhase.greeting) {
      _phase = MotionAssessmentWorkflowPhase.calibrating;
    }
  }

  void beginCapture() {
    if (_phase == MotionAssessmentWorkflowPhase.calibrating ||
        _phase == MotionAssessmentWorkflowPhase.capturingSegment) {
      _phase = MotionAssessmentWorkflowPhase.capturingSegment;
    }
  }

  MotionAssessmentWorkflowDecision completeSegment(ForwardHeadResult result) {
    final isCapturing =
        _phase == MotionAssessmentWorkflowPhase.capturingSegment ||
        _phase == MotionAssessmentWorkflowPhase.capturingValidationSegment;
    if (!isCapturing) return _rejected('capture_not_active');
    _segmentResults.add(result);
    if (_segmentResults.length < requiredSegments) {
      _phase = MotionAssessmentWorkflowPhase.changingOrientation;
      return const MotionAssessmentWorkflowDecision(
        action: MotionAssessmentWorkflowAction.requestOrientationChange,
      );
    }
    _phase = MotionAssessmentWorkflowPhase.qualityReview;
    _phase = MotionAssessmentWorkflowPhase.reviewReady;
    return const MotionAssessmentWorkflowDecision(
      action: MotionAssessmentWorkflowAction.requestFinishConfirmation,
    );
  }

  void orientationInstructionCompleted() {
    if (_phase == MotionAssessmentWorkflowPhase.changingOrientation) {
      _phase = MotionAssessmentWorkflowPhase.capturingValidationSegment;
    }
  }

  void finishPromptCompleted({String? latestUserAudioItemId}) {
    if (_phase != MotionAssessmentWorkflowPhase.reviewReady) return;
    _finishPromptBaselineAudioItemId = latestUserAudioItemId;
    _phase = MotionAssessmentWorkflowPhase.awaitingFinishConfirmation;
  }

  MotionAssessmentWorkflowDecision handleCommand(MotionVoiceCommand command) {
    if (command.type != MotionVoiceCommandType.confirmFinish &&
        command.type != MotionVoiceCommandType.continueAssessment) {
      return _rejected('unsupported_workflow_command');
    }
    final audioItemId = command.userAudioItemId?.trim() ?? '';
    final hasFreshConfirmation =
        _phase == MotionAssessmentWorkflowPhase.awaitingFinishConfirmation &&
        audioItemId.isNotEmpty &&
        audioItemId != _finishPromptBaselineAudioItemId &&
        _handledConfirmationAudioItemIds.add(audioItemId);
    if (!hasFreshConfirmation) return _rejected('confirmation_not_received');

    if (command.type == MotionVoiceCommandType.continueAssessment) {
      _continueCount += 1;
      _segmentResults.clear();
      _finishPromptBaselineAudioItemId = null;
      _phase = MotionAssessmentWorkflowPhase.capturingSegment;
      return const MotionAssessmentWorkflowDecision(
        action: MotionAssessmentWorkflowAction.continueCapture,
      );
    }
    _phase = MotionAssessmentWorkflowPhase.finalizing;
    return const MotionAssessmentWorkflowDecision(
      action: MotionAssessmentWorkflowAction.finalizeCompleted,
    );
  }

  MotionAssessmentWorkflowDecision stopForSafety(String reason) {
    final normalizedReason = reason.trim().isEmpty
        ? 'discomfort'
        : reason.trim();
    _safetyEvents.add(<String, Object?>{'reason': normalizedReason});
    _phase = MotionAssessmentWorkflowPhase.finalizing;
    return const MotionAssessmentWorkflowDecision(
      action: MotionAssessmentWorkflowAction.finalizeCancelled,
    );
  }

  MotionAssessmentWorkflowDecision cancel() {
    if (isTerminal) return _rejected('workflow_already_terminal');
    _phase = MotionAssessmentWorkflowPhase.finalizing;
    return const MotionAssessmentWorkflowDecision(
      action: MotionAssessmentWorkflowAction.finalizeCancelled,
    );
  }

  void markCompleted() => _phase = MotionAssessmentWorkflowPhase.completed;

  void markFailed() => _phase = MotionAssessmentWorkflowPhase.failed;

  ForwardHeadResult? aggregateResult() {
    if (_segmentResults.length < requiredSegments) return null;
    final values = _segmentResults.map((result) => result.valueDegrees).toList()
      ..sort();
    final median = values.length.isOdd
        ? values[values.length ~/ 2]
        : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2;
    final samples = _segmentResults.fold<int>(
      0,
      (total, result) => total + result.sampleCount,
    );
    final duration = _segmentResults.fold<Duration>(
      Duration.zero,
      (total, result) => total + result.sampleDuration,
    );
    final dispersion = _segmentResults
        .map((result) => result.angleDispersionDegrees)
        .reduce(math.max);
    final quality =
        _segmentResults
            .map((result) => result.measurementQualityScore)
            .reduce((a, b) => a + b) /
        _segmentResults.length;
    final sides = _segmentResults.map((result) => result.side).toSet();
    final classification = median < 50
        ? ForwardHeadClassification.forwardTendency
        : ForwardHeadClassification.neutralRange;
    return ForwardHeadResult(
      metric: 'craniovertebral_angle',
      valueDegrees: median,
      classification: classification,
      userMessage: classification == ForwardHeadClassification.forwardTendency
          ? '本次多段采集呈现头部前移倾向，结果将交给主智能体解释。'
          : '本次多段采集处于参考范围，结果将交给主智能体解释。',
      sampleCount: samples,
      sampleDuration: duration,
      side: sides.length == 1 ? sides.single : 'both',
      angleDispersionDegrees: dispersion,
      measurementQualityScore: quality,
    );
  }

  MotionAssessmentWorkflowDecision _rejected(String code) {
    return MotionAssessmentWorkflowDecision(
      action: MotionAssessmentWorkflowAction.rejectConfirmation,
      accepted: false,
      code: code,
    );
  }
}
