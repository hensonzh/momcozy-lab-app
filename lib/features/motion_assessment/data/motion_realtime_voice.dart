import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_realtime_response_queue.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/data/motion_voice_signaling.dart';
import 'package:momcozy_flutter_app/features/motion_assessment/domain/motion_assessment_context.dart';
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
  Stream<MotionVoiceCommand> get commands;

  Future<void> connect({required String assessmentId});
  Future<void> speak(String instruction, {bool interrupt = false});
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
  MotionRealtimeVoice({required this.signaling});

  final MotionVoiceSignaling signaling;

  MotionRealtimeVoicePhase _phase = MotionRealtimeVoicePhase.idle;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _microphoneStream;
  MotionRealtimeResponseQueue? _responseQueue;
  final StreamController<MotionVoiceCommand> _commands =
      StreamController<MotionVoiceCommand>.broadcast();
  final Set<String> _handledCommandCallIds = {};
  final Set<String> _handledUserAudioItemIds = {};
  MotionAssessmentContextSnapshot? _latestAssessmentContext;
  DateTime? _latestAssessmentContextReceivedAt;
  int _connectionGeneration = 0;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _terminalCleanup;

  @override
  MotionRealtimeVoicePhase get phase => _phase;
  @override
  bool get isConnected =>
      _phase == MotionRealtimeVoicePhase.listening ||
      _phase == MotionRealtimeVoicePhase.speaking;
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
    final generation = ++_connectionGeneration;
    _setPhase(MotionRealtimeVoicePhase.requestingPermission);
    try {
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
        await peer.addTrack(track, stream);
      }
      peer.onConnectionState = (state) {
        if (!_isActive(generation)) return;
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _setPhase(MotionRealtimeVoicePhase.listening);
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _setPhase(MotionRealtimeVoicePhase.reconnecting);
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _scheduleTerminalFailure(generation);
          default:
            break;
        }
      };
      peer.onTrack = (event) {
        if (event.track.kind == 'audio') {
          unawaited(Helper.setSpeakerphoneOnButPreferBluetooth());
        }
      };
      final channel = await peer.createDataChannel(
        'oai-events',
        RTCDataChannelInit()..ordered = true,
      );
      final dataChannelReady = Completer<void>();
      _dataChannel = channel;
      _responseQueue = MotionRealtimeResponseQueue(
        sendEvent: _sendRealtimeEvent,
      );
      channel.onDataChannelState = (state) {
        if (!_isActive(generation)) return;
        if (state == RTCDataChannelState.RTCDataChannelOpen) {
          if (!dataChannelReady.isCompleted) dataChannelReady.complete();
          _setPhase(MotionRealtimeVoicePhase.listening);
        }
      };
      channel.onMessage = (message) => _handleServerEvent(message, generation);

      final offer = await peer.createOffer({'offerToReceiveAudio': true});
      await peer.setLocalDescription(offer);
      await _waitForIceGathering(peer);
      final local = await peer.getLocalDescription();
      final offerSdp = local?.sdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        throw StateError('WebRTC did not produce a local SDP offer.');
      }
      final answerSdp = await signaling.createAnswer(
        assessmentId: assessmentId,
        offerSdp: offerSdp,
      );
      if (!_isActive(generation)) return;
      await peer.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );
      if (channel.state != RTCDataChannelState.RTCDataChannelOpen) {
        await dataChannelReady.future.timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      if (_isActive(generation)) {
        _setPhase(MotionRealtimeVoicePhase.failed);
        await _closeResources();
      }
      rethrow;
    }
  }

  @override
  Future<void> speak(String instruction, {bool interrupt = false}) async {
    await _responseQueue?.enqueue(instruction, interrupt: interrupt);
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
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    final content = jsonEncode({
      'event_type': eventType,
      'payload': payload,
      'source': 'on_device_pose_gate',
    });
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
  }

  @override
  Future<void> completeCommand(
    MotionVoiceCommand command, {
    required bool accepted,
    required String message,
    bool speakResult = true,
  }) async {
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
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
  }

  void _handleServerEvent(RTCDataChannelMessage message, int generation) {
    if (!_isActive(generation)) return;
    if (message.isBinary) return;
    try {
      final decoded = jsonDecode(message.text);
      if (decoded is! Map) return;
      final event = Map<Object?, Object?>.from(decoded);
      final type = decoded['type']?.toString() ?? '';
      unawaited(_responseQueue?.handleServerEvent(event));
      if (type == 'input_audio_buffer.speech_started') {
        unawaited(_responseQueue?.interrupt());
      }
      final userAudioItemId = completedUserAudioItemIdFromServerEvent(event);
      if (userAudioItemId != null &&
          _handledUserAudioItemIds.add(userAudioItemId)) {
        final snapshot = _latestAssessmentContext;
        final receivedAt = _latestAssessmentContextReceivedAt;
        final contextAgeMs = receivedAt == null
            ? 0
            : DateTime.now().difference(receivedAt).inMilliseconds;
        final instructions =
            snapshot?.toRealtimeInstructions(contextAgeMs: contextAgeMs) ??
            '请简短回答用户刚才的问题。当前没有新鲜的端侧姿态语义快照，因此不要猜测用户姿态；请提示用户保持单人全身入镜，等待本地质量门重新确认。';
        unawaited(_responseQueue?.enqueueModelTurn(instructions));
      }
      if (type == 'response.audio.delta' ||
          type == 'response.output_audio.delta') {
        _setPhase(MotionRealtimeVoicePhase.speaking);
      } else if (type == 'response.done' ||
          type == 'response.audio.done' ||
          type == 'response.output_audio.done') {
        _setPhase(MotionRealtimeVoicePhase.listening);
      } else if (type == 'error') {
        _scheduleTerminalFailure(generation);
      }
      for (final command in motionVoiceCommandsFromServerEvent(event)) {
        if (_handledCommandCallIds.add(command.callId) && !_commands.isClosed) {
          _commands.add(command);
        }
      }
    } on FormatException {
      return;
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

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connectionGeneration += 1;
    await _closeResources();
    _setPhase(MotionRealtimeVoicePhase.closed);
  }

  Future<void> _closeResources() async {
    final channel = _dataChannel;
    final peer = _peerConnection;
    final stream = _microphoneStream;
    final responseQueue = _responseQueue;
    _dataChannel = null;
    _peerConnection = null;
    _microphoneStream = null;
    _responseQueue = null;
    if (stream != null) await _disposeStream(stream);
    await responseQueue?.close();
    if (channel != null) await channel.close();
    if (peer != null) {
      await peer.close();
      await peer.dispose();
    }
  }

  Future<void> _sendRealtimeEvent(Map<String, Object?> event) async {
    final channel = _dataChannel;
    if (channel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    await channel!.send(RTCDataChannelMessage(jsonEncode(event)));
  }

  void _scheduleTerminalFailure(int generation) {
    if (!_isActive(generation) || _terminalCleanup != null) return;
    _setPhase(MotionRealtimeVoicePhase.failed);
    _connectionGeneration += 1;
    late final Future<void> cleanup;
    cleanup = _closeResources().whenComplete(() {
      if (identical(_terminalCleanup, cleanup)) _terminalCleanup = null;
    });
    _terminalCleanup = cleanup;
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
