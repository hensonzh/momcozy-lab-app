import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_record_sheet.dart';

class _Records implements MeRepository {
  _Records(this.state);
  final MeState state;
  MeObservation? saved;
  @override
  Future<MeState> load(DateTime day) async => state;
  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> value) async =>
      value;
  @override
  Future<MeConcern> saveConcern(MeConcern value) async => value;
  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> value) async => value;
  @override
  Future<MeObservation> saveRecord(MeObservation value) async {
    saved = value;
    return value;
  }
}

void main() {
  final now = DateTime(2026, 9, 26, 12, 10);

  Future<_Records> open(
    WidgetTester tester,
    MeMetric kind,
    String feedingMethod, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Records(
      MeState(
        records: [
          MeObservation(
            id: 'feed-12-09',
            kind: MeMetric.feed,
            occurredAt: DateTime(2026, 9, 26, 12, 9),
            value: '80 ml',
            fields: {'feeding_method': feedingMethod},
          ),
        ],
      ),
    );
    final controller = MeController(
      repository: repository,
      now: () => now,
      state: repository.state,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMeRecordSheet(context, controller, kind),
              child: const Text('Open record'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open record'));
    await tester.pumpAndSettle();
    return repository;
  }

  for (final kind in [
    MeMetric.pain,
    MeMetric.latch,
    MeMetric.bottle,
    MeMetric.storage,
  ]) {
    testWidgets('$kind remains scrollable at 320px and 2x text', (
      tester,
    ) async {
      await open(
        tester,
        kind,
        'formula',
        size: const Size(320, 568),
        textScale: 2,
      );
      await tester.ensureVisible(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pain never links to the latest bottle feed and uses compact fields',
    (tester) async {
      final repository = await open(tester, MeMetric.pain, 'formula');
      expect(find.text('Did feeding or pumping hurt today?'), findsOneWidget);
      expect(find.textContaining('Linked to your'), findsNothing);
      expect(find.text('Record how this feeding felt for you.'), findsNothing);
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      expect(dropdowns, findsNWidgets(2));
      expect(tester.getSize(dropdowns.first).width, lessThanOrEqualTo(300));
      expect(tester.getSize(dropdowns.first).height, lessThanOrEqualTo(56));
      expect(tester.getSize(dropdowns.last).height, lessThanOrEqualTo(56));

      await tester.tap(find.text('Left side'));
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('During feeding').last);
      await tester.pumpAndSettle();
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needed a break').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save record'));
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNotNull);
      expect(
        repository.saved!.fields.containsKey('feeding_record_id'),
        isFalse,
      );
      expect(repository.saved!.fields['phase'], 'During feeding');
    },
  );

  testWidgets('stored milk keeps its fields with consistent compact sizing', (
    tester,
  ) async {
    final repository = await open(tester, MeMetric.storage, 'formula');
    final action = find.byType(DropdownButtonFormField<String>);
    final date = find.byType(OutlinedButton).first;
    final amount = find.byType(TextFormField);
    final save = find.byType(FilledButton);
    expect(action, findsOneWidget);
    expect(tester.getSize(action).width, lessThanOrEqualTo(300));
    expect(tester.getSize(action).height, lessThanOrEqualTo(56));
    expect(tester.getSize(date).width, lessThanOrEqualTo(300));
    expect(tester.getSize(amount).width, lessThanOrEqualTo(300));
    expect(
      tester.getTopLeft(save).dy - tester.getBottomLeft(amount).dy,
      lessThanOrEqualTo(32),
    );
    await tester.enterText(amount, '60');
    await tester.pump();
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();
    expect(repository.saved?.fields['volume_ml'], 60);
    expect(repository.saved?.fields['action'], 'Add a bag');
  });

  testWidgets(
    'latch is one choice without extra questions or an implicit feed link',
    (tester) async {
      final repository = await open(tester, MeMetric.latch, 'breastfeeding');
      expect(find.textContaining('Linked to your'), findsNothing);
      expect(find.text('Record how this feeding felt for you.'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Did you notice swallowing? (optional)'), findsNothing);
      expect(find.text('Changes or notes (optional)'), findsNothing);
      for (final choice in [
        'Stayed latched',
        'Came off easily',
        'Could not latch',
      ]) {
        expect(find.text(choice), findsOneWidget);
      }
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Stayed latched'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(repository.saved?.value, 'Stayed latched');
      expect(repository.saved?.fields, isEmpty);
    },
  );
}
