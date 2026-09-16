import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/mother_knowledge_content.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_knowledge_content.dart';
import 'package:momcozy_flutter_app/shared/widgets/knowledge_banner.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final baby in [false, true]) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('knowledge ${baby ? 'baby' : 'mom'} at $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var asked = 0;
          final article = baby
              ? babyKnowledgeArticles[BabyKnowledgeTopic.sleep]!
              : motherKnowledgeArticles[MotherKnowledgeTopic.lactation]!;
          await tester.pumpWidget(
            MaterialApp(
              theme: momCozyTheme(),
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showKnowledgeArticle(
                      context,
                      article: article,
                      babyStyle: baby,
                      title: baby ? '更好地了解 Luna' : '更好地了解自己的身体',
                      boundary: baby
                          ? '内容用于帮助理解记录，不是对宝宝健康或发育状态的判断。'
                          : '内容用于帮助理解你的连续记录，不是对身体或心理状态的诊断。',
                      onAsk: () => asked++,
                    ),
                    child: const Text('阅读'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('阅读'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(article.title), findsOneWidget);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../goldens/design_system/knowledge-${baby ? 'baby' : 'mom'}-${width.toInt()}.png',
              ),
            );
          }
          await tester.ensureVisible(find.text('问问 Cozymate'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('问问 Cozymate'));
          await tester.pumpAndSettle();
          expect(asked, 1);
          expect(find.byType(Dialog), findsNothing);
          await tester.tap(find.text('阅读'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          expect(asked, 1);
          expect(find.byType(Dialog), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
