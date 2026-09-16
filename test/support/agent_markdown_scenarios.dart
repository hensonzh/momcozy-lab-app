import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

const agentMarkdownSample = '''
## 今天的记录

这是一段用于核对排版的文字。**重点内容**与普通文字使用一致的阅读行高，换行后仍然清晰。

- 查看已经保存的记录
- 按自己的节奏继续

[查看排版说明](https://example.com/notes)

最后一段说明：链接、列表和段落保留各自的作用，正文不因格式标记而变得拥挤。
''';

TextStyle _effectiveStyle(RenderParagraph paragraph, String text) {
  TextStyle? result;
  void visit(InlineSpan span, TextStyle inherited) {
    final style = inherited.merge(span.style);
    if (span is TextSpan) {
      if (span.text?.contains(text) ?? false) result = style;
      for (final child in span.children ?? <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  visit(paragraph.text, const TextStyle());
  expect(result, isNotNull, reason: text);
  return result!;
}

Future<void> verifyAgentMarkdown(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final actions = <AgentArtifactActionView>[];
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
        body: SafeArea(
          child: AgentHubPage(
            state: const AgentStreamRunState(
              phase: AgentStreamRunPhase.finished,
              textContent: agentMarkdownSample,
            ),
            greetingProfileLoader: () async =>
                const AgentHubGreetingProfile(displayName: 'Mia', age: 30),
            onArtifactAction: actions.add,
          ),
        ),
        bottomNavigationBar: const MomCozyBottomNavigation(location: '/'),
      ),
    ),
  );
  // Asset decoding runs outside the fake clock; settling frames alone can
  // capture empty avatars when this scenario runs without preceding tests.
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(MomCozyAssets.agentAvatar),
      tester.element(find.byType(MaterialApp)),
    ),
  );
  await tester.pumpAndSettle();
  final heading = find.text('今天的记录', findRichText: true);
  await tester.ensureVisible(heading);
  await tester.pumpAndSettle();
  final headingStyle = _effectiveStyle(
    tester.renderObject<RenderParagraph>(heading),
    '今天的记录',
  );
  expect(headingStyle.fontSize, 18);
  expect(headingStyle.fontFamily, 'NotoSansSCHome');
  expect(headingStyle.height, 1.4);
  final paragraph = find.textContaining('这是一段用于核对排版', findRichText: true);
  final readingStyle = _effectiveStyle(
    tester.renderObject<RenderParagraph>(paragraph),
    '这是一段用于核对排版',
  );
  expect(readingStyle.fontSize, 16);
  expect(readingStyle.height, 1.65);
  expect(readingStyle.color, MomHomeTokens.ink);
  await capture('top');
  final link = find.text('查看排版说明', findRichText: true);
  await tester.ensureVisible(link);
  await tester.pumpAndSettle();
  await capture('link');
  await tester.tap(link);
  await tester.pumpAndSettle();
  expect(actions, hasLength(1));
  expect(actions.single.externalUri, Uri.parse('https://example.com/notes'));
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
