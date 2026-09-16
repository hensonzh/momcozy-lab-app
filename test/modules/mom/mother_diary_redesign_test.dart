import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/mother/mother_diary.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_editor.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/choice_field.dart';

import '../../support/momcozy_test_fonts.dart';
import 'mother_diary_test.dart' show DiaryFixture;

final _date = LocalDate(2026, 9, 13);

Future<void> _mount(
  WidgetTester tester,
  DiaryFixture repo,
  double width,
  double scale, {
  bool modal = false,
  MoodTone? initialMood,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
      home: modal
          ? Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showMotherDiaryEditor(
                    context,
                    repository: repo,
                    date: _date,
                    section: DiarySection.mood,
                    initialMood: initialMood,
                  ),
                  child: const Text('打开心情'),
                ),
              ),
            )
          : MotherDiaryPage(
              repository: repo,
              date: _date,
              section: DiarySection.body,
              onClose: () {},
            ),
    ),
  );
  if (modal) await tester.tap(find.text('打开心情'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _shot(
  WidgetTester tester,
  String state,
  double width,
  double scale,
) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      '../../goldens/ui_refactor/diary-$state-${width.toInt()}-${scale.toInt()}x.png',
    ),
  );
}

Finder _option<T extends Enum>(String label) => find.descendant(
  of: find.byType(ChoiceField<T>),
  matching: find.text(label),
);

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'diary loading, conflict, draft boundary and versioned reload $width/$scale',
        (tester) async {
          final repo = DiaryFixture()..loadGate = Completer<void>();
          await _mount(tester, repo, width, scale);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('今天身体的电量'), findsNothing);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '保存今天的记录'),
                )
                .onPressed,
            isNull,
          );
          await _shot(tester, 'loading', width, scale);
          repo.failure = const ProductFailure(ProductFailureKind.unavailable);
          repo.loadGate!.complete();
          await tester.pumpAndSettle();
          await _shot(tester, 'read-error', width, scale);
          repo.failure = null;
          await _tap(tester, find.text('重试'));
          final note = "${List.filled(1998, '记').join()}完成";
          await tester.ensureVisible(find.byType(TextFormField));
          await tester.enterText(find.byType(TextFormField), '$note超出');
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            note,
          );
          await _shot(tester, 'note-limit', width, scale);
          repo.failure = const ProductFailure(ProductFailureKind.conflict);
          await _tap(tester, find.text('保存今天的记录'));
          final feedback = find.text('这次填写的内容仍然保留。');
          expect(feedback.hitTestable(), findsOneWidget);
          await _shot(tester, 'conflict', width, scale);
          await _tap(tester, find.text('重新载入'));
          await _shot(tester, 'discard-confirm', width, scale);
          await _tap(tester, find.text('继续填写'));
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            note,
          );
          repo.entry = MotherDiaryEntry(
            id: 'server',
            ownerUserId: 'mom',
            date: _date,
            diary: const MotherDiary(
              body: MotherBody(energy: BodyEnergy.managing, note: '已在其他页面更新'),
            ),
            version: 8,
            updatedAt: DateTime.utc(2026, 9, 13),
          );
          repo.failure = null;
          await _tap(tester, find.text('重新载入'));
          await _tap(tester, find.text('放弃修改'));
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            '已在其他页面更新',
          );
          await tester.ensureVisible(find.byType(TextFormField));
          await tester.enterText(find.byType(TextFormField), note);
          await tester.pumpAndSettle();
          repo.gate = Completer<void>();
          await tester.tap(find.text('保存今天的记录'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == '关闭记录',
                  ),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, '正在保存…'),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, '心情'))
                .onPressed,
            isNull,
          );
          await _shot(tester, 'saving', width, scale);
          repo.gate!.complete();
          await tester.pumpAndSettle();
          expect(repo.entry!.version, 9);
          expect(repo.entry!.diary.body.note, note);
          expect(repo.entry!.diary.body.energy, BodyEnergy.managing);
          await _shot(tester, 'saved-long-note', width, scale);
          await _tap(tester, find.text('心情'));
          await _tap(tester, find.text('身体'));
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            note,
          );
        },
      );

      testWidgets(
        'diary quick mood, exclusive pressure and clearing saved record $width/$scale',
        (tester) async {
          final repo = DiaryFixture();
          final tone = width == 320
              ? MoodTone.low
              : width == 390
              ? MoodTone.steady
              : MoodTone.unclear;
          await _mount(
            tester,
            repo,
            width,
            scale,
            modal: true,
            initialMood: tone,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceField<MoodTone>>(
                  find.byType(ChoiceField<MoodTone>),
                )
                .selected,
            {tone},
          );
          await _shot(tester, 'quick-mood', width, scale);
          await _tap(tester, _option<MoodPressure>('担心宝宝'));
          await _tap(tester, _option<MoodPressure>('喂养压力'));
          expect(
            tester
                .widget<ChoiceField<MoodPressure>>(
                  find.byType(ChoiceField<MoodPressure>),
                )
                .selected
                .length,
            2,
          );
          await _tap(tester, _option<MoodPressure>('说不清楚'));
          expect(
            tester
                .widget<ChoiceField<MoodPressure>>(
                  find.byType(ChoiceField<MoodPressure>),
                )
                .selected,
            {MoodPressure.unclear},
          );
          await _shot(tester, 'exclusive-pressure', width, scale);
          await _tap(tester, find.text('保存今天的记录'));
          expect(repo.entry!.diary.mood.tone, tone);
          expect(repo.entry!.diary.mood.pressures, {MoodPressure.unclear});
          await _tap(tester, find.byTooltip('关闭记录'));
          await _tap(tester, find.text('打开心情'));
          expect(
            tester
                .widget<ChoiceField<MoodPressure>>(
                  find.byType(ChoiceField<MoodPressure>),
                )
                .selected,
            {MoodPressure.unclear},
          );
          await _tap(tester, _option<MoodPressure>('担心宝宝'));
          expect(
            tester
                .widget<ChoiceField<MoodPressure>>(
                  find.byType(ChoiceField<MoodPressure>),
                )
                .selected,
            {MoodPressure.babyWorry},
          );
          await _tap(tester, _option<MoodPressure>('担心宝宝'));
          final toneField = tester.widget<ChoiceField<MoodTone>>(
            find.byType(ChoiceField<MoodTone>),
          );
          await _tap(tester, _option<MoodTone>(toneField.options[tone]!));
          await _tap(tester, find.text('保存今天的记录'));
          expect(find.text('先记录一项今天的状态，再保存。').hitTestable(), findsOneWidget);
          expect(repo.saves, 1);
          await _shot(tester, 'cleared-validation', width, scale);
          await _tap(tester, find.byTooltip('关闭记录'));
          await _tap(tester, find.text('放弃修改'));
          expect(repo.entry!.diary.mood.tone, tone);
          expect(repo.entry!.diary.mood.pressures, {MoodPressure.unclear});
        },
      );
    }
  }
}
