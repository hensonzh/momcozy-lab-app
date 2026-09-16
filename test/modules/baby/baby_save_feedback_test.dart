import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/domain/shared/record_deletion.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_saved_feedback.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

class _DelayedDeletes extends BabyTestRecords {
  Completer<void>? gate;
  String? failId;
  ProductFailure? failure;
  final calls = <String>[];
  @override
  Future<RecordDeletion> delete(
    String id, {
    required String babyId,
    required int expectedVersion,
  }) async {
    calls.add(id);
    if (gate != null) await gate!.future;
    if (id == failId) {
      failId = null;
      throw failure ?? const ProductFailure(ProductFailureKind.offline);
    }
    return super.delete(id, babyId: babyId, expectedVersion: expectedVersion);
  }
}

BabyHomeController home(BabyTestRecords repo, [BabyTestProfiles? profiles]) =>
    BabyHomeController(
      profileRepository: profiles ?? BabyTestProfiles(),
      recordRepository: repo,
      timezoneProvider: () async => 'Asia/Shanghai',
      now: () => babyTestNow,
    );

BabyRecord feed(String id, {String babyId = 'baby', int version = 3}) =>
    BabyFeedingRecord(
      id: id,
      babyId: babyId,
      version: version,
      occurredAt: babyTestNow,
      method: BabyFeedingMethod.expressedMilk,
      volumeMl: 60,
    );

void main() {
  setUpAll(loadMomCozyTestFonts);
  test(
    'partial batch undo retries only unconfirmed records and never another baby',
    () async {
      final repo = _DelayedDeletes()
        ..values = [feed('one'), feed('two'), feed('other', babyId: 'other')]
        ..failId = 'two';
      final c = home(repo);
      addTearDown(c.dispose);
      await c.load();
      c.showSaved(repo.values.take(2).toList(), allowUndo: true);
      await c.undoSaved();
      expect(c.savedFeedback!.message, contains('尚未确认'));
      expect(repo.calls, ['one', 'two']);
      await c.undoSaved();
      expect(repo.calls, ['one', 'two', 'two']);
      expect(repo.deleteVersions, [3, 3]);
      expect(repo.values.single.babyId, 'other');
      expect(c.savedFeedback!.undone, isTrue);
      c.showSaved([repo.values.single], allowUndo: true);
      expect(c.savedFeedback!.undone, isTrue);
    },
  );

  test(
    'busy undo is single flight and a baby switch cannot reuse its feedback',
    () async {
      final repo = _DelayedDeletes()
        ..values = [feed('one')]
        ..gate = Completer<void>();
      final profiles = BabyTestProfiles()
        ..values.add(const BabyProfile(id: 'other', name: 'Milo'));
      final c = home(repo, profiles);
      addTearDown(c.dispose);
      await c.load();
      c.showSaved(repo.values, allowUndo: true);
      final undo = c.undoSaved();
      await c.undoSaved();
      expect(repo.calls, ['one']);
      c.dismissSaved();
      expect(c.savedFeedback, isNotNull);
      await c.select('other');
      expect(c.savedFeedback, isNull);
      repo.gate!.complete();
      await undo;
      expect(c.baby!.id, 'other');
      expect(c.savedFeedback, isNull);
    },
  );

  test(
    'conflict and an existing sleep update cannot be undone as new records',
    () async {
      final repo = _DelayedDeletes()
        ..values = [feed('one')]
        ..failId = 'one'
        ..failure = const ProductFailure(ProductFailureKind.conflict);
      final c = home(repo);
      addTearDown(c.dispose);
      await c.load();
      c.showSaved(repo.values, allowUndo: false);
      await c.undoSaved();
      expect(repo.calls, isEmpty);
      c.showSaved(repo.values, allowUndo: true);
      await c.undoSaved();
      await c.undoSaved();
      expect(repo.calls, ['one']);
      expect(c.savedFeedback!.canUndo, isFalse);
      expect(c.savedFeedback!.message, contains('核对'));
    },
  );

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'feeding validation, save, uncertain undo and feedback at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = BabyTestRecords();
          // Use the same authoritative repository for both the form and the undo.
          final controller = home(repo);
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
              home: Scaffold(
                body: BabyHomePage(
                  controller: controller,
                  onAsk: (_) {},
                  onHistory: (_) async {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byType(BabyFeedingSummary),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.byType(BabyFeedingSummary));
          await tester.pumpAndSettle();
          expect(find.byType(BabyFeedingSummary).hitTestable(), findsOneWidget);
          await tester.tap(find.byType(BabyFeedingSummary));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          expect(find.text('先选择这次的喂养方式。').hitTestable(), findsOneWidget);
          expect(repo.values, isEmpty);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-feeding-validation-${width.toInt()}.png',
              ),
            );
          }
          await tester.ensureVisible(find.text('瓶喂母乳'));
          await tester.tap(find.text('瓶喂母乳'));
          await tester.pumpAndSettle();
          expect(find.text('先选择这次的喂养方式。'), findsNothing);
          await tester.enterText(
            find.byKey(const ValueKey('feeding-volume')),
            '60',
          );
          await tester.tap(find.byKey(const ValueKey('baby-save')));
          await tester.pumpAndSettle();
          expect(repo.values, hasLength(1));
          expect(controller.summary!.feedingCount, 1);
          expect(find.text('撤销').hitTestable(), findsOneWidget);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-feeding-saved-${width.toInt()}.png',
              ),
            );
          }
          repo.failDelete = true;
          await tester.tap(find.text('撤销'));
          await tester.pumpAndSettle();
          expect(find.text('重试确认撤销').hitTestable(), findsOneWidget);
          expect(repo.values, isEmpty);
          await tester.tap(find.text('重试确认撤销'));
          await tester.pumpAndSettle();
          expect(repo.deleteVersions, [1, 1]);
          expect(find.text('已撤销这次记录。'), findsOneWidget);
          expect(controller.summary!.feedingCount, 0);
          await tester.tap(find.byTooltip('关闭保存提示'));
          await tester.pumpAndSettle();
          expect(find.byType(BabySavedFeedbackView), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
