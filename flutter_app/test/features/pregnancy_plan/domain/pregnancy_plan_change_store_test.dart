import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';

void main() {
  group('PregnancyPlanChange', () {
    test('projects only the privacy-safe pregnancy_plan.changed payload', () {
      final change = PregnancyPlanChange.tryFromEvent(
        _changedEvent(eventId: 'evt-plan-created'),
      );

      expect(change, isNotNull);
      expect(change!.operation, 'created');
      expect(change.planId, 'plan-pregnancy-1');
      expect(change.planType, 'pregnancy');
      expect(change.source, 'agent_action');
      expect(change.eventId, 'evt-plan-created');
    });

    test('projects deletion as a privacy-safe invalidation event', () {
      final change = PregnancyPlanChange.tryFromEvent(
        _changedEvent(eventId: 'evt-plan-deleted', operation: 'deleted'),
      );

      expect(change, isNotNull);
      expect(change!.operation, 'deleted');
      expect(change.planId, 'plan-pregnancy-1');
      expect(change.planType, 'pregnancy');
      expect(change.source, 'agent_action');
    });

    test('projects updates as privacy-safe invalidation events', () {
      final change = PregnancyPlanChange.tryFromEvent(
        _changedEvent(eventId: 'evt-plan-updated', operation: 'updated'),
      );

      expect(change, isNotNull);
      expect(change!.operation, 'updated');
      expect(change.planId, 'plan-pregnancy-1');
      expect(change.source, 'agent_action');
    });

    test('rejects transient, unrelated, and malformed events', () {
      expect(
        PregnancyPlanChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-action-applied',
            'type': 'action.applied',
            'payload': {'action_type': 'pregnancy.plan.create'},
          }),
        ),
        isNull,
      );
      expect(
        PregnancyPlanChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-plan-transient',
            'type': 'pregnancy_plan.changed',
            'transient': true,
            'payload': {
              'operation': 'created',
              'plan_id': 'plan-pregnancy-1',
              'plan_type': 'pregnancy',
              'source': 'agent_action',
            },
          }),
        ),
        isNull,
      );
      for (final payload in const [
        {
          'operation': 'archived',
          'plan_id': 'plan-pregnancy-1',
          'plan_type': 'pregnancy',
          'source': 'agent_action',
        },
        {
          'operation': 'created',
          'plan_id': 'plan-pregnancy-1',
          'plan_type': 'milk_management',
          'source': 'agent_action',
        },
        {
          'operation': 'created',
          'plan_id': 'plan-pregnancy-1',
          'plan_type': 'pregnancy',
          'source': 'manual',
        },
        {
          'operation': 'created',
          'plan_id': '',
          'plan_type': 'pregnancy',
          'source': 'agent_action',
        },
      ]) {
        expect(
          PregnancyPlanChange.tryFromEvent(
            AgentStreamEvent({
              'event_id': 'evt-invalid-${payload.hashCode}',
              'type': 'pregnancy_plan.changed',
              'payload': payload,
            }),
          ),
          isNull,
        );
      }
    });
  });

  group('PregnancyPlanChangeStore', () {
    test('deduplicates replay and moves the notice between nav and card', () {
      final store = PregnancyPlanChangeStore();
      final change = PregnancyPlanChange.tryFromEvent(
        _changedEvent(eventId: 'evt-plan-created'),
      )!;

      expect(store.record(change), isTrue);
      expect(store.record(change), isFalse);
      expect(store.revision, 1);
      expect(store.hasUnread, isTrue);
      expect(store.highlightCard, isFalse);

      store.transferNavigationNoticeToCard();
      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isTrue);

      store.clearCardNotice();
      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isFalse);
      expect(store.revision, 1);
    });

    test('restores navigation unread when authoritative reload fails', () {
      final store = PregnancyPlanChangeStore();
      store.record(
        PregnancyPlanChange.tryFromEvent(
          _changedEvent(eventId: 'evt-plan-load-failed'),
        )!,
      );
      store.transferNavigationNoticeToCard();

      store.restoreNavigationNotice();

      expect(store.hasUnread, isTrue);
      expect(store.highlightCard, isFalse);
      expect(store.revision, 1);
    });

    test('deletion invalidates data without showing a new-plan notice', () {
      final store = PregnancyPlanChangeStore();
      store.record(
        PregnancyPlanChange.tryFromEvent(
          _changedEvent(eventId: 'evt-plan-created'),
        )!,
      );
      store.transferNavigationNoticeToCard();

      expect(
        store.record(
          PregnancyPlanChange.tryFromEvent(
            _changedEvent(eventId: 'evt-plan-deleted', operation: 'deleted'),
          )!,
        ),
        isTrue,
      );

      expect(store.revision, 2);
      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isFalse);
    });

    test('persists and restores privacy-safe notice state only', () async {
      final persistence = _FakePersistence();
      final first = PregnancyPlanChangeStore(persistence: persistence);
      first.record(
        PregnancyPlanChange.tryFromEvent(
          _changedEvent(eventId: 'evt-persisted-plan-change'),
        )!,
      );
      await first.flushPersistence();

      final persisted = persistence.value!;
      expect(persisted.toMap().keys, {
        'has_unread',
        'highlight_card',
        'revision',
        'last_event_id',
        'seen_event_ids',
      });
      expect(persisted.toMap().toString(), isNot(contains('plan-pregnancy-1')));
      expect(
        persisted.toMap().toString(),
        isNot(contains('action-plan-create')),
      );

      final restored = PregnancyPlanChangeStore(persistence: persistence);
      await restored.restore();
      expect(restored.hasUnread, isTrue);
      expect(restored.revision, 1);
      expect(
        restored.record(
          PregnancyPlanChange.tryFromEvent(
            _changedEvent(eventId: 'evt-persisted-plan-change'),
          )!,
        ),
        isFalse,
      );
    });

    test('late restore does not overwrite a newer in-memory event', () async {
      final persistence = _BlockingPersistence(
        const PregnancyPlanPendingState(
          hasUnread: false,
          highlightCard: false,
          revision: 4,
          lastEventId: 'evt-old',
          seenEventIds: ['evt-old'],
        ),
      );
      final store = PregnancyPlanChangeStore(persistence: persistence);
      final restore = store.restore();
      store.record(
        PregnancyPlanChange.tryFromEvent(_changedEvent(eventId: 'evt-new'))!,
      );

      persistence.release();
      await restore;

      expect(store.hasUnread, isTrue);
      expect(store.lastEventId, 'evt-new');
    });

    test(
      'restore deduplicates the same event arriving before read completes',
      () async {
        final persistence = _BlockingPersistence(
          const PregnancyPlanPendingState(
            hasUnread: false,
            highlightCard: false,
            revision: 1,
            lastEventId: 'evt-same',
            seenEventIds: ['evt-same'],
          ),
        );
        final store = PregnancyPlanChangeStore(persistence: persistence);
        final restore = store.restore();

        expect(
          store.record(
            PregnancyPlanChange.tryFromEvent(
              _changedEvent(eventId: 'evt-same'),
            )!,
          ),
          isTrue,
        );
        persistence.release();
        await restore;

        expect(store.hasUnread, isFalse);
        expect(store.highlightCard, isFalse);
        expect(store.revision, 1);
        expect(
          store.record(
            PregnancyPlanChange.tryFromEvent(
              _changedEvent(eventId: 'evt-same'),
            )!,
          ),
          isFalse,
        );
      },
    );
  });
}

AgentStreamEvent _changedEvent({
  required String eventId,
  String operation = 'created',
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': 7,
    'type': 'pregnancy_plan.changed',
    'thread_id': 'thread-plan',
    'run_id': 'run-plan',
    'payload': {
      'operation': operation,
      'plan_id': 'plan-pregnancy-1',
      'plan_type': 'pregnancy',
      'source': 'agent_action',
      'action_id': 'action-plan-create',
    },
  });
}

class _FakePersistence implements PregnancyPlanChangePersistence {
  PregnancyPlanPendingState? value;

  @override
  Future<PregnancyPlanPendingState?> read() async => value;

  @override
  Future<void> write(PregnancyPlanPendingState state) async {
    value = state;
  }
}

class _BlockingPersistence implements PregnancyPlanChangePersistence {
  _BlockingPersistence(this.value);

  final PregnancyPlanPendingState value;
  final _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<PregnancyPlanPendingState?> read() async {
    await _release.future;
    return value;
  }

  @override
  Future<void> write(PregnancyPlanPendingState state) async {}
}
