import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

void main() {
  testWidgets('chat-first replies have no leading rail or message avatars', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: const Scaffold(
          body: AgentHubPage(
            chatFirstExperience: true,
            historyMessages: [
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.assistant,
                content: '你好，我是 Momcozy AI。',
              ),
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.user,
                content: '你好',
              ),
            ],
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: '今天想聊聊宝宝吗？',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('你好，我是 Momcozy AI'), findsOneWidget);
    expect(find.textContaining('今天想聊聊宝宝吗'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-date-label')), findsOneWidget);
    expect(find.byKey(const ValueKey('agent-assistant-avatar')), findsNothing);
    expect(find.byKey(const ValueKey('agent-assistant-bubble')), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-first-assistant-answer')),
      findsNWidgets(2),
    );
    final answer = tester.widget<SizedBox>(
      find.byKey(const ValueKey('chat-first-assistant-answer')).first,
    );
    expect(answer.width, double.infinity);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chat-first-assistant-answer')),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
  });

  testWidgets('legacy conversation keeps its existing avatar and bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: const Scaffold(
          body: AgentHubPage(
            state: AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: 'Existing Agent reply',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('agent-assistant-avatar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('agent-assistant-bubble')),
      findsOneWidget,
    );
  });
}
