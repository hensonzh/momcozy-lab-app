import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/schedule/data/milk_plan_change_persistence.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';

void main() {
  test('projects only durable privacy-safe milk plan change fields', () {
    final change = MilkPlanChange.tryFromEvent(_event());

    expect(change?.eventId, 'evt-milk-plan');
    expect(change?.operation, MilkPlanChangeOperation.created);
    expect(change?.affectedDateKeys, ['2026-07-03', '2026-07-04']);
    for (final operation in const ['updated', 'rescheduled', 'deleted']) {
      expect(
        MilkPlanChange.tryFromEvent(
          _event(operation: operation, reason: '${operation}_reason'),
        )?.operation.name,
        operation,
      );
    }
    expect(MilkPlanChange.tryFromEvent(_event(operation: 'unknown')), isNull);
    expect(MilkPlanChange.tryFromEvent(_event(source: 'client')), isNull);
    expect(
      MilkPlanChange.tryFromEvent(
        _event(reason: 'synced', affectedDates: const ['invalid']),
      )?.affectedDateKeys,
      isEmpty,
    );
  });

  test('deduplicates replay and transfers one bounded page notice', () {
    final store = MilkPlanChangeStore();
    final change = MilkPlanChange.tryFromEvent(_event())!;

    expect(store.record(change), isTrue);
    expect(store.record(change), isFalse);
    expect(store.revision, 1);
    expect(store.hasUnread, isTrue);

    store.transferNavigationNoticeToPage();
    expect(store.hasUnread, isFalse);
    expect(store.hasPageNotice, isTrue);
    expect(store.affectedDateKeys, ['2026-07-03', '2026-07-04']);

    store.clearPageNotice();
    expect(store.hasPageNotice, isFalse);
    expect(store.affectedDateKeys, isEmpty);
  });

  test(
    'merges affected dates from created, updated, rescheduled, and deleted events',
    () {
      final store = MilkPlanChangeStore();
      final operations = <String, List<String>>{
        'created': ['2026-07-03'],
        'updated': ['2026-07-04'],
        'rescheduled': ['2026-07-05', '2026-07-06'],
        'deleted': ['2026-07-07'],
      };

      var sequence = 0;
      for (final entry in operations.entries) {
        sequence += 1;
        store.record(
          MilkPlanChange.tryFromEvent(
            _event(
              eventId: 'evt-$sequence',
              operation: entry.key,
              reason: '${entry.key}_reason',
              affectedDates: entry.value,
            ),
          )!,
        );
      }

      expect(store.revision, 4);
      expect(store.affectedDateKeys, [
        '2026-07-03',
        '2026-07-04',
        '2026-07-05',
        '2026-07-06',
        '2026-07-07',
      ]);
    },
  );

  test('persisted state contains no plan id, action id, or summary', () {
    final store = MilkPlanChangeStore();
    store.record(MilkPlanChange.tryFromEvent(_event())!);
    store.transferNavigationNoticeToPage();
    final state = MilkPlanPendingState(
      hasUnread: store.hasUnread,
      hasPageNotice: store.hasPageNotice,
      revision: store.revision,
      lastEventId: store.lastEventId,
      affectedDateKeys: store.affectedDateKeys,
      seenEventIds: const ['evt-milk-plan'],
    );

    expect(state.toMap().keys, {
      'has_unread',
      'has_page_notice',
      'revision',
      'last_event_id',
      'affected_date_keys',
      'seen_event_ids',
    });
    expect(state.toMap().toString(), isNot(contains('private plan title')));
    expect(state.toMap().toString(), isNot(contains('plan-private')));
    expect(state.toMap().toString(), isNot(contains('action-private')));
  });

  test('secure persistence keys are account isolated', () {
    const first = FlutterSecureMilkPlanChangePersistence(userId: 'user/a');
    const second = FlutterSecureMilkPlanChangePersistence(userId: 'user/b');

    expect(first.storageKey, contains('user.user%2Fa.pending'));
    expect(second.storageKey, contains('user.user%2Fb.pending'));
    expect(first.storageKey, isNot(second.storageKey));
  });

  testWidgets('Agent reducer callback emits a durable change only once', (
    tester,
  ) async {
    final changes = <MilkPlanChange>[];
    final state = AgentStreamRunState(events: [_event()]);

    Widget page() => MaterialApp(
      home: Scaffold(
        body: AgentHubPage(state: state, onMilkPlanChange: changes.add),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.pumpWidget(page());
    await tester.pump();

    expect(changes, hasLength(1));
    expect(changes.single.affectedDateKeys, ['2026-07-03', '2026-07-04']);
  });
}

AgentStreamEvent _event({
  String eventId = 'evt-milk-plan',
  String operation = 'created',
  String source = 'agent_action',
  String reason = 'created',
  List<String> affectedDates = const [
    '2026-07-04',
    '2026-07-03',
    '2026-07-04',
    'invalid',
  ],
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': 2,
    'type': 'milk_plan.changed',
    'thread_id': 'thread-milk',
    'run_id': 'run-milk',
    'payload': {
      'operation': operation,
      'reason': reason,
      'plan_id': 'plan-private',
      'plan_type': 'milk_management',
      'source': source,
      'action_id': 'action-private',
      'affected_dates': affectedDates,
      'summary': 'private plan title',
    },
  });
}
