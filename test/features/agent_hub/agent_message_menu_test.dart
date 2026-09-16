import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_message_menu.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/agent_message_menu_scenarios.dart';

void main() {
  testWidgets('history message copies its own complete text', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: const Scaffold(
          body: AgentHubHistoryPanel(
            messages: [
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.user,
                content: 'My question\nSecond line',
              ),
              AgentHubHistoryMessage(
                role: AgentHubHistoryRole.assistant,
                content: 'A different reply',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.longPress(find.text('My question\nSecond line'));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('删除'), findsNothing);
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copied, 'My question\nSecond line');
    expect(find.text('已复制'), findsOneWidget);
    expect(find.text('A different reply'), findsOneWidget);
  });

  for (final phase in [
    AgentStreamRunPhase.streaming,
    AgentStreamRunPhase.cancelRequested,
    AgentStreamRunPhase.waitingForConfirmation,
  ]) {
    testWidgets('no message actions during $phase', (tester) async {
      await tester.pumpWidget(
        messageMenuHost(
          AgentRunTranscript(
            state: AgentStreamRunState(
              phase: phase,
              textContent: 'Still writing',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.longPress(find.text('Still writing'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('复制'), findsNothing);
      expect(find.byType(PopupMenuItem), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('keyboard opens menu and Back returns focus without copying', (
    tester,
  ) async {
    await tester.pumpWidget(
      messageMenuHost(
        const AgentMessageMenu(
          text: 'Keyboard message',
          child: Text('Keyboard message'),
        ),
      ),
    );
    final focus = Focus.of(tester.element(find.text('Keyboard message')));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsNothing);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('clipboard failure reports failure and preserves message', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      messageMenuHost(
        const AgentMessageMenu(text: 'Keep me', child: Text('Keep me')),
      ),
    );
    await tester.longPress(find.text('Keep me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(find.text('复制失败，请重试'), findsOneWidget);
    expect(find.text('已复制'), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);
  });

  testWidgets('changing the message invalidates an open menu action', (
    tester,
  ) async {
    var text = 'Old message';
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copies++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    late StateSetter rebuild;
    await tester.pumpWidget(
      messageMenuHost(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AgentMessageMenu(text: text, child: Text(text));
          },
        ),
      ),
    );
    await tester.longPress(find.text('Old message'));
    await tester.pumpAndSettle();
    rebuild(() => text = 'New message');
    await tester.pump();
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copies, 0);
    expect(find.text('New message'), findsOneWidget);
  });

  testWidgets('empty text has no copy and disabled retry is not invented', (
    tester,
  ) async {
    await tester.pumpWidget(
      messageMenuHost(
        const AgentMessageMenu(text: '', child: Text('Attachment only')),
      ),
    );
    await tester.longPress(find.text('Attachment only'));
    await tester.pumpAndSettle();
    expect(find.text('复制'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });
}
