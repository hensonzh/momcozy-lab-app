import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

class ImmediateAgentVoicePlaybackPlayer implements AgentVoicePlaybackPlayer {
  const ImmediateAgentVoicePlaybackPlayer();

  @override
  Future<void> playText(String text) async {}

  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession() {
    return const ImmediateAgentVoiceRealtimePlaybackSession();
  }

  @override
  Future<void> stop() async {}
}

class ImmediateAgentVoiceRealtimePlaybackSession
    implements AgentVoiceRealtimePlaybackSession {
  const ImmediateAgentVoiceRealtimePlaybackSession();

  @override
  Future<void> get done => Future<void>.value();

  @override
  void append(String delta) {}

  @override
  Future<void> cancel() async {}

  @override
  void finish() {}

  @override
  void flush() {}
}
