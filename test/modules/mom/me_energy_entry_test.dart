import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_record_sheet.dart';

class _Records implements MeRepository {
  _Records(this.state);
  final MeState state;
  List<MeMetric>? savedOrder;
  @override
  Future<MeState> load(DateTime date) async => state;
  @override
  Future<Map<String, Object?>> saveProfile(
    Map<String, Object?> profile,
  ) async => profile;
  @override
  Future<MeConcern> saveConcern(MeConcern concern) async => concern;
  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> order) async {
    savedOrder = List.of(order);
    return order;
  }

  @override
  Future<MeObservation> saveRecord(MeObservation record) async => record;
}

void main() {
  testWidgets('Home and Manage records hide Mood from an existing order', (
    tester,
  ) async {
    final state = MeState(
      order: const [
        MeMetric.mood,
        MeMetric.feed,
        MeMetric.energy,
        MeMetric.sleep,
      ],
      records: [
        MeObservation(
          id: 'old-mood',
          kind: MeMetric.mood,
          occurredAt: DateTime(2026, 9, 20),
          value: 'Okay',
        ),
      ],
    );
    final repository = _Records(state);
    final controller = MeController(
      repository: repository,
      now: () => DateTime(2026, 9, 20, 15),
      state: state,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeHomePage(
            controller: controller,
            onAsk: (_) {},
            onSharedRecord: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Mood today'), findsNothing);
    await tester.tap(find.text('Manage records ›'));
    await tester.pumpAndSettle();
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Energy today'), findsNothing);
    expect(find.text('Sleep last night'), findsNothing);
    expect(find.text('Mood today'), findsNothing);
    await tester.tap(find.text('Move to top').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.savedOrder, [
      MeMetric.energy,
      MeMetric.feed,
      MeMetric.sleep,
    ]);
    expect(state.records.single.value, 'Okay');
  });

  test('Energy replaces the Mood entry without deleting old records', () {
    final oldMood = MeObservation(
      id: 'historic-mood',
      kind: MeMetric.mood,
      occurredAt: DateTime(2026, 9, 20),
      value: 'Okay',
    );
    final state = MeState(
      order: const [
        MeMetric.mood,
        MeMetric.sleep,
        MeMetric.energy,
        MeMetric.feed,
      ],
      concerns: const [
        MeConcern(id: 'other', issues: [MeIssue.other]),
      ],
      records: [oldMood],
    );
    expect(state.visibleMetrics, contains(MeMetric.energy));
    expect(state.visibleMetrics, isNot(contains(MeMetric.mood)));
    expect(metricsFor([MeIssue.other]), isNot(contains(MeMetric.mood)));
    expect(state.records.single.toJson()['value'], 'Okay');
  });

  test('Energy offers an overall day check-in and retains legacy values', () {
    expect(meQuickOptions[MeMetric.energy], [
      'Doing well',
      'Getting by',
      'Worn down',
    ]);
    expect(
      MeObservation(
        id: 'new-energy',
        kind: MeMetric.energy,
        occurredAt: DateTime(2026, 9, 20),
        value: 'Getting by',
      ).displayValue,
      'Getting by',
    );
    expect(
      MeObservation(
        id: 'old-energy',
        kind: MeMetric.energy,
        occurredAt: DateTime(2026, 9, 20),
        value: 'Managing',
      ).displayValue,
      'Managing',
    );
  });
}
