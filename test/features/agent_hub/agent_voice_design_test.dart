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
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

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
    final player = VoiceFixturePlayer();
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
    player.plays.last.completeError(StateError('offline'));
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
    final replay = find.widgetWithText(TextButton, '播放回复');
    final dismiss = find.byTooltip('关闭语音提示');
    expect(tester.getSize(replay).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(dismiss).shortestSide, greaterThanOrEqualTo(44));
    expect(tester.getBottomRight(replay).dy, lessThanOrEqualTo(544));
    await tester.tap(replay);
    await tester.pumpAndSettle();
    expect(player.texts, hasLength(2));
    expect(find.text('播放回复'), findsNothing);
    player.plays.last.completeError(StateError('offline again'));
    await tester.pumpAndSettle();
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
  for (final width in [390.0, 320.0]) {
    final scale = width == 320 ? 2.0 : 1.0;
    testWidgets('greeting playback and replay indicator $width/$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final player = VoiceFixturePlayer();
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
            body: AgentHubPage(
              voicePlaybackCoordinator: AgentVoicePlaybackCoordinator(),
              voicePlaybackPlayer: player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(MomCozyAssets.agentAvatar),
          tester.element(find.byType(AgentHubPage)),
        ),
      );
      await tester.pumpAndSettle();
      final indicator = find.byKey(
        const ValueKey('agent-assistant-avatar-speaking'),
      );
      expect(indicator, findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-voice-greeting-playing-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      player.plays.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      await tester.tap(find.text('播放回复'));
      await tester.pumpAndSettle();
      expect(player.texts, hasLength(2));
      expect(player.texts.last, player.texts.first);
      expect(indicator, findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/agent-voice-greeting-replaying-${width.toInt()}-${scale.toInt()}x.png',
        ),
      );
      player.plays.last.complete();
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
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
