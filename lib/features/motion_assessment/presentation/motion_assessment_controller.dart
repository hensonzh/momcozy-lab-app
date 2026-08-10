import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_finalization.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_workflow.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

enum MotionAssessmentPagePhase {
  preparing,
  greeting,
  calibrating,
  readyCountdown,
  capturingSegment,
  changingOrientation,
  capturingValidationSegment,
  qualityReview,
  reviewReady,
  awaitingFinishConfirmation,
  finalizing,
  pausedMultiplePeople,
  targetChanged,
  completed,
  failed,
}

class MotionAssessmentController extends ChangeNotifier {
  MotionAssessmentController({
    required this.target,
    this.sourceArtifactId = '',
    required this.locale,
    required this.repository,
    required this.posePlatform,
    required this.voice,
    this.prepareRealtimeAudio,
    this.voiceRetryDelay = const Duration(milliseconds: 500),
    this.captureCountdown = const Duration(seconds: 3),
    MotionQualityGate? qualityGate,
    ForwardHeadAnalyzer? forwardHeadAnalyzer,
    MotionAssessmentWorkflow? workflow,
  }) : qualityGate = qualityGate ?? MotionQualityGate(),
       forwardHeadAnalyzer = forwardHeadAnalyzer ?? ForwardHeadAnalyzer(),
       workflow = workflow ?? MotionAssessmentWorkflow();

  final String target;
  final String sourceArtifactId;
  final String locale;
  final MotionAssessmentRepository repository;
  final MotionPosePlatform posePlatform;
  final MotionRealtimeVoiceClient voice;
  final Future<void> Function()? prepareRealtimeAudio;
  final Duration voiceRetryDelay;
  final Duration captureCountdown;
  final MotionQualityGate qualityGate;
  final ForwardHeadAnalyzer forwardHeadAnalyzer;
  final MotionAssessmentWorkflow workflow;

  MotionAssessmentPagePhase _phase = MotionAssessmentPagePhase.preparing;
  MotionAssessmentSession? _session;
  MotionPoseObservation? _observation;
  ForwardHeadResult? _forwardHeadResult;
  StreamSubscription<MotionPoseObservation>? _poseSubscription;
  StreamSubscription<MotionVoiceCommand>? _voiceCommandSubscription;
  String _guidance = '正在准备端侧姿态识别…';
  String? _errorMessage;
  String? _poseDiagnosticMessage;
  bool _started = false;
  bool _closed = false;
  bool _disposed = false;
  bool _exitRequested = false;
  bool _cameraStarted = false;
  String? _voiceStatusMessage;
  int _contextSequence = 0;
  int _totalFrames = 0;
  int _acceptedFrames = 0;
  int _multiplePeopleCount = 0;
  int _targetChangedCount = 0;
  int _framingAdjustmentCount = 0;
  bool _sideViewPromptEmitted = false;
  bool _oppositeSidePromptEmitted = false;
  bool _orientationGuidanceCompleted = false;
  bool _captureCountdownInProgress = false;
  int _captureCountdownGeneration = 0;
  Duration? _firstObservationAt;
  Duration? _lastObservationAt;
  MotionAssessmentContextSnapshot? _latestContext;
  MotionQualityDecision? _lastQualityDecision;
  Map<String, Object?>? _latestResultSummary;
  String? _voiceAssessmentId;
  bool _voiceConnectInProgress = false;
  bool _voiceReady = false;
  bool _voiceEverReady = false;
  int _voiceRecoveryCycles = 0;
  bool _terminalizationInProgress = false;
  bool _completedSuccessfully = false;
  String? _completedAssessmentId;

  MotionAssessmentPagePhase get phase => _phase;
  MotionAssessmentSession? get session => _session;
  MotionPoseObservation? get observation => _observation;
  ForwardHeadResult? get forwardHeadResult => _forwardHeadResult;
  String get guidance => _guidance;
  String? get errorMessage => _errorMessage;
  String? get poseDiagnosticMessage => _poseDiagnosticMessage;
  int get personCount => _observation?.poses.length ?? 0;
  MotionRealtimeVoicePhase get voicePhase => voice.phase;
  bool get exitRequested => _exitRequested;
  bool get cameraStarted => _cameraStarted;
  String? get voiceStatusMessage => _voiceStatusMessage;
  String get voiceProviderName => voice.providerName;
  bool get hasRemoteVoiceAudio => voice.hasRemoteAudioTrack;
  bool get voiceReady => _voiceReady;
  bool get completedSuccessfully => _completedSuccessfully;
  String? get completedAssessmentId => _completedAssessmentId;
  bool get canRetry => _phase == MotionAssessmentPagePhase.failed;
  bool get canEnd =>
      _started &&
      !_closed &&
      !_terminalizationInProgress &&
      _phase != MotionAssessmentPagePhase.completed &&
      _phase != MotionAssessmentPagePhase.failed;
  double get samplingProgress {
    if (_forwardHeadResult != null) return 1;
    final completed = workflow.segmentResults.length;
    return ((completed + forwardHeadAnalyzer.samplingProgress) /
            workflow.requiredSegments)
        .clamp(0, 1)
        .toDouble();
  }

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    voice.addListener(_onVoiceChanged);
    _voiceCommandSubscription = voice.commands.listen(
      (command) => unawaited(_handleVoiceCommand(command)),
    );
    _guidance = '正在请求摄像头权限…';
    _notify();
    try {
      final cameraGranted = await posePlatform.requestCameraPermission();
      if (_closed) return;
      if (!cameraGranted) {
        throw StateError('需要摄像头权限才能进行头颈姿态动态评估。');
      }
      _poseSubscription = posePlatform.observations.listen(
        _onObservation,
        onError: _onPoseError,
      );
      _guidance = '正在打开相机并加载端侧姿态识别…';
      _notify();
      await posePlatform.start();
      if (_closed) {
        await _stopPosePlatform();
        return;
      }
      _cameraStarted = true;
      _phase = MotionAssessmentPagePhase.calibrating;
      _guidance = '请让头部、肩部和髋部进入画面';
      _notify();
    } catch (error) {
      await _fail(
        failureCode: 'pose_start_failed',
        message: _friendlyPoseError(error),
        diagnostic: _poseDiagnosticFor(error),
      );
      return;
    }

