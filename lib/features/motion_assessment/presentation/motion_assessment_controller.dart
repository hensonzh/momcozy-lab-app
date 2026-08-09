import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_assessment_api_repository.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_pose_platform.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_voice.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/forward_head_analyzer.dart';
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
    required this.locale,
    required this.repository,
    required this.posePlatform,
    required this.voice,
    MotionQualityGate? qualityGate,
    ForwardHeadAnalyzer? forwardHeadAnalyzer,
  }) : qualityGate = qualityGate ?? MotionQualityGate(),
       forwardHeadAnalyzer = forwardHeadAnalyzer ?? ForwardHeadAnalyzer();

  final String target;
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

  MotionAssessmentPagePhase get phase => _phase;
  MotionAssessmentSession? get session => _session;
  MotionPoseObservation? get observation => _observation;
  ForwardHeadResult? get forwardHeadResult => _forwardHeadResult;
  String get guidance => _guidance;
  String? get errorMessage => _errorMessage;
  int get personCount => _observation?.poses.length ?? 0;
  MotionRealtimeVoicePhase get voicePhase => voice.phase;
  bool get exitRequested => _exitRequested;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    voice.addListener(_onVoiceChanged);
    _voiceCommandSubscription = voice.commands.listen(
      (command) => unawaited(_handleVoiceCommand(command)),
    );
    try {
      final cameraGranted = await posePlatform.requestCameraPermission();
      if (_closed) return;
      if (!cameraGranted) {
        throw StateError('需要摄像头权限才能进行动态姿态评估。');
      }
      final createdSession = await repository.create(
        target: target,
        poseEngine: posePlatform.engineName,
        locale: locale,
      );
      if (_closed) {
        await _cancelCreatedSession(createdSession);
        return;
      }
      _session = createdSession;
      _poseSubscription = posePlatform.observations.listen(
        _onObservation,
        onError: _onPoseError,
      );
      await posePlatform.start();
      if (_closed) {
        await posePlatform.stop();
        return;
      }
      _phase = MotionAssessmentPagePhase.calibrating;
      _guidance = '请后退一些，让全身完整进入画面';
      notifyListeners();
      unawaited(
        voice
            .connect(assessmentId: _session!.id)
            .then((_) => voice.speak('请后退一些，让全身完整进入画面'))
            .catchError((Object _) {
              if (_closed) return;
              _guidance = '实时语音暂未连接，请根据屏幕提示调整站位';
              notifyListeners();
            }),
      );
      await _updateSession(status: 'active');
    } catch (error) {
      if (_closed) return;
      _phase = MotionAssessmentPagePhase.failed;
      _errorMessage = _friendlyError(error);
      _guidance = _errorMessage!;
      notifyListeners();
    }
  }

  void _onObservation(MotionPoseObservation observation) {
    if (_closed || _phase == MotionAssessmentPagePhase.completed) return;
    _observation = observation;
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
    notifyListeners();

    final directive = decision.directive;
    if (directive != null) unawaited(_handleDirective(directive));
    if (!decision.acceptFrame || decision.target == null) {
      if (target == 'forward_head' && !_resultReported) {
        forwardHeadAnalyzer.rejectFrame();
      }
      return;
    }
    if (target == 'forward_head' && !_resultReported) {
      final result = forwardHeadAnalyzer.add(
        decision.target!,
        at: observation.timestamp,
        inputWidth: observation.inputWidth,
        inputHeight: observation.inputHeight,
      );
      if (result != null) {
        _resultReported = true;
        _forwardHeadResult = result;
        _guidance = result.userMessage;
        notifyListeners();
        unawaited(_reportForwardHeadResult(result));
      } else if (forwardHeadAnalyzer.lastFrameStatus ==
          ForwardHeadFrameStatus.needsSideView) {
        _guidance = '请转为自然侧身，让两侧肩部在画面中尽量重合';
        notifyListeners();
      }
    }
  }

  Future<void> _handleDirective(MotionGuidanceDirective directive) async {
    switch (directive) {
      case MotionGuidanceDirective.adjustFraming:
        await voice.sendClientEvent('framing_incomplete', {
          'person_count': 1,
          'accept_pose_frames': false,
        });
        await voice.speak('请后退一些，让头部到双脚完整进入画面。');
      case MotionGuidanceDirective.singlePersonReady:
        await voice.sendClientEvent('single_person_stable', {
          'person_count': 1,
          'target': target,
        });
        await voice.speak(
          target == 'forward_head'
              ? '取景完成。请自然侧身，双脚站稳，目视前方，不要刻意挺直。'
              : '取景完成，请保持安全距离，按提示完成动作。',
        );
      case MotionGuidanceDirective.askOthersToLeave:
        await _updateSession(status: 'paused', pauseReason: 'multiple_people');
        await voice.sendClientEvent('multiple_people', {
          'person_count': personCount,
          'accept_pose_frames': false,
        });
        await voice.speak('检测到多人入镜，请让非评估人员离开镜头', interrupt: true);
      case MotionGuidanceDirective.assessmentResumed:
        await _updateSession(status: 'active');
        await voice.sendClientEvent('single_person_stable', {
          'person_count': 1,
          'resumed': true,
        });
        await voice.speak('已确认只有一位评估对象，我们继续。');
      case MotionGuidanceDirective.confirmRecalibration:
        await _updateSession(status: 'paused', pauseReason: 'target_changed');
        await voice.sendClientEvent('target_changed', {
          'accept_pose_frames': false,
        });
        await voice.speak('检测对象可能已变化，请在屏幕上确认重新校准。', interrupt: true);
    }
  }

  Future<void> confirmRecalibration() async {
    qualityGate.confirmRecalibration();
    forwardHeadAnalyzer.reset();
    _resultReported = false;
    _forwardHeadResult = null;
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
    final classification = _classificationValue(result.classification);
    final summary = <String, Object?>{
      'metric': result.metric,
      'value': double.parse(result.valueDegrees.toStringAsFixed(1)),
      'unit': 'degrees',
      'classification': classification,
      'confidence': 0.8,
      'sample_duration_ms': 2000,
      'side': result.side,
      'frame_quality': 'accepted',
    };
    await voice.sendClientEvent('assessment_metric_ready', summary);
    await voice.speak(result.userMessage);
    await _updateSession(status: 'active', resultSummary: summary);
  }

  Future<void> finish({bool completed = false}) async {
    if (_closed) return;
    _closed = true;
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
          resultSummary: _forwardHeadResult == null
              ? null
              : {
                  'metric': _forwardHeadResult!.metric,
                  'value': double.parse(
                    _forwardHeadResult!.valueDegrees.toStringAsFixed(1),
                  ),
                  'unit': 'degrees',
                  'classification': _classificationValue(
                    _forwardHeadResult!.classification,
                  ),
                },
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
    if (!_closed) notifyListeners();
  }

  void _onPoseError(Object error, StackTrace stackTrace) {
    if (_closed) return;
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
