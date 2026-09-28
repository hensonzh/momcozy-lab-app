import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/application/me_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/data/me_api_repository.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/baby_inventory_transport.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';

class _Repository implements MeRepository {
  _Repository(this.state);
  MeState state;

  @override
  Future<MeState> load(DateTime _) async => state;

  @override
  Future<Map<String, Object?>> saveProfile(Map<String, Object?> values) async =>
      values;

  @override
  Future<MeConcern> saveConcern(MeConcern concern) async => concern;

  @override
  Future<List<MeMetric>> saveOrder(List<MeMetric> order) async => order;

  @override
  Future<MeObservation> saveRecord(MeObservation record) async => record;
}

class _ApiTransport extends FixtureApiJsonTransport {
  _ApiTransport() : super(const {});
  Map<String, Object?>? pumpQuery;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/profile/me-experience') {
      return {
        'records': [
          {
            'id': 'legacy',
            'kind': 'pump',
            'occurred_at': '2026-09-28T09:00:00Z',
            'value': '45 ml',
          },
        ],
      };
    }
    if (path == '/v1/babies') return {'items': <Object?>[]};
    if (path == '/v1/records/pumping') {
      pumpQuery = query;
      return {
        'items': [
          {
            'id': 'canonical',
            'pump_start_time': '2026-09-28T11:24:00Z',
            'milk_volume_ml': 55.5,
            'pump_type': 'manual',
          },
        ],
      };
    }
    throw StateError('Unexpected API path: $path');
  }
}

class _FeedApiTransport extends BabyInventoryTransport {
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/profile/me-experience') return const {};
    if (path == '/v1/records/pumping') return {'items': <Object?>[]};
    return super.getJson(path, query: query);
  }
}

void main() {
  final today = DateTime(2026, 9, 28, 12);
  final yesterday = DateTime(2026, 9, 27, 23, 59);
  MeObservation record(
    String id,
    MeMetric kind,
    DateTime at,
    String value, {
    Map<String, Object?> fields = const {},
  }) => MeObservation(
    id: id,
    kind: kind,
    occurredAt: at,
    value: value,
    fields: fields,
  );

  test('aggregates unique daily records and updates after saving', () async {
    final repository = _Repository(
      MeState(
        records: [
          record('feed-1', MeMetric.feed, today, '— min'),
          record('feed-1', MeMetric.feed, today, '— min'),
          record('pump-1', MeMetric.pump, today, '45 ml'),
          record('pump-1', MeMetric.pump, today, '45 ml'),
          record('old-pump', MeMetric.pump, yesterday, '200 ml'),
        ],
      ),
    );
    final controller = MeController(
      repository: repository,
      now: () => today,
      state: repository.state,
    );
    expect(controller.todayCardValue(MeMetric.feed), '1 time');
    expect(controller.todayCardValue(MeMetric.pump), '45 ml');
    await controller.saveRecord(
      record('feed-2', MeMetric.feed, today, '90 ml'),
    );
    await controller.saveRecord(
      record('pump-2', MeMetric.pump, today, '55.5 ml'),
    );
    expect(controller.todayCardValue(MeMetric.feed), '2 times');
    expect(controller.todayCardValue(MeMetric.pump), '100.5 ml');
    controller.dispose();
  });

  test('unknown pumping amount is not presented as a complete daily total', () {
    final repository = _Repository(
      MeState(
        records: [
          record('pump-1', MeMetric.pump, today, '45 ml'),
          record('pump-2', MeMetric.pump, today, '— ml'),
        ],
      ),
    );
    final controller = MeController(
      repository: repository,
      now: () => today,
      state: repository.state,
    );
    expect(controller.todayCardValue(MeMetric.pump), '— ml');
    controller.dispose();
  });

  test(
    'canonical pumping preserves exact volume for the daily total',
    () async {
      final transport = _ApiTransport();
      final repository = MeApiRepository(
        transport,
        timezoneProvider: () async => 'UTC',
      );
      final state = await repository.load(today);
      final canonical = state.records.singleWhere((e) => e.id == 'canonical');
      expect(canonical.fields['volume_ml'], 55.5);
      final controller = MeController(
        repository: repository,
        now: () => today,
        state: state,
      );
      expect(controller.todayCardValue(MeMetric.pump), '100.5 ml');
      expect(transport.pumpQuery?['limit'], 100);
      controller.dispose();
    },
  );

  test('counts today’s feeding records from the Baby API', () async {
    final transport = _FeedApiTransport();
    transport.create('inventory-baby', {
      'kind': 'feeding',
      'occurred_at': '2026-09-28T09:00:00Z',
      'method': 'breastfeeding',
      'duration_minutes': null,
      'side': 'left',
      'note': '',
    });
    transport.create('inventory-baby', {
      'kind': 'feeding',
      'occurred_at': '2026-09-28T11:24:00Z',
      'method': 'formula',
      'volume_ml': 90,
      'note': '',
    });
    transport.create('inventory-baby-2', {
      'kind': 'feeding',
      'occurred_at': '2026-09-28T10:00:00Z',
      'method': 'formula',
      'volume_ml': 70,
      'note': '',
    });
    final repository = MeApiRepository(
      transport,
      timezoneProvider: () async => 'UTC',
      selectedBabyId: 'inventory-baby',
    );
    final controller = MeController(repository: repository, now: () => today);
    await controller.load();
    expect(controller.state?.failedMetrics, isEmpty);
    expect(controller.todayCardValue(MeMetric.feed), '2 times');
    controller.dispose();
  });

  testWidgets('Me cards show today’s total pumping ml and feeding count', (
    tester,
  ) async {
    final repository = _Repository(
      MeState(
        profile: const {'preferred_name': 'Mia'},
        records: [
          record('pump-1', MeMetric.pump, DateTime(2026, 9, 28, 9), '45 ml'),
          record(
            'pump-2',
            MeMetric.pump,
            DateTime(2026, 9, 28, 11, 24),
            '56 ml',
            fields: const {'volume_ml': 55.5},
          ),
          record('feed-1', MeMetric.feed, DateTime(2026, 9, 28, 10), '— min'),
          record(
            'feed-2',
            MeMetric.feed,
            DateTime(2026, 9, 28, 11, 24),
            '90 ml',
          ),
          record('old-pump', MeMetric.pump, yesterday, '200 ml'),
          record('old-feed', MeMetric.feed, yesterday, '30 min'),
        ],
      ),
    );
    final controller = MeController(repository: repository, now: () => today);
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    Finder card(MeMetric kind) => find.byWidgetPredicate(
      (widget) => widget is MeHomeMetric && widget.kind == kind,
    );
    await tester.ensureVisible(card(MeMetric.feed));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card(MeMetric.feed), matching: find.text('2 times')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card(MeMetric.feed), matching: find.text('90 ml')),
      findsNothing,
    );
    await tester.ensureVisible(card(MeMetric.pump));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: card(MeMetric.pump), matching: find.text('100.5 ml')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card(MeMetric.pump), matching: find.text('56 ml')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
