import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_audio_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_playback_tracker.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_response_queue.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_session_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_visual_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_event.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_voice_command.dart';

enum MotionRealtimeVoicePhase {
  idle,
  requestingPermission,
  connecting,
  listening,
  speaking,
  reconnecting,
  failed,
  closed,
}

enum MotionRealtimeGuidanceFailure {
  busy,
  interruptedByUser,
  playbackStartTimeout,
  playbackCompletionTimeout,
}

class MotionRealtimeGuidanceException implements Exception {
  const MotionRealtimeGuidanceException({
    required this.eventType,
    required this.failure,
  });

  final String eventType;
  final MotionRealtimeGuidanceFailure failure;

  bool get isRecoverable => true;

  @override
  String toString() =>
      'MotionRealtimeGuidanceException($eventType, ${failure.name})';
}

abstract interface class MotionRealtimeVoiceClient implements Listenable {
  MotionRealtimeVoicePhase get phase;
  bool get isConnected;
  bool get hasRemoteAudioTrack;
  String get providerName;
  String? get failureCode;
  String? get latestCompletedUserAudioItemId;
  Stream<MotionVoiceCommand> get commands;

  Future<void> connect({required String assessmentId});
  Future<void> speak(
    String instruction, {
    bool interrupt = false,
    bool exact = false,
  });
  Future<void> requestGuidance(
    String eventType,
    Map<String, Object?> payload, {
    bool interrupt = false,
    bool awaitPlaybackStart = false,
    bool awaitPlaybackCompletion = false,
  });
  void updateAssessmentContext(MotionAssessmentContextSnapshot snapshot);
  Future<void> sendClientEvent(String eventType, Map<String, Object?> payload);
  Future<void> completeCommand(
    MotionVoiceCommand command, {
    required bool accepted,
    required String message,
    Map<String, Object?> details = const {},
    bool speakResult = true,
  });
  Future<void> close();
  void dispose();
}

