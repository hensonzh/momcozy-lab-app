import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_change_store.dart';

void main() {
  test('accepts only authoritative non-transient plan change events', () {
    expect(PlanChange.tryFromEvent(_event())?.eventId, 'plan-event-1');
    expect(PlanChange.tryFromEvent(_event(operation: 'unknown')), isNull);
    expect(PlanChange.tryFromEvent(_event(source: 'client')), isNull);
    expect(PlanChange.tryFromEvent(_event(transient: true)), isNull);
  });

  test('deduplicates events and clears unread state when Plan is viewed', () {
    final store = PlanChangeStore();

    expect(store.record(const PlanChange(eventId: 'same-event')), isTrue);
    expect(store.record(const PlanChange(eventId: 'same-event')), isFalse);
    expect(store.revision, 1);
    expect(store.hasUnread, isTrue);

    store.markViewed();
    expect(store.hasUnread, isFalse);
  });

  test('restores and persists notification state', () async {
    final persistence = _MemoryPersistence(
      const PlanChangeSnapshot(
        hasUnread: true,
        revision: 2,
        seenEventIds: ['restored-event'],
      ),
    );
    final store = PlanChangeStore(persistence: persistence);

    await store.restore();
    expect(store.hasUnread, isTrue);
    expect(store.revision, 2);
    expect(store.record(const PlanChange(eventId: 'restored-event')), isFalse);

    store.markViewed();
    await store.flushPersistence();
    expect(persistence.value?.hasUnread, isFalse);
    expect(persistence.value?.revision, 2);
  });
}

AgentStreamEvent _event({
  String operation = 'updated',
  String source = 'agent_action',
  bool transient = false,
}) {
  return AgentStreamEvent({
    'type': 'milk_plan.changed',
    'event_id': 'plan-event-1',
    'transient': transient,
    'payload': {'operation': operation, 'source': source},
  });
}

class _MemoryPersistence implements PlanChangePersistence {
  _MemoryPersistence(this.value);

  PlanChangeSnapshot? value;

  @override
  Future<PlanChangeSnapshot?> read() async => value;

  @override
  Future<void> write(PlanChangeSnapshot state) async {
    value = state;
  }
}
