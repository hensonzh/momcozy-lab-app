import 'dart:async';

import 'package:flutter/foundation.dart';
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

  MotionAssessmentPagePhase get phase => _phase;
  MotionAssessmentSession? get session => _session;
  MotionPoseObservation? get observation => _observation;
  ForwardHeadResult? get forwardHeadResult => _forwardHeadResult;
  String get guidance => _guidance;
  String? get errorMessage => _errorMessage;
  int get personCount => _observation?.poses.length ?? 0;
  MotionRealtimeVoicePhase get voicePhase => voice.phase;
  bool get exitRequested => _exitRequested;
  bool get cameraStarted => _cameraStarted;
  String? get voiceStatusMessage => _voiceStatusMessage;

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
      _guidance = '请后退一些，让全身完整进入画面';
      notifyListeners();
    } catch (error) {
      if (_closed) return;
      _cameraStarted = false;
      _phase = MotionAssessmentPagePhase.failed;
      _errorMessage = _friendlyError(error);
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
      _voiceStatusMessage = '实时语音暂不可用，本地评估仍可继续';
      _guidance = '云端评估服务暂未连接，请根据屏幕提示继续调整站位';
      notifyListeners();
      return;
    }
    if (_closed) {
      await _cancelCreatedSession(createdSession);
      return;
    }
    _session = createdSession;
    unawaited(_connectVoice(createdSession.id));
    await _updateSession(status: 'active');
  }

  Future<void> _connectVoice(String assessmentId) async {
    try {
      await voice.connect(assessmentId: assessmentId);
      if (_closed) return;
      _voiceStatusMessage = null;
      final instruction = _forwardHeadResult?.userMessage ?? _guidance;
      await voice.speak(instruction);
    } catch (_) {
      if (_closed) return;
      _voiceStatusMessage = '实时语音暂未连接，请根据屏幕提示继续';
      notifyListeners();
    }
  }

  void _onObservation(MotionPoseObservation observation) {
    if (_closed || _phase == MotionAssessmentPagePhase.completed) return;
    _observation = observation;
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
            ? '请后退一些，让头部到双脚完整进入画面'
            : observation.poses.isEmpty
            ? '请站到镜头前，让全身完整入镜'
            : observation.poses.length > 1
            ? '检测到多人，正在确认…'
            : '保持站位，正在校准评估对象…';
      case MotionQualityPhase.ready:
        _phase = MotionAssessmentPagePhase.assessing;
        _guidance = target == 'forward_head'
            ? '请自然侧身，双脚站稳并目视前方'
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
        voice.sendClientEvent('side_view_required', {
          'required_view': 'side',
          'context': snapshot.toJson(),
        }),
      );
      unawaited(voice.speak('请自然侧身，让两侧肩部在画面中尽量重合。'));
    }
    notifyListeners();
    if (directive != null) unawaited(_handleDirective(directive));
    if (readyResult != null) unawaited(_reportForwardHeadResult(readyResult));
  }

  void _recordDirective(MotionGuidanceDirective directive) {
    switch (directive) {
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
    final fullBodyVisible =
        personCount == 1 && decision.phase != MotionQualityPhase.framing;
    final frameStatus = forwardHeadAnalyzer.lastFrameStatus;
    final result = _forwardHeadResult;
    final samplingProgress = result == null
        ? forwardHeadAnalyzer.samplingProgress
        : 1.0;
    final missingRegions = <String>[
      if (personCount == 0) 'person',
      if (personCount == 1 && decision.phase == MotionQualityPhase.framing)
        ..._missingBodyRegions(observation.poses.single),
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
      fullBodyVisible: fullBodyVisible,
      missingRegions: missingRegions,
      distance: fullBodyVisible
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

  List<String> _missingBodyRegions(MotionPose pose) {
    bool unreliable(MotionPoseLandmarkType type) {
      return !(pose.landmark(type)?.isReliable(minimumConfidence: 0.45) ??
          false);
    }

    return <String>[
      if (unreliable(MotionPoseLandmarkType.nose)) 'head',
      if (unreliable(MotionPoseLandmarkType.leftShoulder) &&
          unreliable(MotionPoseLandmarkType.rightShoulder))
        'shoulders',
      if (unreliable(MotionPoseLandmarkType.leftHip) &&
          unreliable(MotionPoseLandmarkType.rightHip))
        'hips',
      if (unreliable(MotionPoseLandmarkType.leftKnee) &&
          unreliable(MotionPoseLandmarkType.rightKnee))
        'knees',
      if (unreliable(MotionPoseLandmarkType.leftAnkle) &&
          unreliable(MotionPoseLandmarkType.rightAnkle))
        'feet',
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
      return (action: 'step_back', reason: 'full_body_not_visible');
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
          voice.sendClientEvent('sampling_progress', {
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
      case MotionGuidanceDirective.adjustFraming:
        await voice.sendClientEvent(
          'framing_incomplete',
          _withLatestContext({'person_count': 1, 'accept_pose_frames': false}),
        );
        await voice.speak('请后退一些，让头部到双脚完整进入画面。');
      case MotionGuidanceDirective.singlePersonReady:
        await voice.sendClientEvent(
          'single_person_stable',
          _withLatestContext({'person_count': 1, 'target': target}),
        );
        await voice.speak(
          target == 'forward_head'
              ? '取景完成。请自然侧身，双脚站稳，目视前方，不要刻意挺直。'
              : '取景完成，请保持安全距离，按提示完成动作。',
        );
      case MotionGuidanceDirective.askOthersToLeave:
        await _updateSession(status: 'paused', pauseReason: 'multiple_people');
        await voice.sendClientEvent(
          'multiple_people',
          _withLatestContext({
            'person_count': personCount,
            'accept_pose_frames': false,
          }),
        );
        await voice.speak('检测到多人入镜，请让非评估人员离开镜头', interrupt: true);
      case MotionGuidanceDirective.assessmentResumed:
        await _updateSession(status: 'active');
        await voice.sendClientEvent(
          'single_person_stable',
          _withLatestContext({'person_count': 1, 'resumed': true}),
        );
        await voice.speak('已确认只有一位评估对象，我们继续。');
      case MotionGuidanceDirective.confirmRecalibration:
        await _updateSession(status: 'paused', pauseReason: 'target_changed');
        await voice.sendClientEvent(
          'target_changed',
          _withLatestContext({'accept_pose_frames': false}),
        );
        await voice.speak('检测对象可能已变化，请在屏幕上确认重新校准。', interrupt: true);
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
            message: '当前无需重新校准，我们继续保持单人完整入镜。',
          );
          return;
        }
        await confirmRecalibration();
        await voice.completeCommand(
          command,
          accepted: true,
          message: '已确认是你，请保持单人完整入镜，正在重新校准。',
        );
      case MotionVoiceCommandType.repeatInstruction:
        await voice.completeCommand(
          command,
          accepted: true,
          message: _guidance,
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
    final summary = _forwardHeadSummary(result);
    _latestResultSummary = Map<String, Object?>.unmodifiable(summary);
    final context = _latestContext;
    await voice.sendClientEvent('assessment_metric_ready', {
      ...summary,
      if (context != null) 'context': context.toJson(),
    });
    await voice.speak(result.userMessage);
    await _updateSession(status: 'active', resultSummary: summary);
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
    } else if (voice.phase == MotionRealtimeVoicePhase.failed) {
      _voiceStatusMessage ??= '实时语音暂未连接，请根据屏幕提示继续';
    }
    notifyListeners();
  }

  void _onPoseError(Object error, StackTrace stackTrace) {
    if (_closed) return;
    _cameraStarted = false;
    _phase = MotionAssessmentPagePhase.failed;
    _errorMessage = '端侧姿态识别暂时不可用，请退出后重试。';
    _guidance = _errorMessage!;
    notifyListeners();
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

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('摄像头权限')) return '请允许摄像头权限后重试。';
    return '动态评估启动失败，请检查网络和权限后重试。';
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
