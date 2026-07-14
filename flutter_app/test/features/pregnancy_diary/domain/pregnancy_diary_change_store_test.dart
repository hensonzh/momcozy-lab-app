import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';

void main() {
  group('PregnancyDiaryChange', () {
    test('projects the privacy-safe pregnancy_diary.changed payload', () {
      final change = PregnancyDiaryChange.tryFromEvent(
        _changedEvent(eventId: 'evt-diary-created'),
      );

      expect(change, isNotNull);
      expect(change!.operation, 'created');
      expect(change.entryId, 'diary-2026-07-12');
      expect(change.entryDate, DateTime(2026, 7, 12));
      expect(change.updatedAt, DateTime.utc(2026, 7, 12, 8, 30));
      expect(change.source, 'agent');
      expect(change.eventId, 'evt-diary-created');
    });

    test('rejects tool outcomes and malformed application events', () {
      expect(
        PregnancyDiaryChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-diary-read',
            'type': 'tool.completed',
            'payload': {
              'tool_name': 'pregnancy_diary.entry.read',
              'safe_output': {'status': 'entries_read'},
            },
          }),
        ),
        isNull,
      );
      expect(
        PregnancyDiaryChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-diary-conflict',
            'type': 'tool.completed',
            'payload': {
              'tool_name': 'pregnancy_diary.entry.create',
              'safe_output': {'status': 'entry_already_exists'},
            },
          }),
        ),
        isNull,
      );
      expect(
        PregnancyDiaryChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-diary-failed',
            'type': 'tool.failed',
            'payload': {
              'tool_name': 'pregnancy_diary.entry.update',
              'code': 'write_failed',
            },
          }),
        ),
        isNull,
      );
      expect(
        PregnancyDiaryChange.tryFromEvent(
          AgentStreamEvent(const {
            'event_id': 'evt-diary-invalid-operation',
            'type': 'pregnancy_diary.changed',
            'payload': {
              'operation': 'read',
              'entry_id': 'diary-2026-07-12',
              'entry_date': '2026-07-12',
              'updated_at': '2026-07-12T08:30:00Z',
              'source': 'agent',
            },
          }),
        ),
        isNull,
      );
    });
  });

  group('PregnancyDiaryChangeStore', () {
    test('deduplicates replayed event ids and increments one revision', () {
      final store = PregnancyDiaryChangeStore();
      final change = PregnancyDiaryChange.tryFromEvent(
        _changedEvent(eventId: 'evt-diary-created'),
      )!;

      expect(store.record(change), isTrue);
      expect(store.record(change), isFalse);

      expect(store.revision, 1);
      expect(store.lastEventId, 'evt-diary-created');
      expect(store.hasUnread, isTrue);
      expect(store.highlightCard, isFalse);
    });

    test('moves the navigation notice to the card and clears it', () {
      final store = PregnancyDiaryChangeStore();
      store.record(
        PregnancyDiaryChange.tryFromEvent(
          _changedEvent(eventId: 'evt-diary-updated', operation: 'updated'),
        )!,
      );

      store.transferNavigationNoticeToCard();

      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isTrue);

      store.clearCardNotice();

      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isFalse);
      expect(store.revision, 1);
    });

    test(
      'restores navigation unread when the highlighted card cannot load',
      () {
        final store = PregnancyDiaryChangeStore();
        store.record(
          PregnancyDiaryChange.tryFromEvent(
            _changedEvent(eventId: 'evt-diary-load-failed'),
          )!,
        );
        store.transferNavigationNoticeToCard();

        store.restoreNavigationNotice();

        expect(store.hasUnread, isTrue);
        expect(store.highlightCard, isFalse);
        expect(store.revision, 1);
      },
    );

    test('a committed delete clears notices but still invalidates data', () {
      final store = PregnancyDiaryChangeStore();
      store.record(
        PregnancyDiaryChange.tryFromEvent(
          _changedEvent(eventId: 'evt-diary-created'),
        )!,
      );

      final recorded = store.record(
        PregnancyDiaryChange.tryFromEvent(
          _changedEvent(eventId: 'evt-diary-deleted', operation: 'deleted'),
        )!,
      );

      expect(recorded, isTrue);
      expect(store.revision, 2);
      expect(store.lastEventId, 'evt-diary-deleted');
      expect(store.hasUnread, isFalse);
      expect(store.highlightCard, isFalse);
    });

    test(
      'persists and restores only privacy-safe pending notice state',
      () async {
        final persistence = _FakePersistence();
        final first = PregnancyDiaryChangeStore(persistence: persistence);
        first.record(
          PregnancyDiaryChange.tryFromEvent(
            _changedEvent(eventId: 'evt-persisted-diary-change'),
          )!,
        );
        await first.flushPersistence();

        final persisted = persistence.value!;
        expect(persisted.hasUnread, isTrue);
        expect(persisted.highlightCard, isFalse);
        expect(persisted.seenEventIds, ['evt-persisted-diary-change']);
        expect(persisted.toMap().keys, {
          'has_unread',
          'highlight_card',
          'revision',
          'last_event_id',
          'seen_event_ids',
        });

        final restored = PregnancyDiaryChangeStore(persistence: persistence);
        await restored.restore();

        expect(restored.hasUnread, isTrue);
        expect(restored.revision, 1);
        expect(
          restored.record(
            PregnancyDiaryChange.tryFromEvent(
              _changedEvent(eventId: 'evt-persisted-diary-change'),
            )!,
          ),
          isFalse,
        );
      },
    );

    test('queues a newer event on top of the restored revision', () async {
      final persistence = _BlockingPersistence(
        const PregnancyDiaryPendingState(
          hasUnread: false,
          highlightCard: false,
          revision: 4,
          lastEventId: 'evt-old',
          seenEventIds: ['evt-old'],
        ),
      );
      final store = PregnancyDiaryChangeStore(persistence: persistence);
      final restore = store.restore();
      store.record(
        PregnancyDiaryChange.tryFromEvent(_changedEvent(eventId: 'evt-new'))!,
      );
      persistence.release();
      await restore;

      expect(store.hasUnread, isTrue);
      expect(store.lastEventId, 'evt-new');
      expect(store.revision, 5);
    });

    test(
      'restore deduplicates the same event arriving before read completes',
      () async {
        final persistence = _BlockingPersistence(
          const PregnancyDiaryPendingState(
            hasUnread: false,
            highlightCard: false,
            revision: 1,
            lastEventId: 'evt-same',
            seenEventIds: ['evt-same'],
          ),
        );
        final store = PregnancyDiaryChangeStore(persistence: persistence);
        final restore = store.restore();

        expect(
          store.record(
            PregnancyDiaryChange.tryFromEvent(
              _changedEvent(eventId: 'evt-same'),
            )!,
          ),
          isTrue,
        );
        expect(
          store.record(
            PregnancyDiaryChange.tryFromEvent(
              _changedEvent(eventId: 'evt-same'),
            )!,
          ),
          isFalse,
        );
        persistence.release();
        await restore;

        expect(store.hasUnread, isFalse);
        expect(store.highlightCard, isFalse);
        expect(store.revision, 1);
        expect(
          store.record(
            PregnancyDiaryChange.tryFromEvent(
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
    'type': 'pregnancy_diary.changed',
    'thread_id': 'thread-diary',
    'run_id': 'run-diary',
    'payload': {
      'operation': operation,
      'entry_id': 'diary-2026-07-12',
      'entry_date': '2026-07-12',
      'updated_at': '2026-07-12T08:30:00Z',
      'source': 'agent',
    },
  });
}

class _FakePersistence implements PregnancyDiaryChangePersistence {
  PregnancyDiaryPendingState? value;

  @override
  Future<PregnancyDiaryPendingState?> read() async => value;

  @override
  Future<void> write(PregnancyDiaryPendingState state) async {
    value = state;
  }
}

class _BlockingPersistence implements PregnancyDiaryChangePersistence {
  _BlockingPersistence(this.value);

  final PregnancyDiaryPendingState value;
  final _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<PregnancyDiaryPendingState?> read() async {
    await _release.future;
    return value;
  }

  @override
  Future<void> write(PregnancyDiaryPendingState state) async {}
}
