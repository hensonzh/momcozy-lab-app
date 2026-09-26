import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_design.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_artwork.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';
import 'baby_final_design_test.dart' show SlowRecords, editor;

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget child, {double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BabyDesign.theme(ThemeData()),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
  for (final width in [320.0, 393.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'home, switcher, knowledge and natural scroll $width/$scale',
        (tester) async {
          viewport(tester, width);
          final home = BabyHomeController(
            profileRepository: BabyTestProfiles(),
            recordRepository: BabyTestRecords(),
            timezoneProvider: () async => 'Asia/Shanghai',
            deliveryDateProvider: () async => LocalDate(2026, 8, 18),
            now: () => babyTestNow,
          );
          await tester.pumpWidget(
            app(
              BabyHomePage(controller: home, onAsk: (_) {}),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Girl · 3 weeks'), findsOneWidget);
          if (width == 320 && scale == 2) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/final-home-320-2x.png'),
            );
          }
          expect(find.textContaining('History'), findsNothing);
          expect(find.text('View all records'), findsNothing);
          expect(find.text('Sleep'), findsNothing);
          expect(find.text('Development'), findsNothing);
          if (scale > 1) {
            await tester.scrollUntilVisible(
              find.text('Not recorded yet'),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text('Not recorded yet'), findsAtLeastNWidgets(1));
            await tester.drag(find.byType(ListView), const Offset(0, 4000));
            await tester.pumpAndSettle();
          } else {
            expect(find.text('Not recorded yet'), findsAtLeastNWidgets(1));
          }
          expect(find.text('Not recorded'), findsNothing);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/final-home-${width.toInt()}.png'),
            );
          }
          await tester.tap(find.text('Luna'));
          await tester.pumpAndSettle();
          expect(find.text('Luna  · Current'), findsOneWidget);
          if (width == 320 && scale == 2) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/final-switcher-320-2x.png'),
            );
          }
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(find.text('Switch baby'), findsNothing);
          await tester.ensureVisible(find.byType(BabyKnowledgeBanner));
          await tester.tap(find.byType(BabyKnowledgeBanner));
          await tester.pumpAndSettle();
          expect(find.text('Ask Momcozy AI'), findsOneWidget);
          expect(find.textContaining('CDC'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(find.text('Ask Momcozy AI'), findsNothing);
          await tester.drag(find.byType(ListView), const Offset(0, -4000));
          await tester.pumpAndSettle();
          final scroll = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          for (var i = 0; i < 6 && scroll.extentAfter > 0; i++) {
            scroll.jumpTo(scroll.maxScrollExtent);
            await tester.pumpAndSettle();
          }
          expect(scroll.extentAfter, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
      for (final kind in [
        BabyRecordKind.feeding,
        BabyRecordKind.dailyStatus,
        BabyRecordKind.growth,
      ]) {
        testWidgets('editor stays usable with keyboard $kind $width/$scale', (
          tester,
        ) async {
          viewport(tester, width);
          final c = editor(BabyTestRecords(), kind);
          addTearDown(c.dispose);
          if (kind == BabyRecordKind.feeding) {
            c.selectBottle(true);
            c.setFeedingMethod(BabyFeedingMethod.formula);
          }
          if (kind == BabyRecordKind.dailyStatus) {
            c.selectDailyTab(BabyDailyTab.stool);
          }
          await tester.pumpWidget(
            app(
              Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      showBabySheet(context, BabyRecordEditor(controller: c)),
                  child: const Text('open'),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.getBottomRight(find.byKey(const ValueKey('baby-save'))).dy,
            lessThanOrEqualTo(564),
          );
        });
      }
    }
  }
  testWidgets(
    'feeding is two-level, one side only and mandatory choices gate save',
    (tester) async {
      final c = editor(BabyTestRecords(), BabyRecordKind.feeding);
      addTearDown(c.dispose);
      await tester.pumpWidget(app(BabyRecordEditor(controller: c)));
      FilledButton save() =>
          tester.widget(find.byKey(const ValueKey('baby-save')));
      expect(save().onPressed, isNull);
      expect(find.text('Select a feeding method first.'), findsNothing);
      await tester.tap(find.text('Bottle feeding'));
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull);
      await tester.tap(find.text('Breast milk'));
      await tester.pump();
      expect(save().onPressed, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('feeding-volume')),
        '90',
      );
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.tap(find.text('Nursing'));
      await tester.pumpAndSettle();
      expect(find.text('Both sides'), findsNothing);
      expect(save().onPressed, isNull);
      await tester.tap(find.text('Left side'));
      await tester.pump();
      expect(save().onPressed, isNotNull);
    },
  );
  testWidgets('save failure retains input and keeps the same save label', (
    tester,
  ) async {
    final r = BabyTestRecords()..failSave = true;
    final c = editor(r, BabyRecordKind.dailyStatus)..setWetCount('2');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showBabySheet(context, BabyRecordEditor(controller: c)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Please try again.'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(c.wetCount, '2');
    expect(c.editable, true);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(BabyRecordEditor), findsNothing);
    expect(r.values, hasLength(1));
  });
  testWidgets(
    'outside dismissal during saving finishes the submitted snapshot',
    (tester) async {
      final r = SlowRecords();
      bool finished = false;
      List<BabyRecord>? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBabyRecordEditor(
                  context,
                  repository: r,
                  baby: babyTestProfile,
                  timezone: 'Asia/Shanghai',
                  now: () => babyTestNow,
                  kind: BabyRecordKind.dailyStatus,
                  diaperKind: DiaperKind.wet,
                );
                finished = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('wet-count')), '2');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(BabyRecordEditor), findsNothing);
      expect(finished, false);
      r.gate.complete();
      await tester.pumpAndSettle();
      expect(finished, true);
      expect(result, hasLength(1));
      expect((r.values.single as BabyDailyStatusRecord).wetCount, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
