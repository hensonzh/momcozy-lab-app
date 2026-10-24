@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_audio.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_poop_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_cry_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_poop_task.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets('quiet conversation task cards at 390', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFAF7),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ChatFirstCryTaskCard(
                  status: ChatFirstCryTaskStatus.pending,
                  onStart: () {},
                  onAbandon: () {},
                ),
                const SizedBox(height: 16),
                ChatFirstPoopTaskCard(
                  status: ChatFirstPoopTaskStatus.pending,
                  canInteract: false,
                  canSubmit: false,
                  availabilityMessage: '审核服务尚未开放，请稍后再试。',
                  onPick: (_) {},
                  onSubmit: () {},
                  onRemove: (_) {},
                  onAbandon: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('录音仅用于本机试听'), findsNothing);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/chat_first/task-cards-390.png'),
    );
  });
  testWidgets('verified cry result card shows the cause only at 390', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFAF7),
          body: const Padding(
            padding: EdgeInsets.all(16),
            child: ChatFirstCryResultCard(answer: 'sleep', incomplete: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('可能和想休息有关'), findsOneWidget);
    expect(find.text('哭声背后的原因'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('chat-first-cry-result-card')),
      matchesGoldenFile('../../goldens/chat_first/cry-result-390.png'),
    );
  });

  testWidgets('cry preview uses the Demo player hierarchy at 390', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ChatFirstCryTaskController(() => _PreviewAudio());
    addTearDown(() async => controller.release());
    await controller.start();
    await controller.stop();
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: Scaffold(
          backgroundColor: const Color(0xFFFFFAF7),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatFirstCryTaskCard(
                  status: ChatFirstCryTaskStatus.pending,
                  controller: controller,
                  onStart: () {},
                  onAbandon: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-first-cry-seek')), findsOneWidget);
    expect(find.textContaining('录音仅用于本机试听'), findsNothing);
    expect(find.text('上传并分析'), findsOneWidget);
    await expectLater(
      find.byKey(const ValueKey('chat-first-topic-cry')),
      matchesGoldenFile('../../goldens/chat_first/cry-preview-390.png'),
    );
  });
}

class _PreviewAudio implements ChatFirstCryAudioSession {
  @override
  Future<List<int>> readRecording() async => <int>[];

  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Future<void> start() async {}
  @override
  Future<Duration> stop() async => const Duration(seconds: 8);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<void> dispose() async {}
}
