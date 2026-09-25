import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_design.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_motion.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_record_editor.dart';
import 'baby_final_design_test.dart' show editor;
import 'baby_test_repositories.dart';

Widget host(Widget child, {bool reduced = false}) => MaterialApp(
  theme: BabyDesign.theme(ThemeData(), reduceMotion: reduced),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'press is visual only, releases on scroll/cancel, and never delays taps',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          Center(
            child: BabyPressFeedback(
              child: FilledButton(
                onPressed: () => taps++,
                child: const Text('save'),
              ),
            ),
          ),
        ),
      );
      final button = find.byType(FilledButton);
      final scale = find.byType(AnimatedScale);
      var gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<AnimatedScale>(scale).scale, .98);
      final transform = tester.widget<Transform>(
        find.descendant(of: scale, matching: find.byType(Transform)).first,
      );
      expect(transform.transform.storage[0], inExclusiveRange(.98, 1));
      await gesture.up();
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      await gesture.cancel();
      expect(taps, 1);
    },
  );

  for (final reduced in [false, true]) {
    testWidgets(
      'sheet and keyboard move continuously, reduce motion=$reduced',
      (tester) async {
        tester.view.physicalSize = const Size(393, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = editor(BabyTestRecords(), BabyRecordKind.dailyStatus)
          ..setWetCount('2');
        addTearDown(c.dispose);
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showBabySheet(context, BabyRecordEditor(controller: c)),
                child: const Text('open'),
              ),
            ),
            reduced: reduced,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump();
        final sheet = find.byType(BabySheetBody);
        final entry = tester.getTopLeft(sheet).dy;
        final route = ModalRoute.of(tester.element(sheet))!;
        if (reduced) expect(route.animation!.value, 1);
        await tester.pump(const Duration(milliseconds: 100));
        final middle = tester.getTopLeft(sheet).dy;
        await tester.pumpAndSettle();
        final settled = tester.getTopLeft(sheet).dy;
        if (reduced) {
          expect(entry, settled);
        } else {
          expect(entry, greaterThan(middle));
          expect(middle, greaterThan(settled));
        }
        final save = find.byKey(const ValueKey('baby-save'));
        final before = tester.getBottomRight(save).dy;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final halfway = tester.getBottomRight(save).dy;
        await tester.pumpAndSettle();
        final after = tester.getBottomRight(save).dy;
        expect(after, lessThanOrEqualTo(564));
        if (reduced) {
          expect(halfway, after);
        } else {
          expect(halfway, inExclusiveRange(after, before));
        }
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byType(BabyRecordEditor), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rapid tab changes keep one live form and preserve every draft', (
    tester,
  ) async {
    final c = editor(BabyTestRecords(), BabyRecordKind.dailyStatus);
    addTearDown(c.dispose);
    await tester.pumpWidget(host(BabyRecordEditor(controller: c)));
    await tester.tap(find.text('Wet diapers'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('wet-count')), '3');
    await tester.pump();
    await tester.tap(find.text('Dirty diapers'));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('stool-count')), '2');
    await tester.pump();
    await tester.tap(find.text('Mood'));
    await tester.pump();
    expect(find.byKey(const ValueKey('wet-count')), findsNothing);
    expect(find.byKey(const ValueKey('stool-count')), findsNothing);
    await tester.tap(find.text('Calm and content'));
    await tester.pumpAndSettle();
    expect(c.wetCount, '3');
    expect(c.stoolCount, '2');
    final saved = (await c.save())!.single as BabyDailyStatusRecord;
    expect(saved.mentalState, BabyMentalState.content);
    expect(saved.wetCount, 3);
    expect(saved.stoolCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion and disabled controls never shrink', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        host(
          BabyPressFeedback(
            child: FilledButton(
              onPressed: reduced ? () {} : null,
              child: const Text('save'),
            ),
          ),
          reduced: reduced,
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await gesture.cancel();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'switching system motion preference mid-animation settles the live form',
    (tester) async {
      final c = editor(BabyTestRecords(), BabyRecordKind.growth);
      addTearDown(c.dispose);
      await tester.pumpWidget(host(BabyRecordEditor(controller: c)));
      await tester.enterText(
        find.byKey(const ValueKey('growth-weight')),
        '4.2',
      );
      await tester.tap(find.text('Length'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final fade = find
          .descendant(
            of: find.byType(BabyContentTransition),
            matching: find.byType(FadeTransition),
          )
          .first;
      expect(tester.widget<FadeTransition>(fade).opacity.value, lessThan(1));
      await tester.pumpWidget(
        host(BabyRecordEditor(controller: c), reduced: true),
      );
      await tester.pump();
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expect(c.growthValues[GrowthMetric.weight], '4.2');
    },
  );

  testWidgets(
    'save label transitions keep button geometry and semantics stable',
    (tester) async {
      final text = ValueNotifier('Save');
      addTearDown(text.dispose);
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 320,
            child: ValueListenableBuilder(
              valueListenable: text,
              builder: (context, value, _) => FilledButton(
                onPressed: () {},
                child: BabyAnimatedLabel(value),
              ),
            ),
          ),
        ),
      );
      final before = tester.getRect(find.byType(FilledButton));
      text.value = 'Saving…';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getRect(find.byType(FilledButton)), before);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Saving…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing);
      expect(tester.getRect(find.byType(FilledButton)), before);
    },
  );
  testWidgets(
    'sheets cover app-shell navigation and outside taps only dismiss',
    (tester) async {
      final root = GlobalKey<NavigatorState>();
      final nested = GlobalKey<NavigatorState>();
      var tabTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: root,
          home: Scaffold(
            bottomNavigationBar: TextButton(
              onPressed: () => tabTaps++,
              child: const Text('bottom-tab'),
            ),
            body: Navigator(
              key: nested,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showBabySheet(
                      context,
                      const BabySheetBody(
                        title: 'sheet',
                        body: SizedBox(height: 160),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BabySheetBody);
      expect(
        ModalRoute.of(tester.element(sheet))!.navigator,
        same(root.currentState),
      );
      expect(
        tester.getBottomRight(sheet).dy,
        greaterThan(tester.getTopLeft(find.text('bottom-tab')).dy),
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tabTaps, 0);
      expect(nested.currentState!.canPop(), false);
    },
  );
}
