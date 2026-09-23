import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_text_reveal.dart';

void main() {
  Widget host(
    String text, {
    bool streaming = true,
    bool completed = false,
    bool reduced = false,
    String replyId = 'reply-1',
    VoidCallback? onReveal,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: AgentTextReveal(
        text: text,
        streaming: streaming,
        completed: completed,
        replyId: replyId,
        onReveal: onReveal,
        builder: (context, visible) => Text(visible),
      ),
    ),
  );

  String visible(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).data!;

  testWidgets('reveals bursts progressively without splitting graphemes', (
    tester,
  ) async {
    var reveals = 0;
    await tester.pumpWidget(host(''));
    const answer = '你👩🏽‍🍼好，今天感觉怎么样？';
    await tester.pumpWidget(host(answer, onReveal: () => reveals++));
    expect(visible(tester), '你');
    await tester.pump(const Duration(milliseconds: 24));
    expect(visible(tester), '你👩🏽‍🍼');
    await tester.pumpAndSettle();
    expect(visible(tester), answer);
    expect(reveals, greaterThan(1));
  });

  testWidgets('queued deltas stay ordered and final tail drains promptly', (
    tester,
  ) async {
    await tester.pumpWidget(host(''));
    final first = List.filled(80, '第一段').join();
    final complete = '$first\n\n**第二段** 👨‍👩‍👧‍👦';
    await tester.pumpWidget(host(first));
    await tester.pump(const Duration(milliseconds: 48));
    final before = visible(tester);
    await tester.pumpWidget(host(complete));
    expect(visible(tester), startsWith(before));
    expect(visible(tester), isNot(complete));
    await tester.pumpWidget(host(complete, streaming: false, completed: true));
    await tester.pump(const Duration(milliseconds: 192));
    expect(visible(tester), complete);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'stopping or disconnecting flushes received text and stops ticking',
    (tester) async {
      await tester.pumpWidget(host(''));
      const answer = '已经收到的文字应当保留，不再继续播放动画';
      await tester.pumpWidget(host(answer));
      expect(visible(tester), isNot(answer));
      await tester.pumpWidget(host(answer, streaming: false));
      expect(visible(tester), answer);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('authoritative corrections and withdrawals replace queued text', (
    tester,
  ) async {
    await tester.pumpWidget(host(''));
    await tester.pumpWidget(host('这是一段很长的临时回复'));
    await tester.pumpWidget(host('修正后的答复', streaming: false, completed: true));
    expect(visible(tester), '修正后的答复');
    await tester.pumpWidget(host(''));
    await tester.pump(const Duration(seconds: 1));
    expect(visible(tester), isEmpty);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'restored replies, reduced motion and new runs never replay old text',
    (tester) async {
      await tester.pumpWidget(host('已有回复'));
      expect(visible(tester), '已有回复');
      await tester.pumpWidget(host('已有回复，新增的一大段文字'));
      await tester.pumpWidget(host('新一轮内容', replyId: 'reply-2'));
      expect(visible(tester), '新一轮内容');
      await tester.pumpWidget(
        host('新一轮内容继续增加', replyId: 'reply-2', reduced: true),
      );
      expect(visible(tester), '新一轮内容继续增加');
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('disposing during typing cancels scheduled frames', (
    tester,
  ) async {
    await tester.pumpWidget(host(''));
    await tester.pumpWidget(host('还没显示完的一段文字'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
