@Tags(['golden'])
library;

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
                      title: baby
                          ? 'Learn more about Luna'
                          : 'Understand your body',
                      boundary: baby
                          ? 'This information helps you understand your records. It does not assess your baby\'s health or development.'
                          : 'This information helps you understand your records. It is not a diagnosis of your physical or mental health.',
                      onAsk: () => asked++,
                    ),
                    child: const Text('Read'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Read'));
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
          await tester.ensureVisible(find.text('Ask Momcozy AI'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ask Momcozy AI'));
          await tester.pumpAndSettle();
          expect(asked, 1);
          expect(find.byType(Dialog), findsNothing);
          await tester.tap(find.text('Read'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Close'));
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
