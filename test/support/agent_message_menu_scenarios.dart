import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_message_menu.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

Widget messageMenuHost(Widget child, {double scale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    appBar: AppBar(title: const Text('Cozymate')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

Future<void> verifyAgentMessageMenu(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  const userText = 'Can we review today’s notes?\nPlease keep both lines.';
  const reply = '**Your notes**\n\nOne observation at a time.';
  await tester.pumpWidget(
    messageMenuHost(
      const AgentHubHistoryPanel(
        messages: [
          AgentHubHistoryMessage(
            role: AgentHubHistoryRole.user,
            content: userText,
          ),
          AgentHubHistoryMessage(
            role: AgentHubHistoryRole.assistant,
            content: reply,
          ),
        ],
      ),
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.longPress(find.text(userText));
  await tester.pumpAndSettle();
  expect(find.text('复制'), findsOneWidget);
  expect(
    tester.getSize(find.byKey(const ValueKey('agent-message-copy'))).height,
    greaterThanOrEqualTo(44),
  );
  await capture('user');
  await tester.tap(find.text('复制'));
  await tester.pumpAndSettle();
  final copiedUser = await Clipboard.getData('text/plain');
  expect(copiedUser?.text, userText);
  expect(find.text('已复制'), findsOneWidget);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();

  final markdown = find.byType(AgentMarkdownText);
  final messageGesture = find
      .descendant(
        of: find.ancestor(
          of: markdown,
          matching: find.byType(AgentMessageMenu),
        ),
        matching: find.byType(GestureDetector),
      )
      .first;
  await tester.ensureVisible(messageGesture);
  await tester.longPress(messageGesture);
  await tester.pumpAndSettle();
  await capture('assistant');
  // Back dismisses only the menu, retaining the conversation.
  final handled = await tester.binding.handlePopRoute();
  expect(handled, isTrue);
  // The native popup's reverse transition must release its pointer barrier.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  expect(find.text('复制'), findsNothing);
  expect(markdown, findsOneWidget);
  await tester.longPress(messageGesture);
  await tester.pumpAndSettle();
  await tester.tap(find.text('复制'));
  await tester.pumpAndSettle();
  final copiedReply = await Clipboard.getData('text/plain');
  expect(copiedReply?.text, reply);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();

  var retries = 0;
  await tester.pumpWidget(
    messageMenuHost(
      AgentRunTranscript(
        state: const AgentStreamRunState(
          phase: AgentStreamRunPhase.disconnected,
          textContent: 'The connection paused.',
        ),
        canRetry: true,
        onRetry: () => retries++,
      ),
      scale: scale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.longPress(find.text('The connection paused.'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('agent-message-retry')), findsOneWidget);
  await capture('retry');
  await tester.tap(find.byKey(const ValueKey('agent-message-retry')));
  await tester.pumpAndSettle();
  expect(retries, 1);
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
}
