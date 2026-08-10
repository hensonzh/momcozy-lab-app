import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_pose.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_quality_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

enum MotionAssessmentPagePhase {
  preparing,
  calibrating,
  assessing,
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
    MotionQualityGate? qualityGate,
    ForwardHeadAnalyzer? forwardHeadAnalyzer,
  }) : qualityGate = qualityGate ?? MotionQualityGate(),
       forwardHeadAnalyzer = forwardHeadAnalyzer ?? ForwardHeadAnalyzer();

  final String target;
  final String sourceArtifactId;
  final String locale;
  final MotionAssessmentRepository repository;
  final MotionPosePlatform posePlatform;
  final MotionRealtimeVoiceClient voice;
  final Future<void> Function()? prepareRealtimeAudio;
  final Duration voiceRetryDelay;
  final MotionQualityGate qualityGate;
  final ForwardHeadAnalyzer forwardHeadAnalyzer;

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
  bool _resultReported = false;
  bool _exitRequested = false;
  bool _cameraStarted = false;
  String? _voiceStatusMessage;
  int _contextSequence = 0;
  int _totalFrames = 0;
  int _acceptedFrames = 0;
  int _multiplePeopleCount = 0;
  int _targetChangedCount = 0;
  int _framingAdjustmentCount = 0;
  final Set<int> _reportedSamplingMilestones = <int>{};
  bool _sideViewPromptEmitted = false;
  Duration? _firstObservationAt;
  MotionAssessmentContextSnapshot? _latestContext;
  Map<String, Object?>? _latestResultSummary;
  String? _voiceAssessmentId;
  bool _voiceConnectInProgress = false;
  bool _voiceReady = false;
  bool _voiceEverReady = false;
  int _voiceRecoveryCycles = 0;
  bool _completionInProgress = false;
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
  double get samplingProgress =>
      _forwardHeadResult == null ? forwardHeadAnalyzer.samplingProgress : 1;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    voice.addListener(_onVoiceChanged);
    _voiceCommandSubscription = voice.commands.listen(
      (command) => unawaited(_handleVoiceCommand(command)),
    );
    _guidance = '正在请求摄像头权限…';
    notifyListeners();
    try {
      final cameraGranted = await posePlatform.requestCameraPermission();
      if (_closed) return;
      if (!cameraGranted) {
        throw StateError('需要摄像头权限才能进行动态姿态评估。');
      }
      _poseSubscription = posePlatform.observations.listen(
        _onObservation,
        onError: _onPoseError,
      );
      _guidance = '正在打开相机并加载端侧姿态识别…';
      notifyListeners();
      await posePlatform.start();
      if (_closed) {
        await posePlatform.stop();
        return;
      }
      _cameraStarted = true;
      _phase = MotionAssessmentPagePhase.calibrating;
      _guidance = '请让头部、肩部和髋部进入画面';
      notifyListeners();
    } catch (error) {
      if (_closed) return;
      await _stopPoseAfterFailure();
      _cameraStarted = false;
      _phase = MotionAssessmentPagePhase.failed;
      _errorMessage = _friendlyPoseError(error);
      _poseDiagnosticMessage = _poseDiagnosticFor(error);
      _guidance = _errorMessage!;
      notifyListeners();
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
      if (_closed) return;
      _voiceStatusMessage = '实时评估服务未连接';
      _exitRequested = true;
      await finish();
      return;
    }
    if (_closed) {
      await _cancelCreatedSession(createdSession);
      return;
    }
    _session = createdSession;
    await _updateSession(status: 'active');
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
            }),
            awaitPlaybackStart: true,
          );
          if (_closed) return false;
          _voiceReady = true;
          _voiceEverReady = true;
          notifyListeners();
          return true;
        } catch (_) {
          if (_closed) return false;
          _voiceStatusMessage = attempt == 0
              ? 'OpenAI 实时语音正在重新连接'
              : 'OpenAI 实时语音未连接';
          notifyListeners();
        }
      }
      if (!_closed) {
        _exitRequested = true;
        await finish();
      }
      return false;
    } finally {
      _voiceConnectInProgress = false;
    }
  }

  void _onObservation(MotionPoseObservation observation) {
    if (_closed || _phase == MotionAssessmentPagePhase.completed) return;
    _observation = observation;
    if (!_voiceReady) {
      notifyListeners();
      return;
    }
    _firstObservationAt ??= observation.timestamp;
    _totalFrames += 1;
    final decision = qualityGate.evaluate(observation);
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
        _phase = MotionAssessmentPagePhase.assessing;
        _guidance = target == 'forward_head'
            ? '请自然侧身，站稳并目视前方'
            : '取景已就绪，请按语音提示完成动作';
      case MotionQualityPhase.pausedMultiplePeople:
        _phase = MotionAssessmentPagePhase.pausedMultiplePeople;
        _guidance = '检测到多人，请让非评估人员离开镜头';
      case MotionQualityPhase.targetChanged:
        _phase = MotionAssessmentPagePhase.targetChanged;
        _guidance = '检测对象可能已变化，请确认后重新校准';
    }
    final directive = decision.directive;
    if (directive != null) {
      _recordDirective(directive);
    }

    ForwardHeadResult? readyResult;
    if (!decision.acceptFrame || decision.target == null) {
      if (target == 'forward_head' && !_resultReported) {
        forwardHeadAnalyzer.rejectFrame();
      }
    } else if (target == 'forward_head' && !_resultReported) {
      _acceptedFrames += 1;
      readyResult = forwardHeadAnalyzer.add(
        decision.target!,
        at: observation.timestamp,
        inputWidth: observation.inputWidth,
        inputHeight: observation.inputHeight,
      );
      if (readyResult != null) {
        _resultReported = true;
        _forwardHeadResult = readyResult;
        _guidance = readyResult.userMessage;
      } else if (forwardHeadAnalyzer.lastFrameStatus ==
          ForwardHeadFrameStatus.needsSideView) {
        _guidance = '请转为自然侧身，让两侧肩部在画面中尽量重合';
      }
    }

    final snapshot = _buildContextSnapshot(observation, decision);
    _latestContext = snapshot;
    voice.updateAssessmentContext(snapshot);
    _emitSamplingMilestone(snapshot);
    if (forwardHeadAnalyzer.lastFrameStatus ==
            ForwardHeadFrameStatus.needsSideView &&
        !_sideViewPromptEmitted) {
      _sideViewPromptEmitted = true;
      unawaited(
        voice.requestGuidance('side_view_required', {
          'required_view': 'side',
          'context': snapshot.toJson(),
        }),
      );
    }
    notifyListeners();
    if (directive != null) unawaited(_handleDirective(directive));
    if (readyResult != null) unawaited(_reportForwardHeadResult(readyResult));
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
    final samplingProgress = result == null
        ? forwardHeadAnalyzer.samplingProgress
        : 1.0;
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
        ? 'completed'
        : rejectionReasons.isNotEmpty
        ? 'blocked'
        : decision.acceptFrame
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
      phase: result != null ? 'result_ready' : _assessmentPhaseValue(_phase),
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
      requiredView: target == 'forward_head' ? 'side' : 'guided',
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
          ? 'final'
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
      discomfortReported: false,
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
      return (action: 'review_result', reason: 'measurement_complete');
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

  String _assessmentPhaseValue(MotionAssessmentPagePhase value) {
    return switch (value) {
      MotionAssessmentPagePhase.preparing => 'preparing',
      MotionAssessmentPagePhase.calibrating => 'calibrating',
      MotionAssessmentPagePhase.assessing => 'sampling',
      MotionAssessmentPagePhase.pausedMultiplePeople =>
        'paused_multiple_people',
      MotionAssessmentPagePhase.targetChanged => 'target_changed',
      MotionAssessmentPagePhase.completed => 'completed',
      MotionAssessmentPagePhase.failed => 'failed',
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

  void _emitSamplingMilestone(MotionAssessmentContextSnapshot snapshot) {
    if (snapshot.samplingState != 'collecting') return;
    final percent = (snapshot.samplingProgress * 100).floor();
    for (final milestone in const [25, 50, 75]) {
      if (percent >= milestone && _reportedSamplingMilestones.add(milestone)) {
        unawaited(
          voice.requestGuidance('sampling_progress', {
            'milestone_percent': milestone,
            'context': snapshot.toJson(),
          }),
        );
      }
    }
  }

  Map<String, Object?> _withLatestContext(Map<String, Object?> payload) {
    final context = _latestContext;
    return {...payload, if (context != null) 'context': context.toJson()};
  }

  Future<void> _handleDirective(MotionGuidanceDirective directive) async {
    switch (directive) {
      case MotionGuidanceDirective.enterFrame:
        await voice.requestGuidance(
          'person_not_detected',
          _withLatestContext({'person_count': 0, 'accept_pose_frames': false}),
        );
      case MotionGuidanceDirective.adjustFraming:
        await voice.requestGuidance(
          'framing_incomplete',
          _withLatestContext({'person_count': 1, 'accept_pose_frames': false}),
        );
      case MotionGuidanceDirective.singlePersonReady:
        await voice.requestGuidance(
          'single_person_stable',
          _withLatestContext({'person_count': 1, 'target': target}),
        );
      case MotionGuidanceDirective.askOthersToLeave:
        await _updateSession(status: 'paused', pauseReason: 'multiple_people');
        await voice.requestGuidance(
          'multiple_people',
          _withLatestContext({
            'person_count': personCount,
            'accept_pose_frames': false,
          }),
          interrupt: true,
        );
      case MotionGuidanceDirective.assessmentResumed:
        await _updateSession(status: 'active');
        await voice.requestGuidance(
          'single_person_stable',
          _withLatestContext({'person_count': 1, 'resumed': true}),
        );
      case MotionGuidanceDirective.confirmRecalibration:
        await _updateSession(status: 'paused', pauseReason: 'target_changed');
        await voice.requestGuidance(
          'target_changed',
          _withLatestContext({'accept_pose_frames': false}),
          interrupt: true,
        );
    }
  }

  Future<void> confirmRecalibration() async {
    qualityGate.confirmRecalibration();
    forwardHeadAnalyzer.reset();
    _resultReported = false;
    _forwardHeadResult = null;
    _latestResultSummary = null;
    _reportedSamplingMilestones.clear();
    _sideViewPromptEmitted = false;
    _phase = MotionAssessmentPagePhase.calibrating;
    _guidance = '请保持单人入镜，正在重新校准…';
    notifyListeners();
    await _updateSession(status: 'active');
  }

  Future<void> _handleVoiceCommand(MotionVoiceCommand command) async {
    if (_closed) return;
    switch (command.type) {
      case MotionVoiceCommandType.confirmRecalibration:
        if (_phase != MotionAssessmentPagePhase.targetChanged) {
          await voice.completeCommand(
            command,
            accepted: false,
            message: 'recalibration_not_required',
            speakResult: false,
          );
          await voice.requestGuidance(
            'recalibration_not_required',
            _withLatestContext({'accepted': false}),
          );
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
          message: '评估已停止',
          speakResult: false,
        );
        _exitRequested = true;
        await finish();
    }
  }

  Future<void> _reportForwardHeadResult(ForwardHeadResult result) async {
    if (_closed || _completionInProgress) return;
    _completionInProgress = true;
    final summary = _forwardHeadSummary(result);
    _latestResultSummary = Map<String, Object?>.unmodifiable(summary);
    final context = _latestContext;
    try {
      await voice.requestGuidance(
        'assessment_completed',
        {...summary, if (context != null) 'context': context.toJson()},
        interrupt: true,
        awaitPlaybackCompletion: true,
      );
    } catch (_) {
      // The authoritative aggregate is still completed and handed to the main
      // Agent when the final Realtime acknowledgement cannot be played.
    }
    await finish(completed: true);
    _exitRequested = true;
    if (!_disposed) notifyListeners();
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
      'multiple_people_count': _multiplePeopleCount,
      'target_changed_count': _targetChangedCount,
      'framing_adjustment_count': _framingAdjustmentCount,
      'pose_model_version':
          posePlatform.engineName == 'mediapipe_pose_landmarker'
          ? 'pose_landmarker_lite.task'
          : 'vision_human_body_pose',
      'analyzer_version': forwardHeadAnalyzerVersion,
      'threshold_version': forwardHeadThresholdVersion,
    };
  }

  Future<void> finish({bool completed = false}) async {
    if (_closed) return;
    _closed = true;
    _cameraStarted = false;
    final poseStop = _stopPosePlatform();
    final voiceStop = voice.close();
    await _poseSubscription?.cancel();
    _poseSubscription = null;
    await _voiceCommandSubscription?.cancel();
    _voiceCommandSubscription = null;
    await poseStop;
    await voiceStop;
    final session = _session;
    if (session != null) {
      try {
        await repository.update(
          assessmentId: session.id,
          status: completed ? 'completed' : 'cancelled',
          resultSummary: _latestResultSummary,
        );
        if (completed) {
          _completedSuccessfully = true;
          _completedAssessmentId = session.id;
        }
      } catch (_) {
        // Closing the private camera is more important than a final status sync.
      }
    }
    _phase = MotionAssessmentPagePhase.completed;
    if (!_disposed) notifyListeners();
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
          !_completionInProgress &&
          _voiceRecoveryCycles < 1 &&
          assessmentId != null) {
        _voiceRecoveryCycles += 1;
        unawaited(_connectVoice(assessmentId, recovering: true));
      }
    }
    notifyListeners();
  }

  void _onPoseError(Object error, StackTrace _) {
    if (_closed) return;
    debugPrint('Motion pose stream failed: $error');
    unawaited(_stopPoseAfterFailure());
    _cameraStarted = false;
    _phase = MotionAssessmentPagePhase.failed;
    _errorMessage = _friendlyPoseError(error);
    _poseDiagnosticMessage = _poseDiagnosticFor(error);
    _guidance = _errorMessage!;
    notifyListeners();
  }

  Future<void> _stopPoseAfterFailure() async {
    final subscription = _poseSubscription;
    _poseSubscription = null;
    await subscription?.cancel();
    await _stopPosePlatform();
  }

  String _friendlyPoseError(Object error) {
    if (error case PlatformException(code: final code)) {
      return switch (code) {
        'pose_model_initialization_failed' => '端侧姿态模型加载失败，请退出后重试。',
        'pose_inference_failed' => '端侧姿态识别运行异常，请退出后重试。',
        'pose_start_timeout' => '端侧姿态模型启动超时，请退出后重试。',
        'pose_event_stream_closed' => '端侧姿态识别连接中断，请退出后重试。',
        'camera_start_cancelled' => '端侧姿态识别启动已取消。',
        'camera_start_failed' => '前置摄像头启动失败，请检查相机是否被其他应用占用。',
        'permission_denied' => '请允许摄像头权限后重试。',
        _ => '端侧姿态识别暂时不可用，请退出后重试。',
      };
    }
    if (error is MissingPluginException) {
      return '当前安装版本未包含端侧姿态识别组件，请更新 App 后重试。';
    }
    if (error.toString().contains('摄像头权限')) {
      return '请允许摄像头权限后重试。';
    }
    return '端侧姿态识别暂时不可用，请退出后重试。';
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

  String _classificationValue(ForwardHeadClassification classification) {
    return classification == ForwardHeadClassification.forwardTendency
        ? 'forward_tendency'
        : 'neutral_range';
  }

  @override
  void dispose() {
    _disposed = true;
    voice.removeListener(_onVoiceChanged);
    unawaited(finish().whenComplete(voice.dispose));
    super.dispose();
  }
}
