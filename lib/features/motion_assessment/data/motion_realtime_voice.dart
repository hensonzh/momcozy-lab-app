import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_audio_session.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_playback_tracker.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_response_queue.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_session_gate.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';
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
  }) : audioSession = audioSession ?? WebRtcMotionRealtimeAudioSession();

  final MotionVoiceSignaling signaling;
  final MotionRealtimeAudioSession audioSession;

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
  final MotionAssessmentEventGate _eventGate = MotionAssessmentEventGate();
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
  String? _protectedPlaybackEventType;

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
            _disconnectTimer = Timer(const Duration(seconds: 2), () {
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
  }) async {
    if (!isConnected) {
      throw StateError('Realtime voice is not connected.');
    }
    final normalizedEventType = eventType.trim();
    if (normalizedEventType.isEmpty) return;
    final shouldWaitForStart = awaitPlaybackStart || awaitPlaybackCompletion;
    final started = shouldWaitForStart ? Completer<void>() : null;
    final completed = awaitPlaybackCompletion ? Completer<void>() : null;
    if (started != null) {
      if (_playbackStarted != null || _playbackCompleted != null) {
        throw StateError('Another Realtime guidance turn is awaiting audio.');
      }
      _playbackStarted = started;
      _playbackCompleted = completed;
    }
    final protectsFinishHandshake =
        normalizedEventType == 'assessment_review_ready';
    if (protectsFinishHandshake) {
      _protectedPlaybackEventType = normalizedEventType;
    }
    try {
      if (interrupt) await _responseQueue?.interrupt();
      final published = await _publishClientEvent(normalizedEventType, payload);
      if (!published) return;
      await _responseQueue?.enqueueModelTurn(
        _guidanceTurnInstructions(normalizedEventType),
      );
      if (started != null) {
        await started.future.timeout(const Duration(seconds: 10));
      }
      if (completed != null) {
        await completed.future.timeout(const Duration(seconds: 20));
      }
    } catch (_) {
      _scheduleTerminalFailure(_connectionGeneration);
      rethrow;
    } finally {
      if (identical(_playbackStarted, started)) _playbackStarted = null;
      if (identical(_playbackCompleted, completed)) _playbackCompleted = null;
      if (protectsFinishHandshake &&
          _protectedPlaybackEventType == normalizedEventType) {
        _protectedPlaybackEventType = null;
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
      await channel!.send(
        RTCDataChannelMessage(
          jsonEncode({
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': 'user',
              'content': [
                {'type': 'input_text', 'text': '[客户端姿态事件]$content'},
              ],
            },
          }),
        ),
      );
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
              'output': jsonEncode({'accepted': accepted, 'message': message}),
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
      'assessment_review_ready' =>
        '客户端已完成两段采集与质量复核。请用一句自然中文说明采集已完成，并明确询问用户：'
            '“你想结束本次评估，还是继续评估？”说完后等待用户新的语音回复，不要自行结束。',
      'change_orientation' =>
        '第一段已完成。请自然、亲切地引导用户缓慢转换到另一个侧身方向，站稳并目视前方；一次只说一个动作。',
      'assessment_finalizing' =>
        '用户已通过新的语音回复确认结束。请简短告知结果正在保存，稍后由主智能体反馈；不要自行诊断。',
      'command_rejected' => '客户端拒绝了不符合当前状态或语音轮次的命令。请依据最新事件继续当前步骤，不要声称评估已结束。',
      _ =>
        '最新客户端语义事件为 $eventType。请只依据刚收到的 motion_assessment.event.v4 facts，'
            '主动给出一句简短、自然、可立即执行的中文语音指导。一次只说一个动作；端侧质量门和状态机结论是权威，'
            '不要要求用户触碰屏幕，不要要求腿脚完整入镜。',
    };
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
      sessionGate.handleServerEvent(event);
      unawaited(_handleResponseQueueEvent(event, generation));
      if (type == 'input_audio_buffer.speech_started' &&
          _protectedPlaybackEventType == null) {
        unawaited(_interruptResponseQueue(generation));
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
      if (type == 'error') {
        _scheduleTerminalFailure(generation);
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

  Future<void> _interruptResponseQueue(int generation) async {
    try {
      await _responseQueue?.interrupt();
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
