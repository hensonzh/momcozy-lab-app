import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_workflow.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

void main() {
  test('two stable segments reach review but never complete automatically', () {
    final workflow = MotionAssessmentWorkflow(requiredSegments: 2)
      ..beginCalibration()
      ..beginCapture();

    final first = workflow.completeSegment(_result(side: 'left', value: 48));
    expect(
      first.action,
      MotionAssessmentWorkflowAction.requestOrientationChange,
    );
    expect(workflow.phase, MotionAssessmentWorkflowPhase.changingOrientation);

    workflow.orientationInstructionCompleted();
    final second = workflow.completeSegment(_result(side: 'right', value: 50));

    expect(
      second.action,
      MotionAssessmentWorkflowAction.requestFinishConfirmation,
    );
    expect(workflow.phase, MotionAssessmentWorkflowPhase.reviewReady);
    expect(workflow.isTerminal, isFalse);
    expect(workflow.aggregateResult()!.valueDegrees, 49);
  });

  test('finish requires prompt playback followed by a new user audio item', () {
    final workflow = _reviewReadyWorkflow();

    final early = workflow.handleCommand(
      const MotionVoiceCommand(
        type: MotionVoiceCommandType.confirmFinish,
        callId: 'early',
        userAudioItemId: 'audio-before-prompt',
      ),
    );
    expect(early.accepted, isFalse);
    expect(early.code, 'confirmation_not_received');

    workflow.finishPromptCompleted(
      latestUserAudioItemId: 'audio-before-prompt',
    );
    final stale = workflow.handleCommand(
      const MotionVoiceCommand(
        type: MotionVoiceCommandType.confirmFinish,
        callId: 'stale',
        userAudioItemId: 'audio-before-prompt',
      ),
    );
    expect(stale.accepted, isFalse);
    expect(
      workflow.phase,
      MotionAssessmentWorkflowPhase.awaitingFinishConfirmation,
    );

    final confirmed = workflow.handleCommand(
      const MotionVoiceCommand(
        type: MotionVoiceCommandType.confirmFinish,
        callId: 'confirmed',
        userAudioItemId: 'audio-after-prompt',
      ),
    );
    expect(confirmed.accepted, isTrue);
    expect(confirmed.action, MotionAssessmentWorkflowAction.finalizeCompleted);
    expect(workflow.phase, MotionAssessmentWorkflowPhase.finalizing);

    final duplicate = workflow.handleCommand(
      const MotionVoiceCommand(
        type: MotionVoiceCommandType.confirmFinish,
        callId: 'duplicate',
        userAudioItemId: 'audio-after-prompt',
      ),
    );
    expect(duplicate.accepted, isFalse);
  });

  test('continue confirmation starts a fresh two-segment capture cycle', () {
    final workflow = _reviewReadyWorkflow();
    workflow.finishPromptCompleted(latestUserAudioItemId: 'audio-before');

    final continued = workflow.handleCommand(
      const MotionVoiceCommand(
        type: MotionVoiceCommandType.continueAssessment,
        callId: 'continue',
        userAudioItemId: 'audio-after',
      ),
    );

    expect(continued.accepted, isTrue);
    expect(continued.action, MotionAssessmentWorkflowAction.continueCapture);
    expect(workflow.phase, MotionAssessmentWorkflowPhase.capturingSegment);
    expect(workflow.segmentResults, isEmpty);
    expect(workflow.continueCount, 1);
  });

  test('a safety stop bypasses the normal finish confirmation handshake', () {
    final workflow = MotionAssessmentWorkflow(requiredSegments: 2)
      ..beginCalibration()
      ..beginCapture();

    final decision = workflow.stopForSafety('dizziness');

    expect(decision.accepted, isTrue);
    expect(decision.action, MotionAssessmentWorkflowAction.finalizeCancelled);
    expect(workflow.phase, MotionAssessmentWorkflowPhase.finalizing);
    expect(workflow.safetyEvents.single['reason'], 'dizziness');
  });
}

MotionAssessmentWorkflow _reviewReadyWorkflow() {
  final workflow = MotionAssessmentWorkflow(requiredSegments: 2)
    ..beginCalibration()
    ..beginCapture();
  workflow.completeSegment(_result(side: 'left', value: 48));
  workflow.orientationInstructionCompleted();
  workflow.completeSegment(_result(side: 'right', value: 50));
  return workflow;
}

ForwardHeadResult _result({required String side, required double value}) {
  return ForwardHeadResult(
    metric: 'craniovertebral_angle',
    valueDegrees: value,
    classification: value < 50
        ? ForwardHeadClassification.forwardTendency
        : ForwardHeadClassification.neutralRange,
    userMessage: 'test',
    sampleCount: 30,
    sampleDuration: const Duration(seconds: 5),
    side: side,
    angleDispersionDegrees: 1,
    measurementQualityScore: 0.9,
  );
}
