import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/agent_voice_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/fake_video_player_platform.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() => VideoPlayerPlatform.instance = FakeVideoPlayerPlatform());
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('voice states $width/$scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyAgentVoice(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/agent-voice-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }

  testWidgets('voice error remains usable above a keyboard at 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final player = FailedGreetingPlayer();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: AgentHubPage(
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    player.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/agent-voice-keyboard-320-2x.png',
      ),
    );
    await tester.tap(find.byTooltip('\u5173\u95ed\u8bed\u97f3\u63d0\u793a'));
    await tester.pumpAndSettle();
    expect(find.text('\u64ad\u653e\u56de\u590d'), findsNothing);
  });
  testWidgets('synchronous player setup failure is recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHubPage(
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: SynchronousFailurePlayer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('\u64ad\u653e\u56de\u590d'), findsOneWidget);
  });
  testWidgets('failed greeting exposes a recoverable voice notice', (
    tester,
  ) async {
    final player = FailedGreetingPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentHubPage(
            voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
            voicePlaybackPlayer: player,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    player.pending.completeError(StateError('private service failure'));
    await tester.pumpAndSettle();
    expect(find.text('播放回复'), findsOneWidget);
    expect(find.textContaining('private service failure'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class FailedGreetingPlayer implements AgentVoicePlaybackPlayer {
  final pending = Completer<void>();
  @override
  Future<void> playText(String text) => pending.future;
  @override
  Future<void> stop() async {}
  @override
  AgentVoiceRealtimePlaybackSession startRealtimeSession({
    AgentVoiceMediaNarrationResolver? mediaNarrationResolver,
  }) => throw UnimplementedError();
}

class SynchronousFailurePlayer extends FailedGreetingPlayer {
  @override
  Future<void> playText(String text) => throw StateError('player unavailable');
}
