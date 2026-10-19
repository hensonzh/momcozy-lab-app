import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/chat_first_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_workspace.dart';

class _Player implements ChatFirstPcmPlayer {
  int stops = 0;
  @override
  Future<void> start() async {}
  @override
  Future<void> write(Uint8List bytes) async {}
  @override
  Future<void> finish() async {}
  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  testWidgets(
    'enabled voice button toggles playback without replaying history',
    (tester) async {
      final player = _Player();
      final voice = ChatFirstVoiceController(
        baseUri: Uri.parse('http://127.0.0.1:1'),
        tokenProvider: () => 'token',
        player: player,
      )..available = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstVoiceScope(
              controller: voice,
              child: const ChatFirstWorkspace(
                runtime: null,
                role: null,
                onOpenDrawer: _noop,
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('关闭语音播放'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('chat-first-voice-toggle')));
      await tester.pump();
      expect(find.byTooltip('开启语音播放'), findsOneWidget);
      expect(player.stops, greaterThan(0));
      voice.dispose();
    },
  );
}

void _noop() {}
