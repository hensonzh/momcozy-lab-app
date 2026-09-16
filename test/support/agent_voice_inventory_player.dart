import 'dart:async';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

/// Controlled audio boundary. The App's coordinator and visible state are real.
class InventoryVoicePlayer implements AgentVoicePlaybackPlayer {
  final texts = <String>[];
  final plays = <Completer<void>>[];
  final sessions = <InventoryVoiceSession>[];
  int stops = 0;
  @override
  Future<void> playText(String text) {
    texts.add(text);
    final play = Completer<void>();
    plays.add(play);
    return play.future;
  }

  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession({
    AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  }) {
    final session = InventoryVoiceSession();
    sessions.add(session);
    return session;
  }

  @override
  Future<void> stop() async {
    stops++;
    for (final play in plays) {
      if (!play.isCompleted) play.complete();
    }
    for (final session in sessions) {
      await session.cancel();
    }
  }
}

class InventoryVoiceSession implements AgentVoiceRealtimePlaybackSession {
  final completion = Completer<void>();
  String text = '';
  bool cancelled = false;
  bool finished = false;
  @override
  Future<void> get done => completion.future;
  @override
  void append(String delta) => text += delta;
  @override
  void flush() {}
  @override
  void finish() => finished = true;
  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!completion.isCompleted) completion.complete();
  }

  void fail() {
    if (!completion.isCompleted) {
      completion.completeError(StateError('isolated failure'));
    }
  }
}
