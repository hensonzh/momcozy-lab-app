import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_avatar.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_workspace.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';

void main() {
  test('2D companion reacts without claiming audio-aligned speech', () {
    var clock = DateTime(2026, 10, 15, 10);
    final controller = ChatFirstAvatarController(now: () => clock);
    expect(controller.mode, ChatFirstAvatarMode.idle);
    expect(controller.hasSpeechTrack, isFalse);
    controller.signal('request-start');
    expect(controller.mode, ChatFirstAvatarMode.thinking);
    controller.signal('reply-chunk');
    expect(controller.mode, ChatFirstAvatarMode.replying);
    controller.signal('reply-done');
    expect(controller.mode, ChatFirstAvatarMode.happy);
    clock = clock.add(const Duration(seconds: 2));
    expect(controller.mode, ChatFirstAvatarMode.idle);
    controller.signal('request-error');
    expect(controller.mode, ChatFirstAvatarMode.concern);
    controller.signal('request-end');
    expect(controller.hasSpeechTrack, isFalse);
    controller.dispose();
  });

  testWidgets(
    'reduced motion keeps the original still illustration and no face paint',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: ChatFirstWorkspace(
                runtime: null,
                role: null,
                onOpenDrawer: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat-first-avatar-paint')),
        findsNothing,
      );
      expect(find.byType(Image), findsWidgets);
    },
  );

  testWidgets(
    'iOS reduce motion flag stops the 2D face, including after a toggle',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(disableAnimations: false),
              child: ChatFirstWorkspace(
                runtime: null,
                role: null,
                onOpenDrawer: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chat-first-avatar-paint')),
        findsNothing,
      );
      expect(find.byType(Image), findsWidgets);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await tester.pump();
      await _waitForScene(tester);
      expect(
        find.byKey(const ValueKey('chat-first-avatar-paint')),
        findsOneWidget,
      );

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat-first-avatar-paint')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('normal motion paints only the existing 2D illustration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: false),
            child: ChatFirstWorkspace(
              runtime: null,
              role: null,
              onOpenDrawer: _noop,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Engine image decoding completes outside FakeAsync. Wait for the real
    // decoded frame, rather than assuming pumpAndSettle awaits native codecs.
    await _waitForScene(tester);
    expect(
      find.byKey(const ValueKey('chat-first-avatar-paint')),
      findsOneWidget,
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('chat-first-avatar-paint')),
                )
                .painter!
            as ChatFirstAvatarPainter;
    expect((painter.image.width, painter.image.height), (1848, 851));
    expect(
      find.byKey(const ValueKey('chat-first-avatar-greet')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('turning reduced motion on and off swaps still and 2D scene', (
    tester,
  ) async {
    Widget app(bool reduced) => MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: const ChatFirstWorkspace(
            runtime: null,
            role: null,
            onOpenDrawer: _noop,
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await _waitForScene(tester);
    expect(
      find.byKey(const ValueKey('chat-first-avatar-paint')),
      findsOneWidget,
    );
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-first-avatar-paint')), findsNothing);
    expect(find.byType(Image), findsWidgets);
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('chat-first-avatar-paint')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'chat activity drives subtle 2D reaction states, never audio motion',
    (tester) async {
      final avatar = ChatFirstAvatarController();
      Widget app(AgentStreamRunState state) => MaterialApp(
        home: Scaffold(
          body: ChatFirstAvatarScope(
            controller: avatar,
            child: AgentHubPage(chatFirstExperience: true, state: state),
          ),
        ),
      );
      await tester.pumpWidget(app(const AgentStreamRunState()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chat-first-action-cry')));
      await tester.pump();
      expect(avatar.mode, ChatFirstAvatarMode.happy);
      await tester.pumpWidget(
        app(const AgentStreamRunState(phase: AgentStreamRunPhase.streaming)),
      );
      await tester.pump();
      expect(avatar.mode, ChatFirstAvatarMode.thinking);
      await tester.pumpWidget(
        app(
          const AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            textContent: '回复已完成',
          ),
        ),
      );
      await tester.pump();
      expect(avatar.mode, ChatFirstAvatarMode.happy);
      expect(avatar.hasSpeechTrack, isFalse);
      await tester.pumpWidget(const SizedBox());
      avatar.dispose();
    },
  );
}

void _noop() {}

Future<void> _waitForScene(WidgetTester tester) => tester.runAsync(() async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump();
    if (find
        .byKey(const ValueKey('chat-first-avatar-paint'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
});
