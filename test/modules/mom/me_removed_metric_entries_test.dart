import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';

class _Records implements MeRepository {
  _Records(this.state);
  final MeState state;
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
  Future<MeObservation> saveRecord(MeObservation value) async => value;
}

void main() {
  final state = MeState(
    order: const [
      MeMetric.bottle,
      MeMetric.storage,
      MeMetric.feed,
      MeMetric.pump,
      MeMetric.energy,
      MeMetric.sleep,
    ],
    concerns: const [
      MeConcern(
        id: 'feeding-and-work',
        issues: [MeIssue.feeding, MeIssue.work],
      ),
    ],
    records: [
      MeObservation(
        id: 'old-bottle',
        kind: MeMetric.bottle,
        occurredAt: DateTime(2026, 9, 20),
        value: 'Took some',
      ),
      MeObservation(
        id: 'old-storage',
        kind: MeMetric.storage,
        occurredAt: DateTime(2026, 9, 20),
        value: '45 ml',
        fields: const {'volume_ml': 45},
      ),
    ],
  );

  test(
    'legacy bottle and storage records remain readable but are not suggested',
    () {
      expect(
        metricsFor([MeIssue.feeding, MeIssue.work]),
        isNot(contains(MeMetric.bottle)),
      );
      expect(
        metricsFor([MeIssue.feeding, MeIssue.work]),
        isNot(contains(MeMetric.storage)),
      );
      expect(
        state.visibleMetrics,
        containsAll([MeMetric.feed, MeMetric.latch, MeMetric.pump]),
      );
      expect(state.visibleMetrics, isNot(contains(MeMetric.bottle)));
      expect(state.visibleMetrics, isNot(contains(MeMetric.storage)));
      expect(state.records.map((record) => record.toJson()['value']), [
        'Took some',
        '45 ml',
      ]);
    },
  );

  testWidgets(
    'Home and Manage records omit bottle and stored milk from old order',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MeController(
        repository: _Records(state),
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
      expect(find.text('Bottle feeding'), findsNothing);
      expect(find.text('Stored milk'), findsNothing);
      await tester.tap(find.text('Manage records ›'));
      await tester.pumpAndSettle();
      expect(find.text('Bottle feeding'), findsNothing);
      expect(find.text('Stored milk'), findsNothing);
      expect(find.text('Feeding'), findsOneWidget);
      expect(find.text('Pumping'), findsOneWidget);
    },
  );
}
