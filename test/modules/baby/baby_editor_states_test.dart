import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

class _PendingGrowthRecords extends BabyTestRecords {
  final gate = Completer<void>();
  int attempts = 0;
  @override
  Future<BabyRecord> save(
    BabyRecord record, {
    required String idempotencyKey,
  }) async {
    attempts++;
    await gate.future;
    return super.save(record, idempotencyKey: idempotencyKey);
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  Future<void> open(
    WidgetTester tester,
    BabyRecordEditorController c,
    double width,
    double scale,
  ) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BabyRecordEditor(controller: c),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  BabyRecordEditorController editor(
    BabyTestRecords repo,
    BabyRecordKind kind, {
    BabySleepRecord? active,
  }) => BabyRecordEditorController(
    repository: repo,
    baby: babyTestProfile,
    timezone: 'Asia/Shanghai',
    now: () => babyTestNow,
    kind: kind,
    activeSleep: active,
    diaperKind: DiaperKind.wet,
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final state in ['wet', 'nursing', 'sleep-start', 'sleep-active']) {
        testWidgets('$state keeps its primary action visible at $width/$scale', (
          tester,
        ) async {
          final repo = BabyTestRecords();
          final active = state == 'sleep-active'
              ? BabySleepRecord(
                  id: 'sleep',
                  babyId: 'baby',
                  occurredAt: babyTestNow.subtract(const Duration(hours: 2)),
                )
              : null;
          if (active != null) repo.values.add(active);
          final c = editor(
            repo,
            state == 'wet'
                ? BabyRecordKind.diaper
                : state == 'nursing'
                ? BabyRecordKind.feeding
                : BabyRecordKind.sleep,
            active: active,
          );
          addTearDown(c.dispose);
          if (state == 'nursing') {
            c.setFeedingMethod(BabyFeedingMethod.breastfeeding);
            c.setSide(FeedingSide.left);
          }
          await open(tester, c, width, scale);
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-$state-${width.toInt()}.png',
              ),
            );
          }
          if (state == 'sleep-active') {
            expect(find.text('入睡时间'), findsNothing);
            await tester.ensureVisible(find.text('调整时间和备注'));
            await tester.tap(find.text('调整时间和备注'));
            await tester.pumpAndSettle();
            expect(find.text('入睡时间'), findsOneWidget);
            await tester.ensureVisible(find.text('补充备注'));
            await tester.tap(find.text('补充备注'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('note-sleep')),
              '醒来后观察',
            );
            tester.testTextInput.hide();
            await tester.ensureVisible(find.text('收起时间和备注'));
            await tester.tap(find.text('收起时间和备注'));
            await tester.pumpAndSettle();
            expect(c.note, '醒来后观察');
            expect(find.text('入睡时间'), findsNothing);
            expect(tester.takeException(), isNull);
          }
          expect(
            find.byKey(const ValueKey('baby-save')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          expect(find.byType(BabyRecordEditor), findsNothing);
          expect(repo.values, hasLength(1));
          if (state == 'sleep-active') {
            expect(
              (repo.values.single as BabySleepRecord).endedAt,
              babyTestNow,
            );
            expect((repo.values.single as BabySleepRecord).note, '醒来后观察');
          }
          if (state == 'nursing') {
            expect(
              (repo.values.single as BabyFeedingRecord).durationMinutes,
              isNull,
            );
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('growth validation and pending save preserve the entered value', (
    tester,
  ) async {
    final repo = _PendingGrowthRecords();
    final c = editor(repo, BabyRecordKind.growth);
    addTearDown(c.dispose);
    await open(tester, c, 390, 1);
    final input = find.byType(TextFormField).first;
    await tester.enterText(input, '-1');
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const ValueKey('baby-save')));
    await tester.pumpAndSettle();
    expect(c.validation, isNotNull);
    expect(repo.attempts, 0);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/baby-editor-current-growth-validation-390-1x.png',
      ),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, '4.2');
    tester.testTextInput.hide();
    await tester.tap(find.byKey(const ValueKey('baby-save')));
    await tester.pump();
    expect(c.busy, isTrue);
    expect(find.text('正在保存…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('baby-save')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '关闭记录',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<TextFormField>(input).enabled, isFalse);
    expect(repo.attempts, 1);
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/baby-editor-current-growth-saving-390-1x.png',
      ),
    );
    repo.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(BabyRecordEditor), findsNothing);
    expect(repo.values, hasLength(1));
    expect((repo.values.single as BabyGrowthRecord).value, 4.2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'collapsed notes preserve the draft and uncertain save retries once',
    (tester) async {
      final repo = BabyTestRecords()..failSave = true;
      final c = editor(repo, BabyRecordKind.diaper);
      addTearDown(c.dispose);
      await open(tester, c, 320, 1);
      await tester.tap(find.text('补充备注'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('note-diaper')), '本次观察');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.text('补充备注'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭记录'));
      await tester.pumpAndSettle();
      expect(find.text('离开这次记录？'), findsOneWidget);
      await tester.tap(find.text('继续填写'));
      await tester.pumpAndSettle();
      expect(c.note, '本次观察');
      await tester.tap(find.byKey(const ValueKey('baby-save')));
      await tester.pumpAndSettle();
      expect(find.text('重试确认保存').hitTestable(), findsOneWidget);
      expect(c.uncertain, isTrue);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/baby-save-uncertain-320.png',
        ),
      );
      await tester.tap(find.text('重试确认保存'));
      await tester.pumpAndSettle();
      expect(repo.values, hasLength(1));
      expect(repo.keys.toSet(), hasLength(1));
      expect((repo.values.single as BabyDiaperRecord).note, '本次观察');
      expect(find.byType(BabyRecordEditor), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