    late final MotionAssessmentSession createdSession;
    try {
      createdSession = await repository.create(
        target: target,
        poseEngine: posePlatform.engineName,
        sourceArtifactId: sourceArtifactId,
        locale: locale,
      );
    } catch (_) {
      await _fail(
        failureCode: 'session_create_failed',
        message: '实时评估服务暂时不可用，请重试。',
      );
      return;
    }
    if (_closed) {
      await _cancelCreatedSession(createdSession);
      return;
    }
    _session = createdSession;
    await _updateSession(status: 'active');
    workflow.beginGreeting();
    _phase = MotionAssessmentPagePhase.greeting;
    _notify();
    await _connectVoice(createdSession.id);
  }

  Future<bool> _connectVoice(
    String assessmentId, {
    bool recovering = false,
  }) async {
    if (_voiceConnectInProgress || _closed) return _voiceReady;
    _voiceAssessmentId = assessmentId;
    _voiceConnectInProgress = true;
    _voiceReady = false;
    try {
      for (var attempt = 0; attempt < 2 && !_closed; attempt += 1) {
        try {
          if (attempt > 0 && voiceRetryDelay > Duration.zero) {
            await Future<void>.delayed(voiceRetryDelay);
          }
          await prepareRealtimeAudio?.call();
          await voice.connect(assessmentId: assessmentId);
          if (_closed) return false;
          _voiceStatusMessage = null;
          await voice.requestGuidance(
            recovering
                ? 'assessment_resumed_after_reconnect'
                : 'assessment_started',
            _withLatestContext({
              'target': target,
              'required_regions': const ['head', 'shoulders', 'hips'],
              'legs_or_feet_required': false,
              'required_segments': workflow.requiredSegments,
            }),
            awaitPlaybackCompletion: true,
          );
          if (_closed) return false;
          workflow.beginCalibration();
          _phase = MotionAssessmentPagePhase.calibrating;
          _voiceReady = true;
          _voiceEverReady = true;
          _notify();
          return true;
        } catch (_) {
          if (_closed) return false;
          _voiceStatusMessage = attempt == 0
              ? 'OpenAI 实时语音正在重新连接'
              : 'OpenAI 实时语音未连接';
          _notify();
        }
      }
      if (!_closed) {
        await _fail(
          failureCode: 'realtime_unavailable',
          message: 'OpenAI 实时语音暂时无法连接，请重试。',
        );
      }
      return false;
    } finally {
      _voiceConnectInProgress = false;
    }
  }

  void _onObservation(MotionPoseObservation observation) {
    if (_closed || workflow.isTerminal) return;
    _observation = observation;
    if (!_voiceReady) {
      _notify();
      return;
    }
    _firstObservationAt ??= observation.timestamp;
    _lastObservationAt = observation.timestamp;
    _totalFrames += 1;
    final decision = qualityGate.evaluate(observation);
    _lastQualityDecision = decision;
    final captureLifecycle = _isCaptureLifecycle(workflow.phase);

    if (captureLifecycle) {
      switch (decision.phase) {
        case MotionQualityPhase.calibrating:
        case MotionQualityPhase.framing:
        case MotionQualityPhase.reacquiring:
        case MotionQualityPhase.checkingMultiplePeople:
          _phase = MotionAssessmentPagePhase.calibrating;
          _guidance = decision.phase == MotionQualityPhase.framing
              ? '请调整距离，让头部、肩部和髋部进入画面'
              : observation.poses.isEmpty
              ? '请站到镜头前，让头部到髋部入镜'
              : observation.poses.length > 1
              ? '检测到多人，正在确认…'
              : '保持站位，正在校准评估对象…';
        case MotionQualityPhase.ready:
          final targetPose = decision.target;
          if (targetPose != null &&
              (workflow.phase == MotionAssessmentWorkflowPhase.calibrating ||
                  workflow.phase ==
                      MotionAssessmentWorkflowPhase.changingOrientation)) {
            _prepareCaptureReadiness(targetPose, observation);
          } else {
            _syncPagePhaseFromWorkflow();
            _guidance = '请自然侧身，站稳并目视前方';
          }
        case MotionQualityPhase.pausedMultiplePeople:
          _phase = MotionAssessmentPagePhase.pausedMultiplePeople;
          _guidance = '检测到多人，请让非评估人员离开镜头';
        case MotionQualityPhase.targetChanged:
          _phase = MotionAssessmentPagePhase.targetChanged;
          _guidance = '检测对象可能已变化，请通过语音确认后重新校准';
      }
    }

    final directive = decision.directive;
    if (directive != null) _recordDirective(directive);

    ForwardHeadResult? readyResult;
    final samplingActive =
        workflow.phase == MotionAssessmentWorkflowPhase.capturingSegment ||
        workflow.phase ==
            MotionAssessmentWorkflowPhase.capturingValidationSegment;
    if (samplingActive && (!decision.acceptFrame || decision.target == null)) {
      forwardHeadAnalyzer.rejectFrame(at: observation.timestamp);
    } else if (samplingActive && target == 'forward_head') {
      readyResult = forwardHeadAnalyzer.add(
        decision.target!,
        at: observation.timestamp,
        inputWidth: observation.inputWidth,
        inputHeight: observation.inputHeight,
      );
      if (forwardHeadAnalyzer.lastFrameStatus ==
          ForwardHeadFrameStatus.accepted) {
        _acceptedFrames += 1;
      }
      if (readyResult == null &&
          forwardHeadAnalyzer.lastFrameStatus ==
              ForwardHeadFrameStatus.needsSideView) {
        _guidance = '请转为自然侧身，让两侧肩部在画面中尽量重合';
      }
    }

    final snapshot = _buildContextSnapshot(observation, decision);
    _latestContext = snapshot;
    voice.updateAssessmentContext(snapshot);
    if (captureLifecycle &&
        forwardHeadAnalyzer.lastFrameStatus ==
            ForwardHeadFrameStatus.needsSideView &&
        !_sideViewPromptEmitted) {
      _sideViewPromptEmitted = true;
      unawaited(
        voice.requestGuidance('side_view_required', {
          'required_view': 'side',
          'segment_index': workflow.segmentResults.length + 1,
          'dedupe_key':
              'side_view_segment_${workflow.segmentResults.length + 1}',
          'context': snapshot.toJson(),
        }),
      );
    }
    _notify();
    if (directive != null) unawaited(_handleDirective(directive));
    if (readyResult != null) _completeSegment(readyResult);
  }

  bool _isCaptureLifecycle(MotionAssessmentWorkflowPhase phase) {
    return phase == MotionAssessmentWorkflowPhase.calibrating ||
        phase == MotionAssessmentWorkflowPhase.capturingSegment ||
        phase == MotionAssessmentWorkflowPhase.changingOrientation ||
        phase == MotionAssessmentWorkflowPhase.capturingValidationSegment;
  }

  void _prepareCaptureReadiness(
    MotionPose pose,
    MotionPoseObservation observation,
  ) {
    if (_captureCountdownInProgress) return;
    if (workflow.phase == MotionAssessmentWorkflowPhase.changingOrientation &&
        !_orientationGuidanceCompleted) {
      _phase = MotionAssessmentPagePhase.changingOrientation;
      return;
    }
    final inspection = forwardHeadAnalyzer.inspect(
      pose,
      inputWidth: observation.inputWidth,
      inputHeight: observation.inputHeight,
    );
    if (!inspection.accepted) {
      _phase =
          workflow.phase == MotionAssessmentWorkflowPhase.changingOrientation
          ? MotionAssessmentPagePhase.changingOrientation
          : MotionAssessmentPagePhase.calibrating;
      if (inspection.status == ForwardHeadFrameStatus.needsSideView) {
        _guidance = '请自然侧身，站稳并目视前方';
      }
      return;
    }
    final validation =
        workflow.phase == MotionAssessmentWorkflowPhase.changingOrientation;
    final expectedSide = workflow.expectedValidationSide;
    if (validation && expectedSide != null && inspection.side != expectedSide) {
      _phase = MotionAssessmentPagePhase.changingOrientation;
      _guidance = '请转到另一侧，站稳并目视前方';
      _emitOppositeSideRequired(inspection.side);
      return;
    }
    _oppositeSidePromptEmitted = false;
    if (captureCountdown == Duration.zero) {
      _beginCaptureAfterCountdown(validation: validation);
      return;
    }
    _captureCountdownInProgress = true;
    final generation = ++_captureCountdownGeneration;
    _phase = MotionAssessmentPagePhase.readyCountdown;
    _guidance = '准备开始采样';
    _notify();
    unawaited(
      _runCaptureCountdown(
        generation: generation,
        validation: validation,
        expectedSide: expectedSide,
      ),
    );
  }

  Future<void> _runCaptureCountdown({
    required int generation,
    required bool validation,
    required String? expectedSide,
  }) async {
    try {
      await voice.requestGuidance(
        'capture_countdown',
        _withLatestContext({
          'countdown_seconds': captureCountdown.inSeconds,
          'segment_index': workflow.segmentResults.length + 1,
          'expected_side': ?expectedSide,
          'dedupe_key':
              'capture_countdown_${workflow.segmentResults.length + 1}_$generation',
        }),
        interrupt: true,
        awaitPlaybackCompletion: true,
      );
      if (_closed || generation != _captureCountdownGeneration) return;
      if (!_captureReadinessStillValid(
        validation: validation,
        expectedSide: expectedSide,
      )) {
        _captureCountdownInProgress = false;
        _phase = validation
            ? MotionAssessmentPagePhase.changingOrientation
            : MotionAssessmentPagePhase.calibrating;
        _notify();
        return;
      }
      _beginCaptureAfterCountdown(validation: validation);
    } catch (_) {
      if (_closed || generation != _captureCountdownGeneration) return;
      _captureCountdownInProgress = false;
      await _fail(
        failureCode: 'capture_countdown_failed',
        message: '实时语音倒计时中断，请重试。',
      );
    }
  }

  bool _captureReadinessStillValid({
    required bool validation,
    required String? expectedSide,
  }) {
    final decision = _lastQualityDecision;
    final observation = _observation;
    final pose = decision?.target;
    if (decision?.phase != MotionQualityPhase.ready ||
        observation == null ||
        pose == null) {
      return false;
    }
    final inspection = forwardHeadAnalyzer.inspect(
      pose,
      inputWidth: observation.inputWidth,
      inputHeight: observation.inputHeight,
    );
    if (!inspection.accepted) return false;
    return !validation ||
        expectedSide == null ||
        inspection.side == expectedSide;
  }

  void _beginCaptureAfterCountdown({required bool validation}) {
    _captureCountdownInProgress = false;
    if (validation) {
      workflow.orientationInstructionCompleted();
    } else {
      workflow.beginCapture();
    }
    _syncPagePhaseFromWorkflow();
    _guidance = validation ? '正在采集另一侧验证段' : '正在采集，请自然站稳';
    _refreshLatestContext();
    _notify();
  }

  void _emitOppositeSideRequired(String? detectedSide) {
    if (_oppositeSidePromptEmitted) return;
    _oppositeSidePromptEmitted = true;
    unawaited(
      voice.requestGuidance(
        'opposite_side_required',
        _withLatestContext({
          'previous_side': workflow.segmentResults.isEmpty
              ? null
              : workflow.segmentResults.last.side,
          'detected_side': detectedSide ?? 'unknown',
          'expected_side': workflow.expectedValidationSide,
          'segment_index': workflow.segmentResults.length + 1,
          'dedupe_key': 'opposite_side_${workflow.segmentResults.length + 1}',
        }),
        interrupt: true,
      ),
    );
  }

  void _completeSegment(ForwardHeadResult result) {
    final decision = workflow.completeSegment(result);
    _syncPagePhaseFromWorkflow();
    _sideViewPromptEmitted = false;
    _oppositeSidePromptEmitted = false;
    if (decision.action ==
        MotionAssessmentWorkflowAction.requestOrientationChange) {
      forwardHeadAnalyzer.reset();
      _orientationGuidanceCompleted = false;
      _refreshLatestContext();
      _guidance = decision.code == 'opposite_side_required'
          ? '仍是原来的方向，请转到另一侧'
          : '第一段采集完成，正在引导你转换方向';
      _notify();
      final previous = workflow.segmentResults.isEmpty
          ? result
          : workflow.segmentResults.last;
      unawaited(
        _prepareValidationSegment(
          previous,
          oppositeSideRequired: decision.code == 'opposite_side_required',
        ),
      );
      return;
    }
    if (decision.action ==
        MotionAssessmentWorkflowAction.requestFinishConfirmation) {
      final aggregate = workflow.aggregateResult();
      if (aggregate == null) {
        unawaited(
          _fail(failureCode: 'aggregate_unavailable', message: '评估结果整理失败，请重试。'),
        );
        return;
      }
      _forwardHeadResult = aggregate;
      _latestResultSummary = Map<String, Object?>.unmodifiable(
        _forwardHeadSummary(aggregate),
      );
      _refreshLatestContext();
      _guidance = '采集完成，正在复核结果';
      _notify();
      unawaited(_requestFinishConfirmation());
    }
  }

  Future<void> _prepareValidationSegment(
    ForwardHeadResult result, {
    bool oppositeSideRequired = false,
  }) async {
    try {
      await voice.requestGuidance(
        oppositeSideRequired ? 'opposite_side_required' : 'change_orientation',
        _withLatestContext({
          'completed_segment': workflow.segmentResults.length,
          'next_segment': workflow.segmentResults.length + 1,
          'previous_side': result.side,
          'expected_side': workflow.expectedValidationSide,
          'dedupe_key': oppositeSideRequired
              ? 'opposite_side_${workflow.segmentResults.length + 1}'
              : 'change_orientation_${workflow.segmentResults.length}',
        }),
        interrupt: true,
        awaitPlaybackCompletion: true,
      );
      if (_closed) return;
      _orientationGuidanceCompleted = true;
      _syncPagePhaseFromWorkflow();
      _refreshLatestContext();
      _guidance = '请保持另一侧方向，准备开始验证段';
      _notify();
    } catch (_) {
      await _fail(
        failureCode: 'realtime_guidance_failed',
        message: '实时语音指导中断，请重试。',
      );
    }
  }

  Future<void> _requestFinishConfirmation() async {
    _phase = MotionAssessmentPagePhase.reviewReady;
    _notify();
    try {
      await voice.requestGuidance(
        'assessment_review_ready',
        _withLatestContext({
          ...?_latestResultSummary,
          'required_user_decision': const ['finish', 'continue'],
          'dedupe_key': 'assessment_review_ready',
        }),
        interrupt: true,
        awaitPlaybackCompletion: true,
      );
      if (_closed) return;
      workflow.finishPromptCompleted(
        latestUserAudioItemId: voice.latestCompletedUserAudioItemId,
      );
      _syncPagePhaseFromWorkflow();
      _refreshLatestContext();
      _guidance = '请直接说“结束”或“继续评估”';
      _notify();
    } catch (_) {
      await _fail(
        failureCode: 'finish_prompt_failed',
        message: '结束确认语音播放失败，请重试。',
      );
    }
  }

  void _refreshLatestContext() {
    final observation = _observation;
    final decision = _lastQualityDecision;
    if (observation == null || decision == null) return;
    final snapshot = _buildContextSnapshot(observation, decision);
    _latestContext = snapshot;
    voice.updateAssessmentContext(snapshot);
  }

  void _recordDirective(MotionGuidanceDirective directive) {
    switch (directive) {
      case MotionGuidanceDirective.enterFrame:
        break;
      case MotionGuidanceDirective.adjustFraming:
        _framingAdjustmentCount += 1;
      case MotionGuidanceDirective.askOthersToLeave:
        _multiplePeopleCount += 1;
      case MotionGuidanceDirective.confirmRecalibration:
        _targetChangedCount += 1;
      case MotionGuidanceDirective.singlePersonReady:
      case MotionGuidanceDirective.assessmentResumed:
        break;
    }
  }

  MotionAssessmentContextSnapshot _buildContextSnapshot(
    MotionPoseObservation observation,
    MotionQualityDecision decision,
  ) {
    final personCount = observation.poses.length;
    final assessmentRegionVisible =
        personCount == 1 && decision.phase != MotionQualityPhase.framing;
    final frameStatus = forwardHeadAnalyzer.lastFrameStatus;
    final result = _forwardHeadResult;
    final missingRegions = <String>[
      if (personCount == 0) 'person',
      if (personCount == 1 && decision.phase == MotionQualityPhase.framing)
        ..._missingAssessmentRegions(observation.poses.single),
    ];
    final rejectionReasons = <String>[
      if (personCount == 0) 'no_person',
      if (personCount > 1) 'multiple_people',
      if (decision.phase == MotionQualityPhase.framing) 'incomplete_framing',
      if (decision.phase == MotionQualityPhase.targetChanged) 'target_changed',
      if (frameStatus == ForwardHeadFrameStatus.needsSideView)
        'side_view_required',
      if (frameStatus == ForwardHeadFrameStatus.insufficientLandmarks &&
          decision.acceptFrame)
        'insufficient_landmark_confidence',
      if (frameStatus == ForwardHeadFrameStatus.invalidFrameSize)
        'invalid_frame_size',
    ];
    final detectedView =
        result != null ||
            (frameStatus == ForwardHeadFrameStatus.accepted &&
                forwardHeadAnalyzer.sampleCount > 0)
        ? 'side'
        : frameStatus == ForwardHeadFrameStatus.needsSideView
        ? 'front_or_oblique'
        : 'unknown';
    final samplingState = result != null
        ? 'review_ready'
        : rejectionReasons.isNotEmpty
        ? 'blocked'
        : decision.acceptFrame &&
              (workflow.phase ==
                      MotionAssessmentWorkflowPhase.capturingSegment ||
                  workflow.phase ==
                      MotionAssessmentWorkflowPhase.capturingValidationSegment)
        ? 'collecting'
        : 'calibrating';
    final recommended = _recommendedAction(
      decision: decision,
      frameStatus: frameStatus,
      resultReady: result != null,
      personCount: personCount,
    );
    final startedAt = _firstObservationAt ?? observation.timestamp;
    return MotionAssessmentContextSnapshot(
      assessmentId: _session?.id ?? '',
      sequence: ++_contextSequence,
      observedAtMs: observation.timestamp.inMilliseconds,
      target: target,
      phase: _workflowPhaseValue(workflow.phase),
      elapsedMs: (observation.timestamp - startedAt).inMilliseconds
          .clamp(0, 1 << 31)
          .toInt(),
      personCount: personCount,
      targetLocked:
          decision.target != null || decision.phase == MotionQualityPhase.ready,
      continuity: _continuityValue(decision.phase),
      assessmentRegionVisible: assessmentRegionVisible,
      missingRegions: missingRegions,
      distance: assessmentRegionVisible
          ? 'acceptable'
          : decision.phase == MotionQualityPhase.framing
          ? 'too_close_or_cropped'
          : 'unknown',
      requiredView: 'side',
      detectedView: detectedView,
      detectedSide:
          result?.side ?? forwardHeadAnalyzer.dominantSide ?? 'unknown',
      alignmentQuality: detectedView == 'side'
          ? 'accepted'
          : frameStatus == ForwardHeadFrameStatus.needsSideView
          ? 'adjustment_required'
          : 'unknown',
      samplingState: samplingState,
      validSamples: result?.sampleCount ?? forwardHeadAnalyzer.sampleCount,
      requiredSamples: forwardHeadAnalyzer.minimumSamples,
      stableDurationMs:
          result?.sampleDuration.inMilliseconds ??
          forwardHeadAnalyzer.stableDuration.inMilliseconds,
      requiredDurationMs: forwardHeadAnalyzer.minimumStableFor.inMilliseconds,
      samplingProgress: samplingProgress,
      rejectionReasons: rejectionReasons,
      measurementStatus: result != null
          ? 'aggregate_ready'
          : forwardHeadAnalyzer.sampleCount > 0
          ? 'provisional'
          : 'unavailable',
      metric: 'craniovertebral_angle',
      rollingMedian:
          result?.valueDegrees ?? forwardHeadAnalyzer.rollingMedianDegrees,
      dispersion:
          result?.angleDispersionDegrees ??
          forwardHeadAnalyzer.angleDispersionDegrees,
      unit: 'degrees',
      measurementQualityScore: result?.measurementQualityScore,
      multiplePeople: personCount > 1,
      targetChanged: decision.phase == MotionQualityPhase.targetChanged,
      discomfortReported: workflow.safetyEvents.isNotEmpty,
      recommendedAction: recommended.action,
      guidanceReason: recommended.reason,
    );
  }

  List<String> _missingAssessmentRegions(MotionPose pose) {
    bool unavailable(MotionPoseLandmarkType type) {
      final landmark = pose.landmark(type);
      return landmark == null ||
          !landmark.isReliable(minimumConfidence: 0.45) ||
          landmark.x < 0.02 ||
          landmark.x > 0.98 ||
          landmark.y < 0.02 ||
          landmark.y > 0.98;
    }

    return <String>[
      if (unavailable(MotionPoseLandmarkType.nose) &&
          unavailable(MotionPoseLandmarkType.leftEar) &&
          unavailable(MotionPoseLandmarkType.rightEar))
        'head',
      if (unavailable(MotionPoseLandmarkType.leftShoulder) &&
          unavailable(MotionPoseLandmarkType.rightShoulder))
        'shoulders',
      if (unavailable(MotionPoseLandmarkType.leftHip) &&
          unavailable(MotionPoseLandmarkType.rightHip))
        'hips',
    ];
  }

  ({String action, String reason}) _recommendedAction({
    required MotionQualityDecision decision,
    required ForwardHeadFrameStatus frameStatus,
    required bool resultReady,
    required int personCount,
  }) {
    if (resultReady) {
      return (
        action: 'await_finish_confirmation',
        reason: 'aggregate_review_ready',
      );
    }
    if (personCount > 1) {
      return (action: 'ask_others_to_leave', reason: 'multiple_people');
    }
    if (personCount == 0) {
      return (action: 'enter_frame', reason: 'no_person');
    }
    if (decision.phase == MotionQualityPhase.targetChanged) {
      return (action: 'confirm_recalibration', reason: 'target_changed');
    }
    if (decision.phase == MotionQualityPhase.framing) {
      return (
        action: 'adjust_framing',
        reason: 'assessment_region_not_visible',
      );
    }
    if (frameStatus == ForwardHeadFrameStatus.needsSideView) {
      return (action: 'turn_sideways', reason: 'side_view_required');
    }
    if (decision.acceptFrame) {
      return (action: 'hold_still', reason: 'stable_samples_needed');
    }
    return (action: 'hold_position', reason: 'quality_gate_calibrating');
  }

  String _workflowPhaseValue(MotionAssessmentWorkflowPhase value) {
    return switch (value) {
      MotionAssessmentWorkflowPhase.preparing => 'preparing',
      MotionAssessmentWorkflowPhase.greeting => 'greeting',
      MotionAssessmentWorkflowPhase.calibrating => 'calibrating',
      MotionAssessmentWorkflowPhase.capturingSegment => 'capturing_segment',
      MotionAssessmentWorkflowPhase.changingOrientation =>
        'changing_orientation',
      MotionAssessmentWorkflowPhase.capturingValidationSegment =>
        'capturing_validation_segment',
      MotionAssessmentWorkflowPhase.qualityReview => 'quality_review',
      MotionAssessmentWorkflowPhase.reviewReady => 'review_ready',
      MotionAssessmentWorkflowPhase.awaitingFinishConfirmation =>
        'awaiting_finish_confirmation',
      MotionAssessmentWorkflowPhase.finalizing => 'finalizing',
      MotionAssessmentWorkflowPhase.completed => 'completed',
      MotionAssessmentWorkflowPhase.failed => 'failed',
    };
  }

  String _continuityValue(MotionQualityPhase value) {
    return switch (value) {
      MotionQualityPhase.ready => 'continuous',
      MotionQualityPhase.reacquiring => 'reacquiring',
      MotionQualityPhase.targetChanged => 'target_changed',
      MotionQualityPhase.checkingMultiplePeople ||
      MotionQualityPhase.pausedMultiplePeople => 'interrupted_multiple_people',
      MotionQualityPhase.calibrating ||
      MotionQualityPhase.framing => 'calibrating',
    };
  }

  Map<String, Object?> _withLatestContext(Map<String, Object?> payload) {
    final context = _latestContext;
    return {...payload, if (context != null) 'context': context.toJson()};
  }

  Future<void> _handleDirective(MotionGuidanceDirective directive) async {
    if (_closed) return;
    switch (directive) {
      case MotionGuidanceDirective.enterFrame:
        await voice.requestGuidance(
          'person_not_detected',
          _withLatestContext({
            'person_count': 0,
            'accept_pose_frames': false,
            'dedupe_key': 'person_not_detected',
          }),
        );
      case MotionGuidanceDirective.adjustFraming:
        await voice.requestGuidance(
          'framing_incomplete',
          _withLatestContext({
            'person_count': 1,
            'accept_pose_frames': false,
            'dedupe_key': 'framing_incomplete',
          }),
        );
      case MotionGuidanceDirective.singlePersonReady:
        await voice.sendClientEvent(
          'single_person_stable',
          _withLatestContext({
            'person_count': 1,
            'target': target,
            'requires_voice_response': false,
            'dedupe_key': 'single_person_stable',
          }),
        );
      case MotionGuidanceDirective.askOthersToLeave:
        await _updateSession(status: 'paused', pauseReason: 'multiple_people');
        await voice.requestGuidance(
          'multiple_people',
          _withLatestContext({
            'person_count': personCount,
            'accept_pose_frames': false,
            'dedupe_key': 'multiple_people',
          }),
          interrupt: true,
        );
      case MotionGuidanceDirective.assessmentResumed:
        await _updateSession(status: 'active');
        await voice.requestGuidance(
          'single_person_stable',
          _withLatestContext({
            'person_count': 1,
            'resumed': true,
            'dedupe_key': 'assessment_resumed',
          }),
        );
      case MotionGuidanceDirective.confirmRecalibration:
        await _updateSession(status: 'paused', pauseReason: 'target_changed');
        await voice.requestGuidance(
          'target_changed',
          _withLatestContext({
            'accept_pose_frames': false,
            'dedupe_key': 'target_changed',
          }),
          interrupt: true,
        );
    }
  }

  Future<void> confirmRecalibration() async {
    qualityGate.confirmRecalibration();
    forwardHeadAnalyzer.reset();
    _forwardHeadResult = null;
    _latestResultSummary = null;
    _sideViewPromptEmitted = false;
    _oppositeSidePromptEmitted = false;
    _captureCountdownGeneration += 1;
    _captureCountdownInProgress = false;
    _syncPagePhaseFromWorkflow();
    _guidance = '请保持单人入镜，正在重新校准…';
    _notify();
    await _updateSession(status: 'active');
  }

  Future<void> _handleVoiceCommand(MotionVoiceCommand command) async {
    if (_closed) return;
    switch (command.type) {
      case MotionVoiceCommandType.confirmRecalibration:
        if (_phase != MotionAssessmentPagePhase.targetChanged) {
          await _rejectCommand(command, 'recalibration_not_required');
          return;
        }
        await confirmRecalibration();
        await voice.completeCommand(
          command,
          accepted: true,
          message: 'recalibration_confirmed',
          speakResult: false,
        );
        await voice.requestGuidance(
          'recalibration_confirmed',
          _withLatestContext({'accepted': true}),
        );
      case MotionVoiceCommandType.repeatInstruction:
        await voice.completeCommand(
          command,
          accepted: true,
          message: 'repeat_requested',
          speakResult: false,
        );
        await voice.requestGuidance(
          'repeat_instruction',
          _withLatestContext({'requested': true}),
        );
      case MotionVoiceCommandType.stopAssessment:
        await voice.completeCommand(
          command,
          accepted: true,
          message: 'assessment_stopping',
          speakResult: false,
        );
        final reason = command.reason ?? 'user_requested';
        if (_isSafetyReason(reason)) {
          workflow.stopForSafety(reason);
          _syncPagePhaseFromWorkflow();
          try {
            await voice.requestGuidance(
              'safety_stop',
              _withLatestContext({
                'reason': reason,
                'requires_voice_response': true,
              }),
              interrupt: true,
              awaitPlaybackCompletion: true,
            );
          } catch (_) {
            // Safety teardown must not depend on a final audio acknowledgement.
          }
        } else {
          workflow.cancel();
        }
        await _finalizeCancelled();
      case MotionVoiceCommandType.continueAssessment:
      case MotionVoiceCommandType.confirmFinish:
        final decision = workflow.handleCommand(command);
        if (!decision.accepted) {
          await _rejectCommand(command, decision.code);
          return;
        }
        await voice.completeCommand(
          command,
          accepted: true,
          message:
              decision.action == MotionAssessmentWorkflowAction.continueCapture
              ? 'assessment_continuing'
              : 'finish_confirmed',
          speakResult: false,
        );
        if (decision.action == MotionAssessmentWorkflowAction.continueCapture) {
          _resetCaptureCycle();
          await voice.requestGuidance(
            'assessment_continued',
            _withLatestContext({
              'continue_count': workflow.continueCount,
              'dedupe_key': 'continue_${workflow.continueCount}',
            }),
            awaitPlaybackStart: true,
          );
          return;
        }
        await _finalizeCompleted();
    }
  }

  Future<void> _rejectCommand(MotionVoiceCommand command, String reason) async {
    await voice.completeCommand(
      command,
      accepted: false,
      message: reason,
      speakResult: false,
    );
    await voice.requestGuidance(
      'command_rejected',
      _withLatestContext({'reason': reason, 'accepted': false}),
    );
  }

  bool _isSafetyReason(String reason) {
    return const {
      'discomfort',
      'pain',
      'dizziness',
      'numbness',
      'breathing_difficulty',
    }.contains(reason);
  }

  void _resetCaptureCycle() {
    forwardHeadAnalyzer.reset();
    _forwardHeadResult = null;
    _latestResultSummary = null;
    _sideViewPromptEmitted = false;
    _oppositeSidePromptEmitted = false;
    _captureCountdownGeneration += 1;
    _captureCountdownInProgress = false;
    _syncPagePhaseFromWorkflow();
    _refreshLatestContext();
    _guidance = '继续评估，请自然侧身并保持稳定';
    _notify();
  }

  Map<String, Object?> _forwardHeadSummary(ForwardHeadResult result) {
    final acceptedFrameRatio = _totalFrames == 0
        ? 0.0
        : _acceptedFrames / _totalFrames;
    final measurementQualityScore =
        (result.measurementQualityScore * 0.85 + acceptedFrameRatio * 0.15)
            .clamp(0, 1)
            .toDouble();
    return <String, Object?>{
      'metric': result.metric,
      'value': double.parse(result.valueDegrees.toStringAsFixed(1)),
      'unit': 'degrees',
      'classification': _classificationValue(result.classification),
      'sample_count': result.sampleCount,
      'sample_duration_ms': result.sampleDuration.inMilliseconds,
      'segment_count': workflow.segmentResults.length,
      'segments': workflow.segmentResults
          .asMap()
          .entries
          .map((entry) => _segmentSummary(entry.key + 1, entry.value))
          .toList(growable: false),
      'side': result.side,
      'frame_quality': 'accepted',
      'angle_dispersion_degrees': double.parse(
        result.angleDispersionDegrees.toStringAsFixed(2),
      ),
      'accepted_frame_ratio': double.parse(
        acceptedFrameRatio.toStringAsFixed(3),
      ),
      'measurement_quality_score': double.parse(
        measurementQualityScore.toStringAsFixed(3),
      ),
      'pose_model_version':
          posePlatform.engineName == 'mediapipe_pose_landmarker'
          ? 'pose_landmarker_lite.task'
          : 'vision_human_body_pose',
      'analyzer_version': forwardHeadAnalyzerVersion,
      'threshold_version': forwardHeadThresholdVersion,
    };
  }

  Map<String, Object?> _segmentSummary(int index, ForwardHeadResult result) {
    return <String, Object?>{
      'index': index,
      'value': double.parse(result.valueDegrees.toStringAsFixed(1)),
      'unit': 'degrees',
      'classification': _classificationValue(result.classification),
      'sample_count': result.sampleCount,
      'sample_duration_ms': result.sampleDuration.inMilliseconds,
      'side': result.side,
      'angle_dispersion_degrees': double.parse(
        result.angleDispersionDegrees.toStringAsFixed(2),
      ),
      'measurement_quality_score': double.parse(
        result.measurementQualityScore.toStringAsFixed(3),
      ),
    };
  }

  Map<String, Object?> _processSummary({required bool finishConfirmed}) {
    final first = _firstObservationAt;
    final last = _lastObservationAt;
    final elapsed = first == null || last == null
        ? 0
        : (last - first).inMilliseconds.clamp(0, 1 << 31).toInt();
    return <String, Object?>{
      'duration_ms': elapsed,
      'total_frames': _totalFrames,
      'accepted_frames': _acceptedFrames,
      'segment_count': workflow.segmentResults.length,
      'required_segments': workflow.requiredSegments,
      'completed_segments': workflow.segmentResults.length,
      'continue_count': workflow.continueCount,
      'retry_count': _voiceRecoveryCycles,
      'interruption_count':
          _multiplePeopleCount + _targetChangedCount + _framingAdjustmentCount,
      'multiple_people_count': _multiplePeopleCount,
      'target_changed_count': _targetChangedCount,
      'framing_adjustment_count': _framingAdjustmentCount,
      'completion_confirmation': finishConfirmed
          ? 'voice_confirmed'
          : 'not_confirmed',
      'voice_provider': voice.providerName,
      'voice_connected': _voiceEverReady,
    };
  }

  Future<void> _finalizeCompleted() async {
    if (_terminalizationInProgress || _closed) return;
    _terminalizationInProgress = true;
    _phase = MotionAssessmentPagePhase.finalizing;
    _guidance = '正在保存评估结果';
    _notify();
    try {
      await voice.requestGuidance(
        'assessment_finalizing',
        _withLatestContext({
          'finish_confirmed': true,
          'dedupe_key': 'assessment_finalizing',
        }),
        awaitPlaybackCompletion: true,
      );
    } catch (_) {
      // The fresh user confirmation is authoritative even if farewell audio is
      // interrupted after it.
    }
    final session = _session;
    final summary = _latestResultSummary;
    if (session == null || summary == null) {
      _terminalizationInProgress = false;
      await _fail(
        failureCode: 'completion_payload_missing',
        message: '评估结果保存失败，请重试。',
      );
      return;
    }
    final finalization = MotionAssessmentFinalization(
      finalizationId: 'finalization-${session.id}-v1',
      assessmentId: session.id,
      outcome: MotionAssessmentOutcome.completed,
      resultSummary: summary,
      processSummary: _processSummary(finishConfirmed: true),
      safetyEvents: workflow.safetyEvents,
      clientRevision: 1,
    );
    try {
      await repository.stageFinalization(finalization);
    } catch (_) {
      _terminalizationInProgress = false;
      await _fail(
        failureCode: 'finalization_storage_failed',
        message: '评估结果暂时无法安全保存，请重试。',
        persistFinalization: false,
      );
      return;
    }
    await _closeResources();
    try {
      _session = await repository.finalize(finalization);
    } catch (_) {
      // The durable payload is retried on launch/resume.
    }
    workflow.markCompleted();
    _phase = MotionAssessmentPagePhase.completed;
    _completedSuccessfully = true;
    _completedAssessmentId = session.id;
    _exitRequested = true;
    _terminalizationInProgress = false;
    _notify();
  }

  Future<void> _finalizeCancelled() async {
    if (_terminalizationInProgress || _closed) return;
    _terminalizationInProgress = true;
    _phase = MotionAssessmentPagePhase.finalizing;
    _notify();
    final session = _session;
    MotionAssessmentFinalization? finalization;
    if (session != null) {
      finalization = MotionAssessmentFinalization(
        finalizationId: 'finalization-${session.id}-v1',
        assessmentId: session.id,
        outcome: MotionAssessmentOutcome.cancelled,
        resultSummary: _latestResultSummary ?? const <String, Object?>{},
        processSummary: _processSummary(finishConfirmed: false),
        safetyEvents: workflow.safetyEvents,
        clientRevision: 1,
      );
      try {
        await repository.stageFinalization(finalization);
      } catch (_) {
        // Cancellation still tears down private camera and microphone data.
      }
    }
    await _closeResources();
    if (finalization != null) {
      try {
        _session = await repository.finalize(finalization);
      } catch (_) {
        // A successfully staged cancellation is retried later.
      }
    }
    workflow.markCompleted();
    _phase = MotionAssessmentPagePhase.completed;
    _exitRequested = true;
    _terminalizationInProgress = false;
    _notify();
  }

  Future<void> finish({bool completed = false}) async {
    if (_closed || _terminalizationInProgress) return;
    if (completed && _latestResultSummary != null) {
      await _finalizeCompleted();
      return;
    }
    workflow.cancel();
    await _finalizeCancelled();
  }

  Future<void> exitAfterFailure() async {
    if (_phase != MotionAssessmentPagePhase.failed) return;
    _exitRequested = true;
    _notify();
  }

  Future<void> _fail({
    required String failureCode,
    required String message,
    String? diagnostic,
    bool persistFinalization = true,
  }) async {
    if (_phase == MotionAssessmentPagePhase.failed ||
        _phase == MotionAssessmentPagePhase.completed ||
        _terminalizationInProgress) {
      return;
    }
    _terminalizationInProgress = true;
    _errorMessage = message;
    _poseDiagnosticMessage = diagnostic;
    _guidance = message;
    final session = _session;
    MotionAssessmentFinalization? finalization;
    if (session != null && persistFinalization) {
      finalization = MotionAssessmentFinalization(
        finalizationId: 'finalization-${session.id}-v1',
        assessmentId: session.id,
        outcome: MotionAssessmentOutcome.failed,
        resultSummary: _latestResultSummary ?? const <String, Object?>{},
        processSummary: _processSummary(finishConfirmed: false),
        safetyEvents: workflow.safetyEvents,
        clientRevision: 1,
        failureCode: failureCode,
      );
      try {
        await repository.stageFinalization(finalization);
      } catch (_) {
        // Teardown and the visible error state are still mandatory.
      }
    }
    await _closeResources();
    if (finalization != null) {
      try {
        _session = await repository.finalize(finalization);
      } catch (_) {
        // A staged failure remains available for a later retry.
      }
    }
    workflow.markFailed();
    _phase = MotionAssessmentPagePhase.failed;
    _terminalizationInProgress = false;
    _notify();
  }

  Future<void> _closeResources() async {
    if (_closed) return;
    _closed = true;
    _cameraStarted = false;
    _voiceReady = false;
    final poseStop = _stopPosePlatform();
    final voiceStop = voice.close();
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await _voiceCommandSubscription?.cancel();
    _voiceCommandSubscription = null;
    await poseStop;
    await voiceStop;
  }

  Future<void> _stopPosePlatform() async {
    try {
      await posePlatform.stop();
    } catch (_) {
      // Native camera teardown is best effort during navigation.
    }
  }

  Future<void> _updateSession({
    required String status,
    String pauseReason = '',
    Map<String, Object?>? resultSummary,
  }) async {
    final session = _session;
    if (session == null || _closed) return;
    try {
      final updated = await repository.update(
        assessmentId: session.id,
        status: status,
        pauseReason: pauseReason,
        resultSummary: resultSummary,
      );
      if (!_closed) _session = updated;
    } catch (_) {
      // Camera quality gating remains local even when status telemetry is down.
    }
  }

  void _onVoiceChanged() {
    if (_closed) return;
    if (voice.isConnected) {
      _voiceStatusMessage = null;
      if (_voiceEverReady && !_voiceConnectInProgress) _voiceReady = true;
    } else if (voice.phase == MotionRealtimeVoicePhase.reconnecting) {
      _voiceReady = false;
      _voiceStatusMessage = 'OpenAI 实时语音正在重新连接';
    } else if (voice.phase == MotionRealtimeVoicePhase.failed) {
      _voiceReady = false;
      _voiceStatusMessage = 'OpenAI 实时语音未连接';
      final assessmentId = _voiceAssessmentId;
      if (!_voiceConnectInProgress &&
          !_terminalizationInProgress &&
          _voiceRecoveryCycles < 1 &&
          assessmentId != null) {
        _voiceRecoveryCycles += 1;
        unawaited(_connectVoice(assessmentId, recovering: true));
      } else if (!_voiceConnectInProgress && !_terminalizationInProgress) {
        unawaited(
          _fail(
            failureCode: voice.failureCode ?? 'realtime_connection_lost',
            message: 'OpenAI 实时语音连接已中断，请重试。',
          ),
        );
      }
    }
    _notify();
  }

  void _onPoseError(Object error, StackTrace _) {
    if (_closed) return;
    debugPrint('Motion pose stream failed: $error');
    unawaited(
      _fail(
        failureCode: 'pose_stream_failed',
        message: _friendlyPoseError(error),
        diagnostic: _poseDiagnosticFor(error),
      ),
    );
  }

  String _friendlyPoseError(Object error) {
    if (error case PlatformException(code: final code)) {
      return switch (code) {
        'pose_model_initialization_failed' => '端侧姿态模型加载失败，请重试。',
        'pose_inference_failed' => '端侧姿态识别运行异常，请重试。',
        'pose_start_timeout' => '端侧姿态模型启动超时，请重试。',
        'pose_event_stream_closed' => '端侧姿态识别连接中断，请重试。',
        'camera_start_cancelled' => '端侧姿态识别启动已取消。',
        'camera_start_failed' => '前置摄像头启动失败，请检查相机是否被其他应用占用。',
        'permission_denied' => '请允许摄像头权限后重试。',
        _ => '端侧姿态识别暂时不可用，请重试。',
      };
    }
    if (error is MissingPluginException) {
      return '当前安装版本未包含端侧姿态识别组件，请更新 App 后重试。';
    }
    if (error.toString().contains('摄像头权限')) {
      return '请允许摄像头权限后重试。';
    }
    return '端侧姿态识别暂时不可用，请重试。';
  }

  String? _poseDiagnosticFor(Object error) {
    if (error is! PlatformException) return null;
    final parts = <String>[error.code];
    final message = _compactDiagnosticValue(error.message);
    if (message != null) parts.add(message);
    final details = error.details;
    if (details is Map) {
      final exception = _compactDiagnosticValue(details['exception']);
      if (exception != null) parts.add(exception);
      final build = _compactDiagnosticValue(details['build']);
      if (build != null) parts.add('build $build');
      final abis = details['abis'];
      if (abis is Iterable) {
        final abiText = _compactDiagnosticValue(abis.join(', '));
        if (abiText != null) parts.add('ABI $abiText');
      }
    }
    return parts.join(' · ');
  }

  String? _compactDiagnosticValue(Object? value) {
    if (value == null) return null;
    final compact = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return null;
    const maxLength = 160;
    return compact.length <= maxLength
        ? compact
        : '${compact.substring(0, maxLength - 1)}…';
  }

  Future<void> _cancelCreatedSession(
    MotionAssessmentSession createdSession,
  ) async {
    try {
      await repository.update(
        assessmentId: createdSession.id,
        status: 'cancelled',
      );
    } catch (_) {
      // A page closed during creation must not restart local resources.
    }
  }

  void _syncPagePhaseFromWorkflow() {
    _phase = switch (workflow.phase) {
      MotionAssessmentWorkflowPhase.preparing =>
        MotionAssessmentPagePhase.preparing,
      MotionAssessmentWorkflowPhase.greeting =>
        MotionAssessmentPagePhase.greeting,
      MotionAssessmentWorkflowPhase.calibrating =>
        MotionAssessmentPagePhase.calibrating,
      MotionAssessmentWorkflowPhase.capturingSegment =>
        MotionAssessmentPagePhase.capturingSegment,
      MotionAssessmentWorkflowPhase.changingOrientation =>
        MotionAssessmentPagePhase.changingOrientation,
      MotionAssessmentWorkflowPhase.capturingValidationSegment =>
        MotionAssessmentPagePhase.capturingValidationSegment,
      MotionAssessmentWorkflowPhase.qualityReview =>
        MotionAssessmentPagePhase.qualityReview,
      MotionAssessmentWorkflowPhase.reviewReady =>
        MotionAssessmentPagePhase.reviewReady,
      MotionAssessmentWorkflowPhase.awaitingFinishConfirmation =>
        MotionAssessmentPagePhase.awaitingFinishConfirmation,
      MotionAssessmentWorkflowPhase.finalizing =>
        MotionAssessmentPagePhase.finalizing,
      MotionAssessmentWorkflowPhase.completed =>
        MotionAssessmentPagePhase.completed,
      MotionAssessmentWorkflowPhase.failed => MotionAssessmentPagePhase.failed,
    };
  }

  String _classificationValue(ForwardHeadClassification classification) {
    return classification == ForwardHeadClassification.forwardTendency
        ? 'forward_tendency'
        : 'neutral_range';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    voice.removeListener(_onVoiceChanged);
    unawaited(finish().whenComplete(voice.dispose));
    super.dispose();
  }
}
