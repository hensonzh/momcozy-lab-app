import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

void main() {
  testWidgets('historic assistant text using the former brand is replaced', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentHubHistoryPanel(
              messages: [
                AgentHubHistoryMessage(
                  role: AgentHubHistoryRole.user,
                  content: '宝宝晚上不肯吃奶',
                ),
                AgentHubHistoryMessage(
                  role: AgentHubHistoryRole.assistant,
                  content: '先联系 Cozymate。',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('宝宝晚上不肯吃奶'), findsOneWidget);
    expect(find.textContaining('先联系'), findsNothing);
    expect(find.textContaining('Cozymate'), findsNothing);
    expect(find.textContaining('outdated name'), findsOneWidget);
  });

  testWidgets(
    'historic Chinese assistant reply is visible without changing user text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentHubHistoryPanel(
                messages: [
                  AgentHubHistoryMessage(
                    role: AgentHubHistoryRole.user,
                    content: '我的乳房有点疼',
                  ),
                  AgentHubHistoryMessage(
                    role: AgentHubHistoryRole.assistant,
                    content: '先确认是否有发热。',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('我的乳房有点疼'), findsOneWidget);
      expect(find.textContaining('先确认是否有发热'), findsOneWidget);
      expect(find.textContaining('not available in English'), findsNothing);
    },
  );

  testWidgets('assistant replies in other languages remain visible', (
    tester,
  ) async {
    for (final reply in ['こんにちは', '안녕하세요', 'Привет', 'مرحبا']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentHubHistoryPanel(
                messages: [
                  const AgentHubHistoryMessage(
                    role: AgentHubHistoryRole.user,
                    content: 'What should I track today?',
                  ),
                  AgentHubHistoryMessage(
                    role: AgentHubHistoryRole.assistant,
                    content: reply,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(reply), findsOneWidget);
      expect(find.text('What should I track today?'), findsOneWidget);
    }
  });

  testWidgets('streamed and restored Chinese assistant text remains visible', (
    tester,
  ) async {
    for (final phase in [
      AgentStreamRunPhase.streaming,
      AgentStreamRunPhase.finished,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentRunTranscript(
              state: AgentStreamRunState(
                phase: phase,
                textContent: '好的，我先给你一个方向。',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('好的'), findsOneWidget);
      expect(find.textContaining('not available in English'), findsNothing);
    }
  });

  testWidgets('a Chinese profile name remains readable at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentRunTranscript(
              state: const AgentStreamRunState(phase: AgentStreamRunPhase.idle),
              greeting: agentHubGreetingForProfile(
                const AgentHubGreetingProfile(displayName: '小美', age: 29),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Hi 小美, I\'m Momcozy AI.'), findsWidgets);
    expect(find.textContaining('not available in English'), findsNothing);
    expect(find.textContaining('小美'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Chinese quick replies are visible but former branding is blocked',
    (tester) async {
      Future<void> mount(List<String> replies) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentRunTranscript(
                state: AgentStreamRunState(
                  phase: AgentStreamRunPhase.finished,
                  textContent: '这一步可以慢慢来。',
                  quickReplies: replies,
                ),
                onQuickReplySelected: (_) {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }

      await mount(['告诉我更多', '继续聊', '稍后再说']);
      expect(find.textContaining('这一步可以慢慢来'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsOneWidget);
      expect(find.text('继续聊'), findsOneWidget);

      await mount(['告诉我更多', '继续聊', 'Ask Cozymate']);
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.textContaining('Cozymate'), findsNothing);
    },
  );
}
