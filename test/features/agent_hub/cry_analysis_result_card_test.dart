import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_cry_task.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_cry_task.dart';

void main() {
  testWidgets('failed classifier stays non-diagnostic and offers rerecord', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatFirstCryTaskCard(
            status: ChatFirstCryTaskStatus.failed,
            onStart: () {},
            onAbandon: () {},
          ),
        ),
      ),
    );
    expect(find.text('这次分析未完成，可以重新录一段。'), findsOneWidget);
    expect(find.text('重新录一段'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-first-cry-result')), findsNothing);
  });

  for (final variant in [
    (ChatFirstCryTaskStatus.completed, 'no_cry', '这段录音未识别到有效哭声'),
    (ChatFirstCryTaskStatus.incomplete, null, '暂未识别出明确原因'),
  ]) {
    testWidgets('non-diagnostic card handles ${variant.$2 ?? 'incomplete'}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstCryResultCard(
              answer: variant.$2,
              incomplete: variant.$1 == ChatFirstCryTaskStatus.incomplete,
            ),
          ),
        ),
      );
      expect(find.text(variant.$3), findsOneWidget);
      expect(find.text('哭声背后的原因'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-first-cry-record-again')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('chat-first-cry-seek')), findsNothing);
    });
  }
}
