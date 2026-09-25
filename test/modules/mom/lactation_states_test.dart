import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/lactation/lactation_record.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/lactation_panel.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'lactation_test.dart' show LactationFixture, date, now;

const validation = 'Check the time and values: milk amount must be 0–2,000 ml, and nursing duration must be a whole number from 0–240 minutes.';
Future<void> click(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'lactation states validate, retry, edit and undo $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          final repo = LactationFixture()..records = [];
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
                    onPressed: () => showLactationPanel(
                      context,
                      repository: repo,
                      ownerUserId: 'mom',
                      date: date,
                      now: () => now,
                    ),
                    child: const Text('打开泌乳'),
                  ),
                ),
              ),
            ),
          );
          await click(tester, find.text('打开泌乳'));
          Future<void> visible(Finder finder) async {
            await tester.scrollUntilVisible(
              finder,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
          }

          Future<void> shot(String name) async {
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/milk-state-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
              ),
            );
          }

          await visible(find.text('No feeding or pumping records today'));
          await shot('empty');
          await click(tester, find.text('Add a record'));
          await shot('pump');
          await click(tester, find.text('Nursing'));
          await shot('nurse');
          final measure = find.byKey(
            const ValueKey('lactation-measurement-nurse'),
          );
          await tester.ensureVisible(measure);
          await tester.enterText(measure, '241');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save this record'));
          await tester.pumpAndSettle();
          expect(repo.keys, isEmpty);
          expect(find.text(validation).hitTestable(), findsOneWidget);
          await shot('validation');
          await tester.ensureVisible(measure);
          await tester.enterText(measure, '12');
          await tester.pumpAndSettle();
          await click(tester, find.text('Feelings and notes'));
          await click(tester, find.text('Full'));
          final note = find.widgetWithText(TextFormField, 'Notes (optional)');
          await tester.ensureVisible(note);
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await tester.enterText(note, '这次右侧有些胀，先记录下来');
          await tester.pumpAndSettle();
          await shot('optional-keyboard');
          repo.createFailure = const ProductFailure(ProductFailureKind.offline);
          await tester.tap(find.text('Save this record'));
          await tester.pumpAndSettle();
          expect(find.text('Your save has not been confirmed. Please try again.').hitTestable(), findsOneWidget);
          expect(find.text('Record saved.'), findsNothing);
          await shot('uncertain');
          repo.createFailure = null;
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Try saving again'));
          await tester.pumpAndSettle();
          expect(repo.keys, hasLength(2));
          expect(repo.keys.first, repo.keys.last);
          final saved = repo.records.single;
          expect(saved.observation, isA<NursingObservation>());
          expect((saved.observation as NursingObservation).durationMinutes, 12);
          expect(saved.observation.feeling, BreastComfort.full);
          expect(saved.observation.note, '这次右侧有些胀，先记录下来');
          expect(find.text('Record saved.').hitTestable(), findsOneWidget);
          await shot('saved');
          await visible(find.byKey(const ValueKey('lactation-edit-created')));
          await click(
            tester,
            find.byKey(const ValueKey('lactation-edit-created')),
          );
          await shot('editing');
          await tester.ensureVisible(measure);
          await tester.enterText(measure, '15');
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save changes'));
          await tester.pumpAndSettle();
          expect(repo.records.single.version, 2);
          expect(
            (repo.records.single.observation as NursingObservation)
                .durationMinutes,
            15,
          );
          expect(find.text('Record updated.').hitTestable(), findsOneWidget);
          await shot('updated');
          await visible(find.byKey(const ValueKey('lactation-delete-created')));
          await click(
            tester,
            find.byKey(const ValueKey('lactation-delete-created')),
          );
          expect(repo.records, isEmpty);
          await visible(find.text('Undo'));
          expect(find.text('Record updated.'), findsNothing);
          await shot('deleted');
          await click(tester, find.text('Undo'));
          expect(repo.restoreVersion, 9);
          expect(repo.records, hasLength(1));
          await visible(find.text('Record restored.'));
          await shot('restored');
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
