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
## Today’s notes

A paragraph for checking readability. **Key details** keep the same line spacing as the rest of the text, even when they wrap.

- Review saved records
- Continue at your own pace

[Read the layout notes](https://example.com/notes)

Links, lists, and paragraphs each have a clear purpose without crowding the reading area.
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
  final heading = find.text('Today’s notes', findRichText: true);
  await tester.ensureVisible(heading);
  await tester.pumpAndSettle();
  final headingStyle = _effectiveStyle(
    tester.renderObject<RenderParagraph>(heading),
    'Today’s notes',
  );
  expect(headingStyle.fontSize, 18);
  expect(headingStyle.fontFamily, 'NotoSansSCHome');
  expect(headingStyle.height, 1.4);
  final paragraph = find.textContaining(
    'A paragraph for checking readability',
    findRichText: true,
  );
  final readingStyle = _effectiveStyle(
    tester.renderObject<RenderParagraph>(paragraph),
    'A paragraph for checking readability',
  );
  expect(readingStyle.fontSize, 16);
  expect(readingStyle.height, 1.65);
  expect(readingStyle.color, MomHomeTokens.ink);
  await capture('top');
  final link = find.text('Read the layout notes', findRichText: true);
  await tester.ensureVisible(link);
  await tester.pumpAndSettle();
  await capture('link');
  await tester.tap(link);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
