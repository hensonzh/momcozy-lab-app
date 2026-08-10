import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_visual_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/frontal_posture_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_finalization.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_capability.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_plan.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_controller.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/presentation/motion_assessment_page.dart';

void main() {
  test(
    'keeps a posture screen in voice selection until a versioned plan is confirmed',
    () async {
      final repository = _FakeRepository(
        immediateSession: _session(target: 'posture_screen'),
      );
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'posture_screen',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: _FakePosePlatform(),
        voice: voice,
      );

      await controller.start();

      expect(controller.phase, MotionAssessmentPagePhase.selectingAssessments);
      expect(controller.assessmentPlan.confirmed, isFalse);
      expect(
        voice.guidanceRequests.first.payload['capabilities'],
        isA<List<Object?>>(),
      );

      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'plan-replace',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.replace,
            targets: [
              MotionAssessmentTarget.forwardHead,
              MotionAssessmentTarget.trunkLateralLean,
            ],
            expectedRevision: 0,
          ),
        ),
      );
      await _flush();

      expect(repository.planUpdates, hasLength(1));
      expect(repository.planUpdates.single.confirmed, isFalse);
      expect(controller.phase, MotionAssessmentPagePhase.selectingAssessments);
      expect(controller.assessmentPlan.revision, 1);

      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'plan-confirm',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.confirm,
            targets: [],
            expectedRevision: 1,
          ),
        ),
      );
      await _flush();

      expect(repository.planUpdates, hasLength(2));
      expect(repository.planUpdates.last.confirmed, isTrue);
      expect(controller.assessmentPlan.confirmed, isTrue);
      expect(controller.phase, MotionAssessmentPagePhase.calibrating);
      expect(
        voice.guidanceRequests.map((request) => request.type),
        contains('assessment_plan_confirmed'),
      );
      await controller.finish();
    },
  );

  test(
    'completes one grouped frontal step for shoulder and trunk screening',
    () async {
      final repository = _FakeRepository(
        immediateSession: _session(target: 'posture_screen'),
      );
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'posture_screen',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        frontalPostureAnalyzer: FrontalPostureAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
        captureCountdown: Duration.zero,
      );

      await controller.start();
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'front-plan',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.replace,
            targets: [
              MotionAssessmentTarget.shoulderHeightAsymmetry,
              MotionAssessmentTarget.trunkLateralLean,
            ],
            expectedRevision: 0,
          ),
        ),
      );
      await _flush();
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'front-confirm',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.confirm,
            targets: [],
            expectedRevision: 1,
          ),
        ),
      );
      await _flush();

      voice.latestAudioItemId = 'before-front-review';
      pose.emit(_acceptedFrontObservation());
      while (controller.phase !=
          MotionAssessmentPagePhase.awaitingFinishConfirmation) {
        await _flush();
      }

      voice.latestAudioItemId = 'finish-front-review';
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.confirmFinish,
          callId: 'finish-front',
          userAudioItemId: 'finish-front-review',
        ),
      );
      while (!controller.exitRequested) {
        await _flush();
      }

      final finalization = repository.finalizations.single;
      expect(finalization.resultSummary['requested_targets'], [
        'shoulder_height_asymmetry',
        'trunk_lateral_lean',
      ]);
      expect(finalization.resultSummary['segment_count'], 1);
      final results = finalization.resultSummary['target_results']! as List;
      expect(
        results.map((item) => (item as Map)['target']),
        containsAll(['shoulder_height_asymmetry', 'trunk_lateral_lean']),
      );
      expect(finalization.processSummary['required_segments'], 1);
    },
  );

  test(
    'announces every transition across two side views and one front view',
    () async {
      final repository = _FakeRepository(
        immediateSession: _session(target: 'posture_screen'),
      );
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'posture_screen',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        forwardHeadAnalyzer: ForwardHeadAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
        frontalPostureAnalyzer: FrontalPostureAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
        captureCountdown: Duration.zero,
      );

      await controller.start();
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'mixed-plan',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.replace,
            targets: [
              MotionAssessmentTarget.forwardHead,
              MotionAssessmentTarget.trunkLateralLean,
            ],
            expectedRevision: 0,
          ),
        ),
      );
      await _flush();
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.updateAssessmentPlan,
          callId: 'mixed-confirm',
          planMutation: MotionAssessmentPlanMutation(
            action: MotionAssessmentPlanAction.confirm,
            targets: [],
            expectedRevision: 1,
          ),
        ),
      );
      await _flush();

      pose.emit(_acceptedSideObservation(side: 'right'));
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'change_orientation',
      )) {
        await _flush();
      }
      pose.emit(
        _acceptedSideObservation(
          side: 'left',
          timestamp: const Duration(seconds: 2),
        ),
      );
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'front_view_required',
      )) {
        await _flush();
      }
      pose.emit(
        _acceptedFrontObservation(timestamp: const Duration(seconds: 3)),
      );
      while (controller.phase !=
          MotionAssessmentPagePhase.awaitingFinishConfirmation) {
        await _flush();
      }

      final transitionTypes = voice.guidanceRequests
          .map((request) => request.type)
          .toList();
      expect(
        transitionTypes,
        containsAllInOrder([
          'assessment_started',
          'assessment_plan_updated',
          'assessment_plan_confirmed',
          'change_orientation',
          'front_view_required',
          'assessment_review_ready',
        ]),
      );
      expect(controller.samplingProgress, 1);
      await controller.finish();
    },
  );

  test(
    'starts local camera before session creation completes and never starts voice after close',
    () async {
      final createCompleter = Completer<MotionAssessmentSession>();
      final repository = _FakeRepository(createCompleter: createCompleter);
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      final start = controller.start();
      while (repository.createCalls == 0) {
        await _flush();
      }
      expect(repository.createCalls, 1);
      expect(pose.startCalls, 1);

      await controller.finish();
      createCompleter.complete(_session());
      await start;

      expect(pose.startCalls, 1);
      expect(voice.connectCalls, 0);
      expect(repository.updatedStatuses, ['cancelled']);
    },
  );

  test(
    'closes the camera when cloud session creation fails because voice is required',
    () async {
      final repository = _FakeRepository(
        createError: StateError('backend unavailable'),
      );
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      await controller.start();

      expect(pose.startCalls, 1);
      expect(controller.exitRequested, isFalse);
      expect(controller.phase, MotionAssessmentPagePhase.failed);
      expect(voice.connectCalls, 0);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'stops a native camera start that completes after the page was closed',
    () async {
      final startCompleter = Completer<void>();
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform(startCompleter: startCompleter);
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
      );

      final start = controller.start();
      while (pose.startCalls == 0) {
        await _flush();
      }
      final finish = controller.finish();
      await _flush();
      startCompleter.complete();
      await Future.wait([start, finish]);

      expect(pose.stopCalls, greaterThanOrEqualTo(2));
      expect(voice.connectCalls, 0);
    },
  );

  test(
    'retries then closes the camera when required realtime voice fails',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice(connectError: StateError('voice unavailable'));
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        voiceRetryDelay: Duration.zero,
      );

      await controller.start();
      await _flush();

      expect(voice.connectCalls, 2);
      expect(controller.exitRequested, isFalse);
      expect(controller.phase, MotionAssessmentPagePhase.failed);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test('drains normal agent audio before opening realtime voice', () async {
    final repository = _FakeRepository(immediateSession: _session());
    final pose = _FakePosePlatform();
    final voice = _FakeVoice();
    var agentAudioDrained = false;
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: pose,
      voice: voice,
      prepareRealtimeAudio: () async {
        agentAudioDrained = true;
      },
    );
    voice.beforeConnect = () {
      expect(agentAudioDrained, isTrue);
    };

    await controller.start();

    expect(voice.connectCalls, 1);
    expect(voice.guidanceRequests.first.type, 'assessment_started');
    expect(voice.guidanceRequests.first.awaitPlaybackCompletion, isTrue);
    await controller.finish();
  });

  test(
    'does not sample pose frames until first Realtime guidance completes',
    () async {
      final firstAudio = Completer<void>();
      final pose = _FakePosePlatform();
      final voice = _FakeVoice()..firstGuidanceCompleter = firstAudio;
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
      );

      final start = controller.start();
      while (voice.guidanceRequests.isEmpty) {
        await _flush();
      }
      pose.emit(_acceptedSideObservation());
      await _flush();
      expect(controller.voiceReady, isFalse);
      expect(voice.latestContext, isNull);

      firstAudio.complete();
      await start;
      pose.emit(_acceptedSideObservation());
      await _flush();
      expect(controller.voiceReady, isTrue);
      expect(voice.latestContext, isNotNull);

      await controller.finish();
    },
  );

  test(
    'starts sampling only after the spoken capture countdown completes',
    () async {
      final countdown = Completer<void>();
      final pose = _FakePosePlatform();
      final voice = _FakeVoice()
        ..guidanceCompleters['capture_countdown'] = countdown;
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        forwardHeadAnalyzer: ForwardHeadAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
      );

      await controller.start();
      pose.emit(_acceptedSideObservation());
      await _flush();

      expect(controller.phase, MotionAssessmentPagePhase.readyCountdown);
      expect(controller.samplingProgress, 0);
      expect(voice.guidanceRequests.last.type, 'capture_countdown');
      expect(voice.guidanceRequests.last.awaitPlaybackCompletion, isTrue);

      countdown.complete();
      await _flush();
      pose.emit(
        _acceptedSideObservation(timestamp: const Duration(seconds: 5)),
      );
      await _flush();

      expect(
        voice.guidanceRequests.map((request) => request.type),
        contains('change_orientation'),
      );
      await controller.finish();
    },
  );

  test(
    'converts live pose changes into Realtime-owned guidance turns',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(
          singlePersonStableFor: Duration.zero,
          multiplePeopleStableFor: Duration.zero,
          personMissingStableFor: Duration.zero,
        ),
      );

      await controller.start();
      await _flush();

      pose.emit(_poseObservation(Duration.zero, const []));
      await _flush();
      pose.emit(_acceptedSideObservation());
      await _flush();
      final tracked = _acceptedSideObservation().poses.single;
      pose.emit(
        _poseObservation(const Duration(seconds: 2), [
          tracked,
          MotionPose(
            centerX: 0.82,
            centerY: tracked.centerY,
            bodyScale: tracked.bodyScale,
            landmarks: tracked.landmarks,
          ),
        ]),
      );
      await _flush();
      await _flush();

      expect(voice.spokenInstructions, isEmpty);
      expect(
        voice.guidanceRequests.map((event) => event.type),
        containsAll([
          'assessment_started',
          'person_not_detected',
          'multiple_people',
        ]),
      );
      expect(
        voice.sentEvents.map((event) => event.type),
        contains('single_person_stable'),
      );
      expect(voice.latestContext?.personCount, 2);
      expect(voice.latestContext?.recommendedAction, 'ask_others_to_leave');

      await controller.finish();
    },
  );

  test(
    'surfaces a native pose model startup failure with a useful cause',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform(
        startError: PlatformException(
          code: 'pose_model_initialization_failed',
          message: 'Unable to open pose model asset',
          details: const {
            'exception': 'java.lang.RuntimeException',
            'build': 42,
            'abis': ['arm64-v8a'],
          },
        ),
      );
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: _FakeVoice(),
      );

      await controller.start();

      expect(controller.phase, MotionAssessmentPagePhase.failed);
      expect(controller.errorMessage, contains('姿态模型加载失败'));
      expect(controller.errorMessage, isNot(contains('网络')));
      expect(controller.poseDiagnosticMessage, contains('Unable to open'));
      expect(controller.poseDiagnosticMessage, contains('RuntimeException'));
      expect(controller.poseDiagnosticMessage, contains('build 42'));
      expect(repository.createCalls, 0);
      expect(pose.stopCalls, 1);

      await controller.finish();
    },
  );

  test('stops the local camera when native pose inference fails', () async {
    final repository = _FakeRepository(immediateSession: _session());
    final pose = _FakePosePlatform();
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: pose,
      voice: _FakeVoice(),
    );

    await controller.start();
    pose.emitError(
      PlatformException(
        code: 'pose_inference_failed',
        message: 'MediaPipe execution failed',
      ),
    );
    await _flush();

    expect(controller.phase, MotionAssessmentPagePhase.failed);
    expect(controller.errorMessage, contains('姿态识别运行异常'));
    expect(pose.stopCalls, 1);

    await controller.finish();
  });

  test(
    'requires two segments and a fresh voice confirmation before durable completion',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        sourceArtifactId: 'artifact-motion-1',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        forwardHeadAnalyzer: ForwardHeadAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
        captureCountdown: Duration.zero,
      );

      await controller.start();
      voice.latestAudioItemId = 'before-review';
      pose.emit(_acceptedSideObservation(side: 'right'));
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'change_orientation',
      )) {
        await _flush();
      }
      expect(controller.exitRequested, isFalse);

      pose.emit(_acceptedSideObservation());
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'assessment_review_ready',
      )) {
        await _flush();
      }
      expect(controller.exitRequested, isFalse);
      expect(
        controller.phase,
        MotionAssessmentPagePhase.awaitingFinishConfirmation,
      );

      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.confirmFinish,
          callId: 'confirm-stale',
          userAudioItemId: 'before-review',
        ),
      );
      await _flush();
      expect(controller.exitRequested, isFalse);

      voice.latestAudioItemId = 'finish-audio';
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.confirmFinish,
          callId: 'confirm-fresh',
          userAudioItemId: 'finish-audio',
        ),
      );
      while (!controller.exitRequested) {
        await _flush();
      }

      expect(repository.createdSourceArtifactIds, ['artifact-motion-1']);
      expect(voice.latestContext?.assessmentId, 'assessment-1');
      expect(voice.latestContext?.samplingState, 'review_ready');

      final completed = repository.finalizations.single;
      expect(completed.outcome, MotionAssessmentOutcome.completed);
      expect(completed.resultSummary['segment_count'], 2);
      expect(completed.resultSummary['sample_count'], 2);
      expect(completed.resultSummary['sample_duration_ms'], 0);
      expect(completed.resultSummary['angle_dispersion_degrees'], 0.0);
      expect(completed.resultSummary['accepted_frame_ratio'], 1.0);
      expect(
        completed.resultSummary['measurement_quality_score'],
        isA<double>(),
      );
      expect(completed.resultSummary['analyzer_version'], isNotEmpty);
      expect(completed.resultSummary['threshold_version'], isNotEmpty);
      expect(
        completed.processSummary['completion_confirmation'],
        'voice_confirmed',
      );
      expect(controller.completedSuccessfully, isTrue);
      expect(controller.completedAssessmentId, 'assessment-1');
      expect(
        voice.guidanceRequests.map((request) => request.type),
        contains('assessment_review_ready'),
      );
    },
  );

  test(
    'safety voice command bypasses finish confirmation and cancels',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
      );

      await controller.start();
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.stopAssessment,
          callId: 'safety-stop',
          reason: 'dizziness',
          userAudioItemId: 'safety-audio',
        ),
      );
      while (!controller.exitRequested) {
        await _flush();
      }

      final finalization = repository.finalizations.single;
      expect(finalization.outcome, MotionAssessmentOutcome.cancelled);
      expect(finalization.safetyEvents, [
        const {'reason': 'dizziness'},
      ]);
      expect(
        finalization.processSummary['completion_confirmation'],
        'not_confirmed',
      );
      expect(controller.completedSuccessfully, isFalse);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'the explicit end action safely cancels an in-progress assessment',
    () async {
      final repository = _FakeRepository(immediateSession: _session());
      final pose = _FakePosePlatform();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: _FakeVoice(),
      );

      await controller.start();
      expect(controller.canEnd, isTrue);

      await controller.finish();

      expect(controller.exitRequested, isTrue);
      expect(controller.canEnd, isFalse);
      expect(
        repository.finalizations.single.outcome,
        MotionAssessmentOutcome.cancelled,
      );
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  test(
    'does not replace an ambiguously staged completion with a failed finalization',
    () async {
      final repository = _FakeRepository(
        immediateSession: _session(),
        stageError: StateError('secure storage acknowledgement failed'),
      );
      final pose = _FakePosePlatform();
      final voice = _FakeVoice();
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: voice,
        qualityGate: MotionQualityGate(singlePersonStableFor: Duration.zero),
        forwardHeadAnalyzer: ForwardHeadAnalyzer(
          minimumStableFor: Duration.zero,
          minimumSamples: 1,
        ),
        captureCountdown: Duration.zero,
      );

      await controller.start();
      pose.emit(_acceptedSideObservation(side: 'right'));
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'change_orientation',
      )) {
        await _flush();
      }
      pose.emit(_acceptedSideObservation());
      while (!voice.guidanceRequests.any(
        (request) => request.type == 'assessment_review_ready',
      )) {
        await _flush();
      }
      voice.latestAudioItemId = 'finish-audio';
      voice.emitCommand(
        const MotionVoiceCommand(
          type: MotionVoiceCommandType.confirmFinish,
          callId: 'confirm-finish',
          userAudioItemId: 'finish-audio',
        ),
      );
      while (controller.phase != MotionAssessmentPagePhase.failed) {
        await _flush();
      }

      expect(repository.stagedFinalizations, hasLength(1));
      expect(
        repository.stagedFinalizations.single.outcome,
        MotionAssessmentOutcome.completed,
      );
      expect(repository.finalizations, isEmpty);
      expect(controller.exitRequested, isFalse);
      expect(pose.stopCalls, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'keeps guidance hands-free while exposing one explicit end control',
    (tester) async {
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: _FakeRepository(immediateSession: _session()),
        posePlatform: _FakePosePlatform(),
        voice: _FakeVoice(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MotionAssessmentPage(
            controllerIdentity: 'voice-fallback',
            controllerFactory: () => controller,
            previewBuilder: (_) => const ColoredBox(color: Colors.black),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(
        find.byKey(const ValueKey('motion-assessment-end')),
        findsOneWidget,
      );
      expect(find.text('结束评估'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('motion-assessment-guidance')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('motion-assessment-voice-status')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'requires an explicit per-session choice before enabling cloud key frames',
    (tester) async {
      final pose = _FakePosePlatform();
      final repository = _FakeRepository(immediateSession: _session());
      final visualContext = MotionVisualContextCoordinator(
        captureKeyFrame: () => throw StateError('not requested in this test'),
      );
      final controller = MotionAssessmentController(
        target: 'forward_head',
        locale: 'zh-CN',
        repository: repository,
        posePlatform: pose,
        voice: _FakeVoice(),
        visualContextCoordinator: visualContext,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MotionAssessmentPage(
            controllerIdentity: 'visual-consent',
            controllerFactory: () => controller,
            previewBuilder: (_) => const ColoredBox(color: Colors.black),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开启视觉辅助吗？'), findsOneWidget);
      expect(find.textContaining('不会上传连续视频'), findsOneWidget);
      expect(pose.startCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('motion-visual-consent-enable')),
      );
      await tester.pumpAndSettle();

      expect(pose.startCalls, 1);
      expect(repository.createdKeyFrameUploadEnabled, [true]);
    },
  );

  testWidgets('local-only consent choice keeps key-frame upload disabled', (
    tester,
  ) async {
    final repository = _FakeRepository(immediateSession: _session());
    final visualContext = MotionVisualContextCoordinator(
      captureKeyFrame: () => throw StateError('must stay local-only'),
    );
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: repository,
      posePlatform: _FakePosePlatform(),
      voice: _FakeVoice(),
      visualContextCoordinator: visualContext,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MotionAssessmentPage(
          controllerIdentity: 'local-only-consent',
          controllerFactory: () => controller,
          visualConsentPrompt: (_) async => false,
          previewBuilder: (_) => const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.createdKeyFrameUploadEnabled, [false]);
    expect(visualContext.isEnabled, isFalse);
  });

  testWidgets('shows retry and exit controls only after terminal failure', (
    tester,
  ) async {
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: _FakeRepository(immediateSession: _session()),
      posePlatform: _FakePosePlatform(
        startError: PlatformException(code: 'pose_model_initialization_failed'),
      ),
      voice: _FakeVoice(),
    );
    await tester.runAsync(controller.start);

    await tester.pumpWidget(
      MaterialApp(
        home: MotionAssessmentPage(
          controllerIdentity: 'failed-overlay',
          controllerFactory: () => controller,
          previewBuilder: (_) => const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pump();

    expect(controller.phase, MotionAssessmentPagePhase.failed);
    expect(
      find.byKey(const ValueKey('motion-assessment-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motion-assessment-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('motion-assessment-exit')),
      findsOneWidget,
    );
  });

  testWidgets('keeps live guidance focused without technical keypoint labels', (
    tester,
  ) async {
    final pose = _FakePosePlatform();
    final controller = MotionAssessmentController(
      target: 'forward_head',
      locale: 'zh-CN',
      repository: _FakeRepository(immediateSession: _session()),
      posePlatform: pose,
      voice: _FakeVoice(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MotionAssessmentPage(
          controllerIdentity: 'pose-overlay',
          controllerFactory: () => controller,
          previewBuilder: (_) => const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('motion-pose-tracking-status')),
      findsNothing,
    );
    expect(pose.startCalls, 1);

    pose.emit(_acceptedSideObservation());
    await tester.pump();
    await tester.pump();
    expect(controller.observation, isNotNull);

    expect(find.byKey(const ValueKey('motion-pose-overlay')), findsOneWidget);
    expect(find.textContaining('个关键点'), findsNothing);
    expect(
      find.byKey(const ValueKey('motion-assessment-guidance')),
      findsNothing,
    );
  });

  testWidgets(
    'replaces and disposes the controller when runtime identity changes',
    (tester) async {
      final firstPose = _FakePosePlatform();
      final secondPose = _FakePosePlatform();

      MotionAssessmentController controllerFor(_FakePosePlatform pose) {
        return MotionAssessmentController(
          target: 'forward_head',
          locale: 'zh-CN',
          repository: _FakeRepository(immediateSession: _session()),
          posePlatform: pose,
          voice: _FakeVoice(),
        );
      }

      var runtimeIdentity = 'runtime-a';
      late StateSetter updateHost;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return MotionAssessmentPage(
                key: const ValueKey('motion-page'),
                controllerIdentity: runtimeIdentity,
                controllerFactory: () => controllerFor(
                  runtimeIdentity == 'runtime-a' ? firstPose : secondPose,
                ),
                previewBuilder: (_) => const ColoredBox(color: Colors.black),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(firstPose.startCalls, 1);

      updateHost(() => runtimeIdentity = 'runtime-b');
      await tester.pump();
      expect(secondPose.startCalls, 1);
      await tester.runAsync(
        () => firstPose.stopCalled.future.timeout(const Duration(seconds: 1)),
      );
      await tester.pump();

      expect(firstPose.stopCalls, greaterThanOrEqualTo(1));
    },
  );
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

MotionAssessmentSession _session({String target = 'forward_head'}) {
  return MotionAssessmentSession(
    id: 'assessment-1',
    target: target,
    status: 'ready',
    poseEngine: 'mediapipe_pose_landmarker',
    videoUploadEnabled: false,
    landmarkUploadEnabled: false,
    pauseReason: '',
    resultSummary: {},
    requestedTargets: target == 'forward_head'
        ? const ['forward_head']
        : const [],
    planConfirmed: target == 'forward_head',
  );
}

class _FakeRepository implements MotionAssessmentRepository {
  _FakeRepository({
    this.createCompleter,
    this.immediateSession,
    this.createError,
    this.stageError,
  });

  final Completer<MotionAssessmentSession>? createCompleter;
  final MotionAssessmentSession? immediateSession;
  final Object? createError;
  final Object? stageError;
  int createCalls = 0;
  final List<String> createdSourceArtifactIds = [];
  final List<bool> createdKeyFrameUploadEnabled = [];
  final List<String> updatedStatuses = [];
  final List<({String status, Map<String, Object?>? resultSummary})> updates =
      [];
  final List<MotionAssessmentFinalization> stagedFinalizations = [];
  final List<MotionAssessmentFinalization> finalizations = [];
  final List<({List<String> targets, int expectedRevision, bool confirmed})>
  planUpdates = [];

  @override
  Future<MotionAssessmentSession> create({
    required String target,
    required String poseEngine,
    String sourceArtifactId = '',
    String locale = 'zh-CN',
    bool keyFrameUploadEnabled = false,
  }) {
    createCalls += 1;
    createdSourceArtifactIds.add(sourceArtifactId);
    createdKeyFrameUploadEnabled.add(keyFrameUploadEnabled);
    final error = createError;
    if (error != null) return Future<MotionAssessmentSession>.error(error);
    return createCompleter?.future ?? Future.value(immediateSession!);
  }

  @override
  Future<MotionAssessmentSession> update({
    required String assessmentId,
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  }) async {
    updatedStatuses.add(status);
    updates.add((status: status, resultSummary: resultSummary));
    return _session();
  }

  @override
  Future<MotionAssessmentSession> updatePlan({
    required String assessmentId,
    required List<String> targets,
    required int expectedRevision,
    required bool confirmed,
  }) async {
    planUpdates.add((
      targets: List.of(targets),
      expectedRevision: expectedRevision,
      confirmed: confirmed,
    ));
    return MotionAssessmentSession(
      id: assessmentId,
      target: 'posture_screen',
      status: 'active',
      poseEngine: 'mediapipe_pose_landmarker',
      videoUploadEnabled: false,
      landmarkUploadEnabled: false,
      pauseReason: '',
      resultSummary: const {},
      requestedTargets: List.of(targets),
      planRevision: expectedRevision + 1,
      planConfirmed: confirmed,
    );
  }

  @override
  Future<void> stageFinalization(
    MotionAssessmentFinalization finalization,
  ) async {
    stagedFinalizations.add(finalization);
    final error = stageError;
    if (error != null) throw error;
  }

  @override
  Future<MotionAssessmentSession> finalize(
    MotionAssessmentFinalization finalization,
  ) async {
    finalizations.add(finalization);
    return _session();
  }

  @override
  Future<void> retryPendingFinalizations() async {}
}

class _FakePosePlatform implements MotionPosePlatform {
  _FakePosePlatform({this.startCompleter, this.startError});

  final Completer<void>? startCompleter;
  final Object? startError;
  final _observations = StreamController<MotionPoseObservation>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  final Completer<void> stopCalled = Completer<void>();

  @override
  String get engineName => 'mediapipe_pose_landmarker';

  @override
  Stream<MotionPoseObservation> get observations => _observations.stream;

  @override
  Future<bool> requestCameraPermission() async => true;

  @override
  Future<void> start() {
    startCalls += 1;
    final error = startError;
    if (error != null) return Future.error(error);
    return startCompleter?.future ?? Future.value();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    if (!stopCalled.isCompleted) stopCalled.complete();
  }

  void emit(MotionPoseObservation observation) =>
      _observations.add(observation);

  void emitError(Object error) => _observations.addError(error);
}

class _FakeVoice extends ChangeNotifier implements MotionRealtimeVoiceClient {
  _FakeVoice({this.connectError});

  final Object? connectError;
  Completer<void>? firstGuidanceCompleter;
  final Map<String, Completer<void>> guidanceCompleters = {};
  VoidCallback? beforeConnect;
  int connectCalls = 0;
  MotionAssessmentContextSnapshot? latestContext;
  final List<String> spokenInstructions = [];
  final List<({String type, Map<String, Object?> payload})> sentEvents = [];
  final List<
    ({
      String type,
      Map<String, Object?> payload,
      bool interrupt,
      bool awaitPlaybackStart,
      bool awaitPlaybackCompletion,
    })
  >
  guidanceRequests = [];
  MotionRealtimeVoicePhase _phase = MotionRealtimeVoicePhase.idle;
  final _commands = StreamController<MotionVoiceCommand>.broadcast();
  String? latestAudioItemId;

  @override
  Stream<MotionVoiceCommand> get commands => _commands.stream;

  @override
  String? get latestCompletedUserAudioItemId => latestAudioItemId;

  @override
  bool get isConnected =>
      _phase == MotionRealtimeVoicePhase.listening ||
      _phase == MotionRealtimeVoicePhase.speaking;

  @override
  bool get hasRemoteAudioTrack => true;

  @override
  String get providerName => 'openai_realtime';

  @override
  String? get failureCode => connectError == null ? null : 'signaling';

  @override
  MotionRealtimeVoicePhase get phase => _phase;

  @override
  Future<void> connect({required String assessmentId}) async {
    connectCalls += 1;
    beforeConnect?.call();
    final error = connectError;
    if (error != null) {
      _phase = MotionRealtimeVoicePhase.failed;
      notifyListeners();
      throw error;
    }
    _phase = MotionRealtimeVoicePhase.listening;
    notifyListeners();
  }

  @override
  Future<void> requestGuidance(
    String eventType,
    Map<String, Object?> payload, {
    bool interrupt = false,
    bool awaitPlaybackStart = false,
    bool awaitPlaybackCompletion = false,
  }) async {
    guidanceRequests.add((
      type: eventType,
      payload: payload,
      interrupt: interrupt,
      awaitPlaybackStart: awaitPlaybackStart,
      awaitPlaybackCompletion: awaitPlaybackCompletion,
    ));
    if (awaitPlaybackStart || awaitPlaybackCompletion) {
      await firstGuidanceCompleter?.future;
      firstGuidanceCompleter = null;
      await guidanceCompleters[eventType]?.future;
    }
  }

  @override
  Future<void> speak(
    String instruction, {
    bool interrupt = false,
    bool exact = false,
  }) async {
    spokenInstructions.add(instruction);
  }

  @override
  Future<void> sendClientEvent(
    String eventType,
    Map<String, Object?> payload,
  ) async {
    sentEvents.add((type: eventType, payload: payload));
  }

  @override
  void updateAssessmentContext(MotionAssessmentContextSnapshot snapshot) {
    latestContext = snapshot;
  }

  @override
  Future<void> completeCommand(
    MotionVoiceCommand command, {
    required bool accepted,
    required String message,
    Map<String, Object?> details = const {},
    bool speakResult = true,
  }) async {}

  @override
  Future<void> close() async {
    _phase = MotionRealtimeVoicePhase.closed;
  }

  void emitCommand(MotionVoiceCommand command) => _commands.add(command);
}

MotionPoseObservation _acceptedSideObservation({
  String side = 'left',
  Duration timestamp = const Duration(seconds: 1),
}) {
  final leftConfidence = side == 'left' ? 0.95 : 0.9;
  final rightConfidence = side == 'right' ? 0.95 : 0.9;
  const reliable = MotionPoseLandmark(
    x: 0.5,
    y: 0.5,
    z: 0,
    visibility: 0.95,
    presence: 0.95,
  );
  return MotionPoseObservation(
    timestamp: timestamp,
    inputWidth: 1000,
    inputHeight: 1000,
    inferenceTime: const Duration(milliseconds: 20),
    poses: [
      MotionPose(
        centerX: 0.5,
        centerY: 0.5,
        bodyScale: 0.8,
        landmarks: {
          MotionPoseLandmarkType.nose: const MotionPoseLandmark(
            x: 0.5,
            y: 0.08,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.leftEar: const MotionPoseLandmark(
            x: 0.7,
            y: 0.35,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
          MotionPoseLandmarkType.rightEar: MotionPoseLandmark(
            x: 0.7,
            y: 0.35,
            z: 0,
            visibility: rightConfidence,
            presence: rightConfidence,
          ),
          MotionPoseLandmarkType.leftShoulder: MotionPoseLandmark(
            x: 0.5,
            y: 0.55,
            z: 0,
            visibility: leftConfidence,
            presence: leftConfidence,
          ),
          MotionPoseLandmarkType.rightShoulder: MotionPoseLandmark(
            x: 0.51,
            y: 0.55,
            z: 0,
            visibility: rightConfidence,
            presence: rightConfidence,
          ),
          MotionPoseLandmarkType.leftHip: MotionPoseLandmark(
            x: 0.5,
            y: 0.7,
            z: 0,
            visibility: leftConfidence,
            presence: leftConfidence,
          ),
          MotionPoseLandmarkType.rightHip: MotionPoseLandmark(
            x: 0.51,
            y: 0.7,
            z: 0,
            visibility: rightConfidence,
            presence: rightConfidence,
          ),
          MotionPoseLandmarkType.leftKnee: reliable,
          MotionPoseLandmarkType.leftAnkle: const MotionPoseLandmark(
            x: 0.5,
            y: 0.92,
            z: 0,
            visibility: 0.95,
            presence: 0.95,
          ),
        },
      ),
    ],
  );
}

MotionPoseObservation _acceptedFrontObservation({
  Duration timestamp = const Duration(seconds: 1),
}) {
  const confidence = 0.95;
  MotionPoseLandmark point(double x, double y) => MotionPoseLandmark(
    x: x,
    y: y,
    z: 0,
    visibility: confidence,
    presence: confidence,
  );
  return MotionPoseObservation(
    timestamp: timestamp,
    inputWidth: 1000,
    inputHeight: 1000,
    inferenceTime: const Duration(milliseconds: 20),
    poses: [
      MotionPose(
        centerX: 0.5,
        centerY: 0.5,
        bodyScale: 0.8,
        landmarks: {
          MotionPoseLandmarkType.nose: point(0.5, 0.12),
          MotionPoseLandmarkType.leftShoulder: point(0.28, 0.43),
          MotionPoseLandmarkType.rightShoulder: point(0.72, 0.50),
          MotionPoseLandmarkType.leftHip: point(0.42, 0.78),
          MotionPoseLandmarkType.rightHip: point(0.58, 0.78),
        },
      ),
    ],
  );
}

MotionPoseObservation _poseObservation(
  Duration timestamp,
  List<MotionPose> poses,
) {
  return MotionPoseObservation(
    timestamp: timestamp,
    inputWidth: 1000,
    inputHeight: 1000,
    inferenceTime: const Duration(milliseconds: 20),
    poses: poses,
  );
}
