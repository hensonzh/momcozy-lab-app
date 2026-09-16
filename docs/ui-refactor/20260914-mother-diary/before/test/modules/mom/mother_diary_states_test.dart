import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'mother_diary_test.dart' show DiaryFixture;

Future<void> choose(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'diary optional and conditional fields save without stale values $width/$scale',
        (tester) async {
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
                      date: LocalDate(2026, 9, 12),
                      stageLabel: '产后第 21 天 · 恢复建立期',
                    ),
                    child: const Text('记录'),
                  ),
                ),
              ),
            ),
          );
          await choose(tester, '记录');
          Future<void> capture(String name, String anchor) async {
            await tester.ensureVisible(find.text(anchor));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/diary-state-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }

          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '保存今天的记录'),
                )
                .onPressed,
            isNotNull,
          );
          await choose(tester, '保存今天的记录');
          expect(find.text('先记录一项今天的状态，再保存。'), findsOneWidget);
          await capture('empty-validation', '先记录一项今天的状态，再保存。');
          expect(repository.saves, 0);
          await choose(tester, '补充休息情况');
          await choose(tester, '1–2 小时');
          await capture('rest-stretch', '最长一段完整休息');
          expect(find.text('已填写'), findsOneWidget);
          await choose(tester, '30–60 分钟');
          await choose(tester, '有点难');
          await capture('rest-day', '今天有没有一段不被打扰的休息');
          await choose(tester, '喂奶');
          await choose(tester, '宝宝醒了');
          await capture('rest-disruptions', '影响休息的原因');
          await choose(tester, '补充休息情况');
          await choose(tester, '补充休息情况');
          await choose(tester, '保存今天的记录');
          expect(
            repository.entry!.diary.rest.longestStretch,
            SleepStretchBand.oneToTwoHours,
          );
          expect(
            repository.entry!.diary.rest.dayRest,
            DayRestBand.thirtyToSixtyMinutes,
          );
          expect(
            repository.entry!.diary.rest.resleepDifficulty,
            ResleepDifficulty.somewhatHard,
          );
          expect(repository.entry!.diary.rest.disruptions, {
            RestDisruption.feeding,
            RestDisruption.baby,
          });
          await choose(tester, '身体');
          expect(find.text('这种不适有多难受？'), findsNothing);
          await choose(tester, '腰背');
          await choose(tester, '明显');
          await choose(tester, '有一点影响');
          await capture('body-discomfort', '这种不适有多难受？');
          await choose(tester, '如厕与盆底');
          await choose(tester, '尿急 / 漏尿');
          await capture('body-urination', '排尿');
          await choose(tester, '费力');
          await capture('body-bowel', '排便');
          await choose(tester, '保存今天的记录');
          expect(repository.entry!.diary.body.discomfortSites, {
            DiscomfortSite.back,
          });
          expect(
            repository.entry!.diary.body.severity,
            DiscomfortSeverity.noticeable,
          );
          expect(repository.entry!.diary.body.impact, BodyImpact.some);
          expect(
            repository.entry!.diary.body.urination,
            Urination.leakingUrgency,
          );
          expect(repository.entry!.diary.body.bowel, Bowel.difficult);
          await choose(tester, '腰背');
          expect(find.text('这种不适有多难受？'), findsNothing);
          expect(find.text('这种不适影响到你了吗？'), findsNothing);
          await choose(tester, '保存今天的记录');
          expect(repository.entry!.diary.body.discomfortSites, isEmpty);
          expect(repository.entry!.diary.body.severity, isNull);
          expect(repository.entry!.diary.body.impact, isNull);
          expect(repository.entry!.diary.body.bowel, Bowel.difficult);
          expect(repository.saves, 3);
        },
      );
    }
  }
}