class MotionRealtimeVoice extends ChangeNotifier
    implements MotionRealtimeVoiceClient {
  MotionRealtimeVoice({
    required this.signaling,
    MotionRealtimeAudioSession? audioSession,
    this.visualContextCoordinator,
  }) : audioSession = audioSession ?? WebRtcMotionRealtimeAudioSession();

  final MotionVoiceSignaling signaling;
  final MotionRealtimeAudioSession audioSession;
  final MotionVisualContextCoordinator? visualContextCoordinator;

  MotionRealtimeVoicePhase _phase = MotionRealtimeVoicePhase.idle;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _microphoneStream;
  MediaStream? _remoteAudioStream;
  MotionRealtimeResponseQueue? _responseQueue;
  MotionRealtimeSessionGate? _sessionGate;
  final MotionRealtimePlaybackTracker _playbackTracker =
      MotionRealtimePlaybackTracker();
  final StreamController<MotionVoiceCommand> _commands =
      StreamController<MotionVoiceCommand>.broadcast();
  final Set<String> _handledCommandCallIds = {};
  final Set<String> _handledUserAudioItemIds = {};
  final Set<String> _handledVisualCallIds = {};
  final Set<String> _visualRequestTurnIds = {};
  final Set<String> _visualClientEventIds = {};
  final MotionAssessmentEventGate _eventGate = MotionAssessmentEventGate();
  Future<void> _inputOperations = Future<void>.value();
  Future<void> _guidanceOperations = Future<void>.value();
  MotionAssessmentContextSnapshot? _latestAssessmentContext;
  DateTime? _latestAssessmentContextReceivedAt;
  MotionAssessmentEventFactory? _eventFactory;
  String? _latestCompletedUserAudioItemId;
  int _connectionGeneration = 0;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _terminalCleanup;
  Timer? _disconnectTimer;
  String _providerName = '';
  String? _failureCode;
  bool _remoteAudioTrackReady = false;
  bool _audioSessionActive = false;
  Completer<void>? _playbackStarted;
  Completer<void>? _playbackCompleted;
  int _visualEventSequence = 0;

  @override
  MotionRealtimeVoicePhase get phase => _phase;
  @override
  bool get isConnected =>
      _phase == MotionRealtimeVoicePhase.listening ||
      _phase == MotionRealtimeVoicePhase.speaking;
  @override
  bool get hasRemoteAudioTrack =>
      _remoteAudioTrackReady ||
      _remoteAudioStream?.getAudioTracks().isNotEmpty == true;
  @override
  String get providerName => _providerName;
  @override
  String? get failureCode => _failureCode;
  @override
  String? get latestCompletedUserAudioItemId => _latestCompletedUserAudioItemId;
  @override
  Stream<MotionVoiceCommand> get commands => _commands.stream;

  @override
  Future<void> connect({required String assessmentId}) async {
    if (_disposed || _closed || _phase == MotionRealtimeVoicePhase.connecting) {
      return;
    }
    final pendingCleanup = _terminalCleanup;
    if (pendingCleanup != null) await pendingCleanup;
    if (_disposed || _closed) return;
    if (_peerConnection != null ||
        _dataChannel != null ||
        _microphoneStream != null) {
      _connectionGeneration += 1;
      await _closeResources();
      if (_disposed || _closed) return;
    }
    final generation = ++_connectionGeneration;
    visualContextCoordinator?.setServerCapability(false);
    _eventFactory = MotionAssessmentEventFactory(assessmentId: assessmentId);
    _failureCode = null;
    _setPhase(MotionRealtimeVoicePhase.requestingPermission);
    var failureStage = 'audio_session';
    try {
      _audioSessionActive = true;
      await audioSession.activate();
      failureStage = 'microphone_permission';
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      if (!_isActive(generation)) {
        await _disposeStream(stream);
        return;
      }
      _microphoneStream = stream;
      _setPhase(MotionRealtimeVoicePhase.connecting);
      failureStage = 'peer_connection';
      final sessionGate = MotionRealtimeSessionGate();
      _sessionGate = sessionGate;
      final peer = await createPeerConnection({
        'sdpSemantics': 'unified-plan',
        'bundlePolicy': 'max-bundle',
      });
      _peerConnection = peer;
      if (!_isActive(generation)) {
        await peer.close();
        await peer.dispose();
        await _disposeStream(stream);
        return;
      }
      for (final track in stream.getAudioTracks()) {
        // Negotiate the microphone track with the initial offer, but do not
        // transmit user audio before OpenAI confirms the model session.
        track.enabled = false;
        await peer.addTrack(track, stream);
      }
      peer.onConnectionState = (state) {
        if (!_isActive(generation)) return;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _disconnectTimer?.cancel();
            _disconnectTimer = null;
            sessionGate.markPeerConnected();
            if (sessionGate.isReady && _responseQueue != null) {
              _setPhase(MotionRealtimeVoicePhase.listening);
            }
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _setPhase(MotionRealtimeVoicePhase.reconnecting);
            _disconnectTimer?.cancel();
            _disconnectTimer = Timer(const Duration(seconds: 8), () {
              _failureCode = 'connection_lost';
              _scheduleTerminalFailure(generation);
            });
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _failureCode = 'connection_closed';
            sessionGate.fail(
              StateError('Realtime WebRTC connection closed before ready.'),
            );
            _scheduleTerminalFailure(generation);
          default:
            break;
        }
      };
      peer.onTrack = (event) {
        if (event.track.kind == 'audio') {
          unawaited(_configureRemoteAudio(event, generation, sessionGate));
        }
      };
      final channel = await peer.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      _dataChannel = channel;
      channel.onDataChannelState = (state) {
        if (!_isActive(generation)) return;
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          sessionGate.markDataChannelOpen();
        } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
          sessionGate.fail(
            StateError('Realtime data channel closed before model startup.'),
          );
          _scheduleTerminalFailure(generation);
        }
      };
      channel.onMessage = (message) =>
          _handleServerEvent(message, generation, sessionGate);

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      await _waitForIceGathering(peer);
      final local = await peer.getLocalDescription();
      final offerSdp = local?.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        throw StateError('WebRTC did not produce a local SDP offer.');
      }
      failureStage = 'signaling';
      final answer = await signaling.createAnswer(
        assessmentId: assessmentId,
        offerSdp: offerSdp,
      );
      if (!_isActive(generation)) return;
      _providerName = answer.provider;
      visualContextCoordinator?.setServerCapability(
        answer.visualContextEnabled,
      );
      await peer.setRemoteDescription(
        RTCSessionDescription(answer.answerSdp, 'answer'),
      );
      if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
        sessionGate.markDataChannelOpen();
      }
      failureStage = 'session_startup';
      await sessionGate.ready.timeout(const Duration(seconds: 10));
      if (!_isActive(generation)) return;
      _responseQueue = MotionRealtimeResponseQueue(
        sendEvent: _sendRealtimeEvent,
      );
      for (final track in stream.getAudioTracks()) {
        track.enabled = true;
      }
      _setPhase(MotionRealtimeVoicePhase.listening);
    } catch (error) {
      if (_isActive(generation)) {
        _failureCode = failureStage;
        debugPrint(
          'Motion Realtime voice failed at $failureStage '
          '(${error.runtimeType}).',
        );
        _setPhase(MotionRealtimeVoicePhase.failed);
        await _closeResources();
      }
      rethrow;
    }
  }

  @override
  Future<void> requestGuidance(
    String eventType,
    Map<String, Object?> payload, {
    bool interrupt = false,
    bool awaitPlaybackStart = false,
    bool awaitPlaybackCompletion = false,
  }) {
    final waitsForPlayback = awaitPlaybackStart || awaitPlaybackCompletion;
    if (!waitsForPlayback) {
      return _requestGuidance(
        eventType,
        payload,
        interrupt: interrupt,
        awaitPlaybackStart: awaitPlaybackStart,
        awaitPlaybackCompletion: awaitPlaybackCompletion,
      );
    }
    final result = _guidanceOperations.then(
      (_) => _requestGuidance(
        eventType,
        payload,
        interrupt: interrupt,
        awaitPlaybackStart: awaitPlaybackStart,
        awaitPlaybackCompletion: awaitPlaybackCompletion,
      ),
    );
    _guidanceOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _requestGuidance(
    String eventType,
    Map<String, Object?> payload, {
    required bool interrupt,
    required bool awaitPlaybackStart,
    required bool awaitPlaybackCompletion,
  }) async {
    if (!isConnected) {
      throw StateError('Realtime voice is not connected.');
    }
    final normalizedEventType = eventType.trim();
    if (normalizedEventType.isEmpty) return;
    final shouldWaitForStart = awaitPlaybackStart || awaitPlaybackCompletion;
    final maximumAttempts = shouldWaitForStart ? 2 : 1;
    var eventPublished = false;
    for (var attempt = 0; attempt < maximumAttempts; attempt += 1) {
      final started = shouldWaitForStart ? Completer<void>() : null;
      final completed = awaitPlaybackCompletion ? Completer<void>() : null;
      if (started != null) {
        if (_playbackStarted != null || _playbackCompleted != null) {
          throw MotionRealtimeGuidanceException(
            eventType: normalizedEventType,
            failure: MotionRealtimeGuidanceFailure.busy,
          );
        }
        _playbackStarted = started;
        _playbackCompleted = completed;
      }
      try {
        if (interrupt || attempt > 0) await _responseQueue?.interrupt();
        if (!eventPublished) {
          final published = await _publishClientEvent(
            normalizedEventType,
            payload,
          );
          if (!published) return;
          eventPublished = true;
        }
        await _responseQueue?.enqueueModelTurn(
          _guidanceTurnInstructions(normalizedEventType),
          coalesceKey: _guidanceCoalesceKey(normalizedEventType),
          interruptActive: _interruptsStaleGuidance(normalizedEventType),
        );
        if (started != null) {
          await started.future.timeout(const Duration(seconds: 10));
        }
        if (completed != null) {
          await completed.future.timeout(const Duration(seconds: 20));
        }
        return;
      } on TimeoutException {
        final playbackStarted = started?.isCompleted == true;
        final failure = playbackStarted
            ? MotionRealtimeGuidanceFailure.playbackCompletionTimeout
            : MotionRealtimeGuidanceFailure.playbackStartTimeout;
        debugPrint(
          'Motion Realtime guidance ${failure.name}: '
          '$normalizedEventType (attempt ${attempt + 1}).',
        );
        if (playbackStarted) {
          // Guidance prompts are intentionally short. If audio started but the
          // WebRTC drain event is lost, stop any stale buffer and keep the
          // healthy session instead of reporting a connection failure.
          try {
            await _responseQueue?.interrupt();
          } catch (_) {
            if (!_transportIsUsable) {
              _scheduleTerminalFailure(_connectionGeneration);
            }
          }
          return;
        }
        if (attempt + 1 >= maximumAttempts || !isConnected) {
          throw MotionRealtimeGuidanceException(
            eventType: normalizedEventType,
            failure: failure,
          );
        }
      } on MotionRealtimeGuidanceException catch (error) {
        if (error.failure == MotionRealtimeGuidanceFailure.interruptedByUser &&
            normalizedEventType != 'capture_countdown') {
          // Barge-in is expected with Semantic VAD. Non-countdown guidance can
          // yield to the user's turn; countdown remains synchronized with
          // capture and must be retried after the user finishes speaking.
          return;
        }
        rethrow;
      } catch (_) {
        if (!_transportIsUsable) {
          _scheduleTerminalFailure(_connectionGeneration);
        }
        rethrow;
      } finally {
        if (identical(_playbackStarted, started)) _playbackStarted = null;
        if (identical(_playbackCompleted, completed)) {
          _playbackCompleted = null;
        }
      }
    }
  }

  @override
  Future<void> speak(
    String instruction, {
    bool interrupt = false,
    bool exact = false,
  }) async {
    if (!isConnected) return;
    try {
      await _responseQueue?.enqueue(
        instruction,
        interrupt: interrupt,
        exact: exact,
      );
    } catch (_) {
      _scheduleTerminalFailure(_connectionGeneration);
    }
  }

  @override
  void updateAssessmentContext(MotionAssessmentContextSnapshot snapshot) {
    if (_disposed || _closed) return;
    _latestAssessmentContext = snapshot;
    _latestAssessmentContextReceivedAt = DateTime.now();
  }

  @override
  Future<void> sendClientEvent(
    String eventType,
    Map<String, Object?> payload,
  ) async {
    await _publishClientEvent(eventType, payload);
  }

  Future<bool> _publishClientEvent(
    String eventType,
    Map<String, Object?> payload,
  ) {
    final normalizedType = eventType.trim();
    if (normalizedType.startsWith('safety_') ||
        normalizedType == 'multiple_people') {
      return _publishClientEventInOrder(normalizedType, payload);
    }
    return _serializeInput(
      () => _publishClientEventInOrder(normalizedType, payload),
    );
  }

  Future<bool> _publishClientEventInOrder(
    String eventType,
    Map<String, Object?> payload,
  ) async {
    if (!isConnected) return false;
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return false;
    final factory = _eventFactory;
    if (factory == null) return false;
    final normalizedType = eventType.trim();
    if (normalizedType.isEmpty) return false;
    final dedupeKey = payload['dedupe_key']?.toString().trim();
    if (!_eventGate.shouldSend(
      type: normalizedType,
      dedupeKey: dedupeKey?.isNotEmpty == true ? dedupeKey! : normalizedType,
    )) {
      return false;
    }
    final context = _latestAssessmentContext;
    final facts =
        <String, Object?>{
            ...payload,
            if (!payload.containsKey('context') && context != null)
              'context': context.toJson(),
          }
          ..remove('dedupe_key')
          ..remove('requires_voice_response');
    final event = factory.create(
      type: normalizedType,
      stateRevision: context?.sequence ?? 0,
      facts: facts,
      requiresVoiceResponse: payload['requires_voice_response'] != false,
      dedupeKey: dedupeKey,
    );
    final content = jsonEncode(event);
    try {
      await _sendRealtimeEvent({
        'event_id': 'motion-semantic-${event['event_id']}',
        'type': 'conversation.item.create',
        'item': {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': '[客户端姿态事件]$content'},
          ],
        },
      });
      final coordinator = visualContextCoordinator;
      final semanticEventId = event['event_id']?.toString() ?? '';
      if (coordinator != null && semanticEventId.isNotEmpty) {
        final generation = _connectionGeneration;
        coordinator.scheduleEventCapture(
          eventType: normalizedType,
          eventId: semanticEventId,
          context: context,
          contextAgeMs: _latestContextAgeMs(),
          onCaptured: (visual) async {
            if (!_isActive(generation)) return;
            await _trySendVisualContext(
              assessmentId: factory.assessmentId,
              visual: visual,
            );
          },
        );
      }
      return true;
    } catch (_) {
      _scheduleTerminalFailure(_connectionGeneration);
      rethrow;
    }
  }

  @override
  Future<void> completeCommand(
    MotionVoiceCommand command, {
    required bool accepted,
    required String message,
    Map<String, Object?> details = const {},
    bool speakResult = true,
  }) async {
    if (!isConnected) return;
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    try {
      await channel!.send(
        RTCDataChannelMessage(
          jsonEncode({
            'type': 'conversation.item.create',
            'item': {
              'type': 'function_call_output',
              'call_id': command.callId,
              'output': jsonEncode({
                'accepted': accepted,
                'message': message,
                ...details,
              }),
            },
          }),
        ),
      );
      if (speakResult && message.isNotEmpty) await speak(message);
    } catch (_) {
      _scheduleTerminalFailure(_connectionGeneration);
    }
  }

  String _guidanceTurnInstructions(String eventType) {
    return switch (eventType) {
      'assessment_started' =>
        '这是通用体态评估的新会话。简洁介绍当前开放的三个项目，并给出四种容易理解的选择：'
            '头颈专项（头前伸）、正面体态（高低肩加躯干侧倾）、完整三项，或自选一个或多个；'
            '然后明确询问用户选择哪一种。此时不要引导站位，也不要自行选择，未开放项目不要说成可选。',
      'capture_countdown' =>
        '端侧已确认当前画面可以开始采样。只用一句短句让用户站稳，然后清楚地说“三、二、一，开始”。'
            '必须说完倒计时，不要添加其他动作或结果。',
      'opposite_side_required' =>
        '端侧确认用户仍是上一段的方向。请亲切地说明需要转到另一侧，站稳并目视前方；'
            '不要声称第二段已完成。',
      'assessment_review_ready' =>
        '客户端已完成计划内全部采集与质量复核。请用一句自然中文说明采集已完成，并明确询问用户：'
            '“你想结束本次评估，还是继续评估？”说完后等待用户新的语音回复，不要自行结束。',
      'assessment_plan_updated' =>
        '客户端已更新用户选择。请只依据事件里的 selected_targets 和 plan_revision，'
            '用自然中文简短复述当前选择，并询问是否确认；不要开始站位指导。',
      'assessment_plan_confirmed' =>
        '客户端已持久化并确认评估项目。请简短说明接下来第一个取景方向，再开始引导用户站位；'
            '不要朗读内部 target。',
      'front_view_required' =>
        '下一个项目需要正面稳定画面。请清楚引导用户自然正对镜头、双肩放松并站稳；'
            '不要让用户猜下一步，也不要要求腿脚完整入镜。',
      'change_orientation' =>
        '第一段已完成。请自然、亲切地引导用户缓慢转换到另一个侧身方向，站稳并目视前方；一次只说一个动作。',
      'assessment_continued' =>
        '用户已明确选择继续评估。请依据事件里的 first_required_view 立即说明第一个站位方向，'
            '并请用户站稳；不要只说“继续评估”，也不要让用户等待下一条指令。',
      'assessment_finalizing' =>
        '用户已通过新的语音回复确认结束。请以 CozyMate 的同一身份简短告知：'
            '结果正在保存，保存完成后我会继续为你解读。不要提及内部模型、角色切换或结果交接，不要自行诊断。',
      'command_rejected' => '客户端拒绝了不符合当前状态或语音轮次的命令。请依据最新事件继续当前步骤，不要声称评估已结束。',
      _ =>
        '最新客户端语义事件为 $eventType。请只依据刚收到的 motion_assessment.event.v4 facts，'
            '只说一句简短、自然、可立即执行的中文语音指导，一次只说一个动作。不要解释原因、复述检测状态、重复鼓励或预告后续动作；'
            '端侧质量门和状态机结论是权威，'
            '不要要求用户触碰屏幕，不要要求腿脚完整入镜。',
    };
  }

  String? _guidanceCoalesceKey(String eventType) {
    return switch (eventType) {
      'assessment_started' ||
      'assessment_plan_updated' ||
      'assessment_plan_confirmed' ||
      'assessment_review_ready' ||
      'assessment_finalizing' ||
      'safety_stop' => null,
      _ => 'assessment-guidance',
    };
  }

  bool _interruptsStaleGuidance(String eventType) {
    return const {
      'person_not_detected',
      'framing_incomplete',
      'multiple_people',
      'target_changed',
      'side_view_required',
      'front_view_required',
      'capture_countdown',
      'change_orientation',
      'opposite_side_required',
      'assessment_resumed_after_reconnect',
    }.contains(eventType);
  }

  void _handleServerEvent(
    RTCDataChannelMessage message,
    int generation,
    MotionRealtimeSessionGate sessionGate,
  ) {
    if (!_isActive(generation)) return;
    if (message.isBinary) return;
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is! Map) return;
      final event = Map<Object?, Object?>.from(decoded);
      final type = decoded['type']?.toString() ?? '';
      final isVisualError = type == 'error' && _isVisualContextError(event);
      sessionGate.handleServerEvent(event);
      unawaited(_handleResponseQueueEvent(event, generation));
      if (type == 'input_audio_buffer.speech_started' &&
          (_playbackStarted != null || _playbackCompleted != null)) {
        _failPlaybackWaiters(
          MotionRealtimeGuidanceException(
            eventType: 'active_guidance',
            failure: MotionRealtimeGuidanceFailure.interruptedByUser,
          ),
        );
      }
      final userAudioItemId = completedUserAudioItemIdFromServerEvent(event);
      if (userAudioItemId != null &&
          _handledUserAudioItemIds.add(userAudioItemId)) {
        _latestCompletedUserAudioItemId = userAudioItemId;
        unawaited(
          _handleCompletedUserAudio(
            userAudioItemId: userAudioItemId,
            generation: generation,
          ),
        );
      }
      final playbackTransition = _playbackTracker.handleEventType(type);
      switch (playbackTransition) {
        case MotionRealtimePlaybackTransition.speaking:
          final started = _playbackStarted;
          if (started != null && !started.isCompleted) started.complete();
          _setPhase(MotionRealtimeVoicePhase.speaking);
        case MotionRealtimePlaybackTransition.listening:
          final started = _playbackStarted;
          final completed = _playbackCompleted;
          if (started?.isCompleted == true &&
              completed != null &&
              !completed.isCompleted) {
            completed.complete();
          }
          _setPhase(MotionRealtimeVoicePhase.listening);
        case null:
          break;
      }
      if (type == 'error' && !isVisualError) {
        _logServerError(event);
      }
      for (final request in motionVisualSnapshotRequestsFromServerEvent(
        event,
      )) {
        if (_handledVisualCallIds.add(request.callId)) {
          unawaited(
            _handleVisualSnapshotRequest(
              request: request,
              generation: generation,
              userAudioItemId:
                  _responseQueue?.activeContextId ??
                  _latestCompletedUserAudioItemId,
            ),
          );
        }
      }
      for (final command in motionVoiceCommandsFromServerEvent(event)) {
        if (_handledCommandCallIds.add(command.callId) && !_commands.isClosed) {
          _commands.add(
            command.withUserAudioItemId(_responseQueue?.activeContextId),
          );
        }
      }
    } on FormatException {
      return;
    }
  }

  Future<void> _handleCompletedUserAudio({
    required String userAudioItemId,
    required int generation,
  }) async {
    await sendClientEvent('user_speech_completed', {
      'user_audio_item_id': userAudioItemId,
      'requires_voice_response': true,
      'dedupe_key': userAudioItemId,
    });
    if (!_isActive(generation)) return;
    final snapshot = _latestAssessmentContext;
    final receivedAt = _latestAssessmentContextReceivedAt;
    final contextAgeMs = receivedAt == null
        ? 0
        : DateTime.now().difference(receivedAt).inMilliseconds;
    final instructions =
        snapshot?.toRealtimeInstructions(contextAgeMs: contextAgeMs) ??
        '自然回应用户刚才的话。当前没有新鲜的端侧姿态事实，不要猜测姿态或推进状态；请等待客户端的新事件。';
    await _enqueueModelTurn(
      instructions,
      generation,
      contextId: userAudioItemId,
    );
  }

  Future<void> _handleVisualSnapshotRequest({
    required MotionVisualSnapshotRequest request,
    required int generation,
    required String? userAudioItemId,
  }) async {
    if (!_isActive(generation)) return;
    final normalizedTurnId = userAudioItemId?.trim() ?? '';
    var submitted = false;
    var unavailableReason = 'visual_context_unavailable';
    try {
      await _serializeInput(() async {
        final firstRequestForTurn = normalizedTurnId.isEmpty
            ? true
            : _visualRequestTurnIds.add(normalizedTurnId);
        if (firstRequestForTurn) {
          final coordinator = visualContextCoordinator;
          final snapshot = _latestAssessmentContext;
          final factory = _eventFactory;
          if (coordinator != null && factory != null) {
            final visual = await coordinator.captureOnDemand(
              reason: request.reason,
              userAudioItemId: normalizedTurnId.isEmpty
                  ? null
                  : normalizedTurnId,
              context: snapshot,
              contextAgeMs: _latestContextAgeMs(),
            );
            if (_isActive(generation) && visual != null) {
              submitted = await _trySendVisualContext(
                assessmentId: factory.assessmentId,
                visual: visual,
              );
              if (!submitted) {
                unavailableReason = 'visual_transport_unavailable';
              }
            } else if (visual == null) {
              unavailableReason = 'no_fresh_single_person_frame';
            }
          }
        } else {
          unavailableReason = 'already_requested_for_turn';
        }
        if (!_isActive(generation)) return;
        await _sendFunctionCallOutput(
          callId: request.callId,
          output: {
            'submitted': submitted,
            'reason': submitted ? request.reason.wireName : unavailableReason,
            'authority': 'advisory',
            'fallback': 'use_latest_semantic_pose_context',
          },
        );
      });
      if (!_isActive(generation)) return;
      final snapshot = _latestAssessmentContext;
      final instructions = snapshot == null
          ? '视觉关键帧当前不可用。请自然回答用户刚才的问题，不要猜测她的姿态，也不要让评估中断。'
          : '${snapshot.toRealtimeInstructions(contextAgeMs: _latestContextAgeMs())}\n'
                '${submitted ? '本轮已提交一张稀疏关键帧作为辅助；' : '本轮没有可用关键帧；'}'
                '端侧语义事实仍然是权威。直接回应用户，不要再次调用 motion_visual_snapshot。';
      await _enqueueModelTurn(
        instructions,
        generation,
        contextId: normalizedTurnId.isEmpty ? null : normalizedTurnId,
      );
    } catch (_) {
      visualContextCoordinator?.recordTransportFailure(disableForSession: true);
      if (_isActive(generation) && !_transportIsUsable) {
        _scheduleTerminalFailure(generation);
      }
    }
  }

  Future<bool> _trySendVisualContext({
    required String assessmentId,
    required MotionVisualContext visual,
  }) async {
    final coordinator = visualContextCoordinator;
    if (coordinator == null ||
        !coordinator.isEnabled ||
        !_visualIsStillSafeToSend(visual)) {
      return false;
    }
    final clientEventId = 'motion-visual-${++_visualEventSequence}';
    if (_visualClientEventIds.length >= 32) {
      _visualClientEventIds.remove(_visualClientEventIds.first);
    }
    _visualClientEventIds.add(clientEventId);
    try {
      await _sendRealtimeEvent(
        motionVisualConversationItemCreate(
          clientEventId: clientEventId,
          assessmentId: assessmentId,
          visual: visual,
        ),
      );
      coordinator.markSent();
      return true;
    } catch (_) {
      _visualClientEventIds.remove(clientEventId);
      coordinator.recordTransportFailure(disableForSession: true);
      return false;
    }
  }

  bool _visualIsStillSafeToSend(MotionVisualContext visual) {
    final context = _latestAssessmentContext;
    if (context == null ||
        context.personCount != 1 ||
        context.multiplePeople ||
        _latestContextAgeMs() > context.freshForMs) {
      return false;
    }
    final revisionGap = context.sequence - visual.stateRevision;
    return revisionGap >= 0 && revisionGap <= 24;
  }

  Future<void> _sendFunctionCallOutput({
    required String callId,
    required Map<String, Object?> output,
  }) {
    return _sendRealtimeEvent({
      'type': 'conversation.item.create',
      'item': {
        'type': 'function_call_output',
        'call_id': callId,
        'output': jsonEncode(output),
      },
    });
  }

  int _latestContextAgeMs() {
    final receivedAt = _latestAssessmentContextReceivedAt;
    if (receivedAt == null) return 1 << 31;
    return DateTime.now()
        .difference(receivedAt)
        .inMilliseconds
        .clamp(0, 1 << 31);
  }

  bool _isVisualContextError(Map<Object?, Object?> event) {
    if (!motionRealtimeErrorTargetsVisualContext(
      event,
      pendingVisualEventIds: _visualClientEventIds,
    )) {
      return false;
    }
    visualContextCoordinator?.recordTransportFailure(disableForSession: true);
    return true;
  }

  Future<void> _handleResponseQueueEvent(
    Map<Object?, Object?> event,
    int generation,
  ) async {
    try {
      await _responseQueue?.handleServerEvent(event);
    } catch (_) {
      _scheduleTerminalFailure(generation);
    }
  }

  Future<void> _enqueueModelTurn(
    String instructions,
    int generation, {
    String? contextId,
  }) async {
    try {
      await _responseQueue?.enqueueModelTurn(
        instructions,
        contextId: contextId,
      );
    } catch (_) {
      _scheduleTerminalFailure(generation);
    }
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peer) async {
    if (peer.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    peer.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
  }

  Future<void> _configureRemoteAudio(
    RTCTrackEvent event,
    int generation,
    MotionRealtimeSessionGate sessionGate,
  ) async {
    event.track.enabled = true;
    _remoteAudioTrackReady = true;
    if (event.streams.isNotEmpty) _remoteAudioStream = event.streams.first;
    try {
      await Helper.setVolume(1, event.track);
      await Helper.setSpeakerphoneOnButPreferBluetooth();
    } catch (_) {
      // The WebRTC engine still owns playout; routing can recover on the next
      // platform audio-device change.
    }
    if (_isActive(generation)) sessionGate.markRemoteAudioTrackReady();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connectionGeneration += 1;
    await _closeResources();
    _setPhase(MotionRealtimeVoicePhase.closed);
  }

  Future<void> _closeResources() async {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    final channel = _dataChannel;
    final peer = _peerConnection;
    final stream = _microphoneStream;
    final responseQueue = _responseQueue;
    final sessionGate = _sessionGate;
    final deactivateAudioSession = _audioSessionActive;
    _dataChannel = null;
    _peerConnection = null;
    _microphoneStream = null;
    _remoteAudioStream = null;
    _remoteAudioTrackReady = false;
    _responseQueue = null;
    _sessionGate = null;
    _audioSessionActive = false;
    visualContextCoordinator?.setServerCapability(false);
    _visualClientEventIds.clear();
    _playbackTracker.reset();
    _failPlaybackWaiters(
      StateError('Realtime voice connection was closed during playback.'),
    );
    sessionGate?.fail(StateError('Realtime voice connection was closed.'));
    if (stream != null) await _disposeStream(stream);
    await responseQueue?.close();
    if (channel != null) await channel.close();
    if (peer != null) {
      await peer.close();
      await peer.dispose();
    }
    if (deactivateAudioSession) {
      try {
        await audioSession.deactivate();
      } catch (_) {
        // Native audio focus release remains best effort during teardown.
      }
    }
  }

  void _failPlaybackWaiters(Object error) {
    final started = _playbackStarted;
    final completed = _playbackCompleted;
    final playbackHadStarted = started?.isCompleted == true;
    if (started != null && !started.isCompleted) started.completeError(error);
    if (completed != null && !completed.isCompleted && playbackHadStarted) {
      completed.completeError(error);
    } else if (completed != null && !completed.isCompleted) {
      completed.complete();
    }
  }

  Future<void> _sendRealtimeEvent(Map<String, Object?> event) async {
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('Realtime data channel is not open.');
    }
    await channel!.send(RTCDataChannelMessage(jsonEncode(event)));
  }

  bool get _transportIsUsable =>
      !_disposed &&
      !_closed &&
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;

  void _logServerError(Map<Object?, Object?> event) {
    final rawError = event['error'];
    final error = rawError is Map
        ? Map<Object?, Object?>.from(rawError)
        : const <Object?, Object?>{};
    final code = error['code']?.toString() ?? 'unknown';
    final type = error['type']?.toString() ?? 'unknown';
    final clientEventId =
        error['event_id']?.toString() ?? event['event_id']?.toString() ?? '';
    debugPrint(
      'Motion Realtime server event error: type=$type code=$code '
      'client_event_id=${clientEventId.isEmpty ? 'none' : clientEventId}.',
    );
  }

  Future<T> _serializeInput<T>(Future<T> Function() operation) {
    final result = _inputOperations.then((_) => operation());
    _inputOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _scheduleTerminalFailure(int generation) {
    if (!_isActive(generation) || _terminalCleanup != null) return;
    _connectionGeneration += 1;
    late final Future<void> cleanup;
    cleanup = _closeResources().whenComplete(() {
      if (identical(_terminalCleanup, cleanup)) _terminalCleanup = null;
    });
    _terminalCleanup = cleanup;
    _setPhase(MotionRealtimeVoicePhase.failed);
  }

  Future<void> _disposeStream(MediaStream stream) async {
    for (final track in stream.getTracks()) {
      await track.stop();
    }
    await stream.dispose();
  }

  void _setPhase(MotionRealtimeVoicePhase value) {
    if (_disposed || _phase == value) return;
    _phase = value;
    notifyListeners();
  }

  bool _isActive(int generation) {
    return !_disposed && !_closed && generation == _connectionGeneration;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _closed = true;
    _connectionGeneration += 1;
    unawaited(_closeResources());
    unawaited(_commands.close());
    super.dispose();
  }
}
