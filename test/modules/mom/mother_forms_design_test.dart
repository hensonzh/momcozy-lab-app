import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'mother_diary_test.dart' show DiaryFixture;

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final section in DiarySection.values) {
        testWidgets('diary ${section.name} dialog at $width / $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = DiaryFixture();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: momCozyTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showMotherDiaryEditor(
                      context,
                      repository: repository,
                      date: LocalDate(2026, 9, 8),
                      section: section,
                    ),
                    child: const Text('记录'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('记录'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/diary-${section.name}-${width.toInt()}.png',
              ),
            );
          }
          final selection = switch (section) {
            DiarySection.rest => '4–5 小时',
            DiarySection.body => '有力气',
            DiarySection.mood => '还算平稳',
          };
          await tester.ensureVisible(find.text(selection));
          await tester.tap(find.text(selection));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('关闭记录'));
          await tester.pumpAndSettle();
          expect(find.text('离开这次记录？'), findsOneWidget);
          await tester.tap(find.text('继续填写'));
          await tester.pumpAndSettle();
          if (section == DiarySection.body) {
            await tester.ensureVisible(find.byType(TextFormField));
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            addTearDown(tester.view.resetViewInsets);
            await tester.enterText(find.byType(TextFormField), '今天希望多休息一会儿');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          repository.failure = const ProductFailure(ProductFailureKind.offline);
          await tester.tap(find.text('保存今天的记录'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('这次填写的内容仍然保留。'), findsOneWidget);
          expect(
            tester
                .getRect(find.byType(Dialog))
                .contains(tester.getCenter(find.text('这次填写的内容仍然保留。'))),
            isTrue,
          );
          if (section == DiarySection.body && width == 320 && scale == 2) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/diary-keyboard-error-320.png',
              ),
            );
          }
          repository.failure = null;
          await tester.tap(find.text('保存今天的记录'));
          await tester.pumpAndSettle();
          expect(repository.saves, 2);
          expect(find.text('今天的记录已保存'), findsOneWidget);
          if (section == DiarySection.body) {
            expect(repository.entry!.diary.body.note, '今天希望多休息一会儿');
          }
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('关闭记录'));
          await tester.pumpAndSettle();
          expect(find.byType(MotherDiaryEditor), findsNothing);
        });
      }
    }
  }
}
