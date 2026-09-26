import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_record_sheet.dart';

class _EmptyMeRepository implements MeRepository {
  @override
  Future<MeState> load(DateTime date) async => const MeState();

  @override
  Future<Map<String, Object?>> saveProfile(
    Map<String, Object?> profile,
  ) async => profile;

  @override
  Future<MeConcern> saveConcern(MeConcern concern) async => concern;

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> order) async => order;

  @override
  Future<MeObservation> saveRecord(MeObservation record) async => record;
}

void main() {
  for (final (metric, lastOption, hint) in <(MeMetric, String, String)>[
    (
      MeMetric.energy,
      'Worn down',
      'Think about your energy across the day so far. You can update it later.',
    ),
    (
      MeMetric.sleep,
      'Not sure',
      'Record last night’s sleep. You can update it later.',
    ),
    (
      MeMetric.mood,
      'Good',
      'Record how you feel right now. You can update it later.',
    ),
  ]) {
    testWidgets('$metric quick record has no redundant note or large gap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MeController(
        repository: _EmptyMeRepository(),
        now: () => DateTime(2026, 9, 20),
        state: const MeState(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMeRecordSheet(context, controller, metric),
                child: const Text('Open record'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();

      expect(
        find.text('You do not need to fill out the other items.'),
        findsNothing,
      );
      final lastChoice = find
          .ancestor(
            of: find.text(lastOption),
            matching: find.byType(OutlinedButton),
          )
          .first;
      final save = find
          .ancestor(
            of: find.text('Save record'),
            matching: find.byType(FilledButton),
          )
          .first;
      expect(
        tester.getRect(save).top - tester.getRect(lastChoice).bottom,
        lessThanOrEqualTo(32),
      );
      final help = find.text(hint);
      expect(help, findsOneWidget);
      final firstChoice = find
          .ancestor(
            of: find.text(meQuickOptions[metric]!.first),
            matching: find.byType(OutlinedButton),
          )
          .first;
      expect(
        tester.getRect(firstChoice).top - tester.getRect(help).bottom,
        lessThanOrEqualTo(22),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final (metric, title) in <(MeMetric, String)>[
    (MeMetric.sleep, 'About how long did you sleep last night?'),
    (MeMetric.bottle, 'How did your baby take the bottle?'),
  ]) {
    testWidgets('$metric title fully fits at 320px and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MeController(
        repository: _EmptyMeRepository(),
        now: () => DateTime(2026, 9, 20),
        state: const MeState(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () =>
                      showMeRecordSheet(context, controller, metric),
                  child: const Text('Open record'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open record'));
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      final naturalHeight = paragraph.getMaxIntrinsicHeight(
        paragraph.size.width,
      );
      expect(paragraph.size.height, greaterThanOrEqualTo(naturalHeight - 1));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Close'), findsOneWidget);
      if (metric == MeMetric.bottle) {
        final caregiver = find.byType(DropdownButtonFormField<String>).at(1);
        await tester.ensureVisible(caregiver);
        await tester.pumpAndSettle();
        await tester.tap(caregiver);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Care professional').last);
        await tester.pumpAndSettle();
        final selectedText = find.descendant(
          of: caregiver,
          matching: find.text('Care professional'),
        );
        final selected = tester.renderObject<RenderParagraph>(selectedText);
        expect(
          selected.size.height,
          greaterThanOrEqualTo(
            selected.getMaxIntrinsicHeight(selected.size.width) - 1,
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
