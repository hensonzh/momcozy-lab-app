import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'mother_diary_test.dart' show DiaryFixture;

Future<void> mount(
  WidgetTester tester,
  DiaryFixture repository, {
  double width = 390,
  double height = 844,
  double scale = 1,
  DiarySection section = DiarySection.rest,
  VoidCallback? onClose,
}) async {
  await loadMomCozyTestFonts();
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: child!,
      ),
      home: MotherDiaryPage(
        repository: repository,
        date: LocalDate(2026, 9, 12),
        section: section,
        onClose: onClose ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> click(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> shot(
  WidgetTester tester,
  String name,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/design_system/diary-page-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'independent diary uses shared sections, preserves draft and saves $width/$scale',
        (tester) async {
          final repo = DiaryFixture();
          var closed = false;
          await mount(
            tester,
            repo,
            width: width,
            scale: scale,
            onClose: () => closed = true,
          );
          await shot(tester, 'rest', width, scale);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '保存今天的记录'),
                )
                .onPressed,
            isNotNull,
          );
          await click(tester, '4–5 小时');
          await click(tester, '身体');
          await shot(tester, 'body', width, scale);
          await click(tester, '有力气');
          await click(tester, '心情');
          await shot(tester, 'mood', width, scale);
          await click(tester, '还算平稳');
          await tester.tap(find.byTooltip('关闭记录'));
          await tester.pumpAndSettle();
          expect(find.text('离开这次记录？'), findsOneWidget);
          await click(tester, '继续填写');
          expect(closed, isFalse);
          expect(repo.saves, 0);
          repo.failure = const ProductFailure(ProductFailureKind.offline);
          await click(tester, '保存今天的记录');
          expect(find.text('这次填写的内容仍然保留。'), findsOneWidget);
          await shot(tester, 'offline', width, scale);
          repo.failure = null;
          await click(tester, '保存今天的记录');
          expect(repo.saves, 2);
          expect(repo.entry!.date, LocalDate(2026, 9, 12));
          expect(repo.entry!.diary.completedGroups, 3);
          await shot(tester, 'saved', width, scale);
          await tester.tap(find.byTooltip('关闭记录'));
          await tester.pumpAndSettle();
          expect(closed, isTrue);
        },
      );
    }
  }
  testWidgets(
    'short diary keeps note and save reachable with keyboard and large text',
    (tester) async {
      final repo = DiaryFixture();
      await mount(
        tester,
        repo,
        width: 320,
        height: 568,
        scale: 2,
        section: DiarySection.body,
      );
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.enterText(find.byType(TextFormField), '今天希望多休息一会儿');
      await tester.pumpAndSettle();
      await shot(tester, 'keyboard', 320, 2);
      expect(find.text('保存今天的记录').hitTestable(), findsOneWidget);
      await click(tester, '保存今天的记录');
      expect(repo.entry!.diary.body.note, '今天希望多休息一会儿');
      expect(tester.takeException(), isNull);
    },
  );
}
