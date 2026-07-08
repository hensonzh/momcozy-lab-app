import 'dart:async';

import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/voice_api.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

const defaultAgentVoicePcmPlayerChannelName =
    'com.momcozymai.flutter/voice_pcm_player';

abstract interface class AgentVoicePcmPlayer {
  Future<void> start({int sampleRate, int channels});

  Future<void> write(List<int> bytes);

  Future<void> stop();
}

class MethodChannelAgentVoicePcmPlayer implements AgentVoicePcmPlayer {
  MethodChannelAgentVoicePcmPlayer({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel(defaultAgentVoicePcmPlayerChannelName);

  final MethodChannel _channel;

  @override
  Future<void> start({int sampleRate = 24000, int channels = 1}) async {
    await _channel.invokeMethod<void>('start', {
      'sampleRate': sampleRate,
      'channels': channels,
    });
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (bytes.isEmpty) return;
    await _channel.invokeMethod<void>('write', {
      'bytes': Uint8List.fromList(bytes),
    });
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }
}

class AgentVoiceApiPlaybackPlayer implements AgentVoicePlaybackPlayer {
  AgentVoiceApiPlaybackPlayer({
    required this.repository,
    AgentVoicePcmPlayer? pcmPlayer,
    this.sampleRate = 24000,
    this.channels = 1,
  }) : pcmPlayer = pcmPlayer ?? MethodChannelAgentVoicePcmPlayer();

  final AgentVoiceRepository repository;
  final AgentVoicePcmPlayer pcmPlayer;
  final int sampleRate;
  final int channels;
  int _playToken = 0;

  @override
  Future<void> playText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final token = ++_playToken;
    await pcmPlayer.start(sampleRate: sampleRate, channels: channels);
    try {
      await for (final chunk in repository.realtimeVoicePcmStream(
        text: normalized,
      )) {
        if (token != _playToken) break;
        await pcmPlayer.write(chunk);
      }
    } finally {
      if (token == _playToken) {
        await pcmPlayer.stop();
      }
    }
  }

  @override
  Future<void> stop() async {
    _playToken += 1;
    await pcmPlayer.stop();
  }
}
