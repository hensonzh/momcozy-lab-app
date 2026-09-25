import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';

void main() {
  testWidgets(
    'historic assistant text is not shown in Chinese or under the former brand',
    (tester) async {
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
      expect(find.textContaining('not available in English'), findsOneWidget);
    },
  );

  testWidgets(
    'old non-English assistant replies are hidden without changing user messages',
    (tester) async {
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
        expect(find.text(reply), findsNothing);
        expect(find.textContaining('not available in English'), findsOneWidget);
        expect(find.text('What should I track today?'), findsOneWidget);
      }
    },
  );

  testWidgets('a legacy streamed or restored AI reply never renders Chinese', (
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
      expect(find.textContaining('好的'), findsNothing);
      expect(find.textContaining('not available in English'), findsOneWidget);
    }
  });

  testWidgets(
    'legacy suggestions do not reintroduce non-English text or branding',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentRunTranscript(
              state: const AgentStreamRunState(
                phase: AgentStreamRunPhase.finished,
                textContent: 'A safe English response.',
                quickReplies: ['Tell me more', '继续聊', 'Ask Cozymate'],
              ),
              onQuickReplySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('A safe English response.'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-quick-replies')), findsNothing);
      expect(find.textContaining('继续聊'), findsNothing);
      expect(find.textContaining('Cozymate'), findsNothing);
    },
  );
}
