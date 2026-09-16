import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Future<void> verifyAgentVoice(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final player = VoiceFixturePlayer();
  final client = VoiceFixtureClient();
  addTearDown(client.dispose);
  final coordinator = AgentVoicePlaybackCoordinator();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: AgentHubPage(
            runner: AgentStreamRunner(client),
            voicePlaybackCoordinator: coordinator,
            voicePlaybackPlayer: player,
          ),
        ),
      ),
    ),
  );
  Future<void> frame() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  }

  await frame();
  final context = tester.element(find.byType(Scaffold).first);
  await tester.runAsync(
    () => precacheImage(const AssetImage(MomCozyAssets.agentAvatar), context),
  );
  await frame();
  expect(player.texts, hasLength(1));
  player.plays.last.completeError(StateError('internal endpoint secret'));
  await tester.pumpAndSettle();
  expect(find.text('播放回复'), findsOneWidget);
  expect(find.textContaining('internal endpoint secret'), findsNothing);
  await capture('greeting-error');
  await tester.tap(find.text('播放回复'));
  await frame();
  expect(player.texts, hasLength(2));
  expect(player.texts.last, player.texts.first);
  expect(client.requests, isEmpty);
  expect(find.text('播放回复'), findsNothing);
  player.plays.last.completeError(StateError('offline'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('关闭语音提示'));
  await tester.pumpAndSettle();
  expect(find.text('播放回复'), findsNothing);
  await capture('dismissed');
  // A new typed request clears stale errors and keeps the normal stream contract.
  await tester.enterText(
    find.byKey(const ValueKey('agent-composer-input')),
    'Please read this reply.',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('agent-send-button')));
  await frame();
  expect(client.requests, hasLength(1));
  client.emit('message.delta', 1, {'text': 'One observation at a time.'});
  await frame();
  expect(player.sessions, hasLength(1));
  player.sessions.last.fail();
  await frame();
  expect(find.text('播放回复'), findsOneWidget);
  final replay = find.widgetWithText(TextButton, '播放回复');
  expect(tester.widget<TextButton>(replay).onPressed, isNull);
  await capture('stream-error');
  client.emit('message.completed', 2, {'text': 'One observation at a time.'});
  client.emit('run.completed', 3, {});
  await tester.pumpAndSettle();
  expect(tester.widget<TextButton>(replay).onPressed, isNotNull);
  await capture('reply-error');
  await tester.tap(replay);
  await frame();
  expect(player.sessions, hasLength(2));
  expect(player.sessions.last.text, 'One observation at a time.');
  expect(client.requests, hasLength(1));
  expect(find.text('播放回复'), findsNothing);
  await tester.tap(find.byKey(const ValueKey('agent-auto-voice-button')));
  await tester.pumpAndSettle();
  expect(player.sessions.last.cancelled, isTrue);
  expect(find.byTooltip('开启实时语音播报'), findsOneWidget);
  await capture('off');
  await tester.tap(find.byKey(const ValueKey('agent-auto-voice-button')));
  await tester.pumpAndSettle();
  expect(find.byTooltip('关闭实时语音播报'), findsOneWidget);
  expect(player.sessions, hasLength(2));
  await capture('on');
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

class VoiceFixturePlayer implements AgentVoicePlaybackPlayer {
  final texts = <String>[];
  final plays = <Completer<void>>[];
  final sessions = <VoiceFixtureSession>[];
  @override
  Future<void> playText(String text) {
    texts.add(text);
    final p = Completer<void>();
    plays.add(p);
    return p.future;
  }

  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession({
    AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  }) {
    final s = VoiceFixtureSession();
    sessions.add(s);
    return s;
  }

  @override
  Future<void> stop() async {
    for (final p in plays) {
      if (!p.isCompleted) p.complete();
    }
    for (final s in sessions) {
      await s.cancel();
    }
  }
}

class VoiceFixtureSession implements AgentVoiceRealtimePlaybackSession {
  final completion = Completer<void>();
  String text = '';
  bool cancelled = false;
  @override
  Future<void> get done => completion.future;
  @override
  void append(String delta) {
    text += delta;
  }

  @override
  void flush() {}
  @override
  void finish() {}
  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!completion.isCompleted) completion.complete();
  }

  void fail() {
    if (!completion.isCompleted) {
      completion.completeError(StateError('offline'));
    }
  }
}

class VoiceFixtureClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final controller = StreamController<AgentStreamEvent>();
  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    return controller.stream;
  }

  void emit(String type, int sequence, Map<String, Object?> payload) {
    controller.add(
      AgentStreamEvent({
        'event_id': 'voice-$sequence',
        'type': type,
        'thread_id': 'voice-thread',
        'run_id': 'voice-run',
        'message_id': 'voice-message',
        'sequence': sequence,
        'payload': payload,
      }),
    );
  }

  Future<void> dispose() => controller.close();
}
