import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_actions.dart';
import 'package:momcozy_flutter_app/features/records/data/chat_first_record_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/chat_first_record.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  final now = DateTime(2026, 10, 15, 9, 30);
  Map<String, Object?> babyRow(String kind) {
    final data =
        jsonDecode(
              File(
                'test/fixtures/product_baseline/baby_records.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    return Map<String, Object?>.from(
      (data['items'] as List).cast<Map>().singleWhere(
        (row) => (row['observation'] as Map)['kind'] == kind,
      ),
    );
  }

  test('nursing demands a side and duration, never guesses volume', () {
    final draft = ChatFirstRecordDraft(
      kind: ChatFirstRecordKind.nursing,
      startedAt: now,
    );
    expect(() => draft.payload(now), throwsFormatException);
    draft.side = 'left';
    draft.durationMinutes = 20;
    expect(draft.payload(now), {
      'feed_time': now.toUtc().toIso8601String(),
      'feed_type': 'breastfeeding',
      'feed_action': 'left',
      'duration_seconds': 1200,
    });
    draft.durationMinutes = 0;
    expect(() => draft.payload(now), throwsFormatException);
  });

  test(
    'three account-scoped record kinds use real Product Backend endpoints',
    () async {
      for (final kind in [
        ChatFirstRecordKind.formula,
        ChatFirstRecordKind.pumping,
        ChatFirstRecordKind.growth,
      ]) {
        final draft = ChatFirstRecordDraft(kind: kind, startedAt: now)
          ..volumeMl = 50
          ..weightKg = 3.2;
        final transport = FixtureApiJsonTransport(const {
          'id': 'saved-1',
          'owner_user_id': 'owner-1',
          'status': 'active',
        });
        final repository = ChatFirstRecordRepository(
          transport: transport,
          ownerUserId: 'owner-1',
        );
        await repository.save(draft, now: now, idempotencyKey: 'safe-key-1');
        expect(transport.lastPath, switch (kind) {
          ChatFirstRecordKind.formula => '/v1/records/feeding',
          ChatFirstRecordKind.pumping => '/v1/records/pumping',
          _ => '/v1/records/growth',
        });
        expect(transport.lastHeaders?['Idempotency-Key'], 'safe-key-1');
        expect(transport.lastBody!.containsKey('infant_id'), isFalse);
      }
    },
  );

  test(
    'expressed milk is a measured feeding, not a guessed nursing volume',
    () async {
      final draft = ChatFirstRecordDraft(
        kind: ChatFirstRecordKind.expressed,
        startedAt: now,
      )..volumeMl = 70;
      final transport = FixtureApiJsonTransport(const {
        'id': 'saved-1',
        'owner_user_id': 'owner-1',
        'status': 'active',
      });
      await ChatFirstRecordRepository(
        transport: transport,
        ownerUserId: 'owner-1',
      ).save(draft, now: now, idempotencyKey: 'expressed-once');
      expect(transport.lastPath, '/v1/records/feeding');
      expect(transport.lastBody, containsPair('feed_type', 'expressed_milk'));
      expect(transport.lastBody, containsPair('volume_ml', 70));
    },
  );

  test(
    'diaper and sleep require matching saved baby record categories',
    () async {
      const babyId = '5d56ff19-4f29-4414-9554-a125669a314b';
      for (final kind in [
        ChatFirstRecordKind.diaper,
        ChatFirstRecordKind.sleep,
      ]) {
        final wire = babyRow(
          kind == ChatFirstRecordKind.diaper ? 'diaper' : 'sleep',
        );
        final observation = wire['observation'] as Map;
        final draft =
            ChatFirstRecordDraft(
                kind: kind,
                startedAt: DateTime.parse(
                  observation['occurred_at'] as String,
                ).toLocal(),
              )
              ..diaperKind = 'both'
              ..endedAt = kind == ChatFirstRecordKind.sleep
                  ? DateTime.parse(observation['ended_at'] as String).toLocal()
                  : null;
        final transport = FixtureApiJsonTransport(wire);
        final repository = ChatFirstRecordRepository(
          transport: transport,
          ownerUserId: 'owner-1',
          babyId: babyId,
        );
        expect(
          await repository.save(draft, now: now, idempotencyKey: 'baby-once'),
          wire['id'],
        );
        expect(transport.lastPath, '/v1/babies/$babyId/records');
        expect(transport.lastHeaders?['Idempotency-Key'], 'baby-once');
      }
      final wrongKind = FixtureApiJsonTransport(babyRow('sleep'));
      final diaper = ChatFirstRecordDraft(
        kind: ChatFirstRecordKind.diaper,
        startedAt: now.subtract(const Duration(hours: 1)),
      )..diaperKind = 'wet';
      await expectLater(
        ChatFirstRecordRepository(
          transport: wrongKind,
          ownerUserId: 'owner-1',
          babyId: babyId,
        ).save(diaper, now: now, idempotencyKey: 'wrong-kind'),
        throwsFormatException,
      );
    },
  );

  test(
    'baby diaper and sleep only sync with an actual selected baby',
    () async {
      for (final kind in [
        ChatFirstRecordKind.diaper,
        ChatFirstRecordKind.sleep,
      ]) {
        final draft =
            ChatFirstRecordDraft(
                kind: kind,
                startedAt: now.subtract(const Duration(hours: 1)),
              )
              ..diaperKind = 'wet'
              ..endedAt = now.subtract(const Duration(minutes: 25));
        final transport = FixtureApiJsonTransport(const {});
        final repository = ChatFirstRecordRepository(
          transport: transport,
          ownerUserId: 'owner-1',
        );
        await expectLater(
          repository.save(draft, now: now, idempotencyKey: 'safe-key-2'),
          throwsStateError,
        );
        expect(transport.mutationPaths, isEmpty);
      }
    },
  );

  test(
    'rejects a response from another owner instead of saying synced',
    () async {
      final transport = FixtureApiJsonTransport(const {
        'id': 'saved-1',
        'owner_user_id': 'other-owner',
      });
      final repository = ChatFirstRecordRepository(
        transport: transport,
        ownerUserId: 'owner-1',
      );
      final draft = ChatFirstRecordDraft(
        kind: ChatFirstRecordKind.formula,
        startedAt: now,
      )..volumeMl = 50;
      await expectLater(
        repository.save(draft, now: now, idempotencyKey: 'safe-key'),
        throwsFormatException,
      );
    },
  );
}
