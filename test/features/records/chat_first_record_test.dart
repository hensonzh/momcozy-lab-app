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
    'feeding records use the selected baby authoritative record endpoint',
    () async {
      const babyId = '5d56ff19-4f29-4414-9554-a125669a314b';
      for (final kind in [
        ChatFirstRecordKind.nursing,
        ChatFirstRecordKind.formula,
        ChatFirstRecordKind.expressed,
      ]) {
        final draft = ChatFirstRecordDraft(kind: kind, startedAt: now)
          ..side = 'left'
          ..durationMinutes = 20
          ..volumeMl = 70;
        final wire = babyRow('feeding');
        final observation = Map<String, Object?>.from(
          wire['observation']! as Map,
        );
        observation
          ..['occurred_at'] = now.toUtc().toIso8601String()
          ..['note'] = ''
          ..['method'] = switch (kind) {
            ChatFirstRecordKind.nursing => 'breastfeeding',
            ChatFirstRecordKind.formula => 'formula',
            _ => 'expressed_milk',
          }
          ..['side'] = kind == ChatFirstRecordKind.nursing ? 'left' : null
          ..['volume_ml'] = kind == ChatFirstRecordKind.nursing ? null : 70.0
          ..['duration_minutes'] = kind == ChatFirstRecordKind.nursing
              ? 20
              : null;
        wire['observation'] = observation;
        final transport = FixtureApiJsonTransport(wire);
        await ChatFirstRecordRepository(
          transport: transport,
          ownerUserId: 'owner-1',
          babyId: babyId,
        ).save(
          draft,
          now: now,
          timezone: 'Asia/Shanghai',
          idempotencyKey: 'feeding-$kind',
        );
        expect(transport.lastPath, '/v1/babies/$babyId/records');
        expect(transport.lastHeaders?['Idempotency-Key'], 'feeding-$kind');
        final saved = transport.lastBody!['observation'] as Map;
        expect(saved['kind'], 'feeding');
        expect(saved['method'], observation['method']);
      }
    },
  );

  test('feeding response must confirm the requested method', () async {
    const babyId = '5d56ff19-4f29-4414-9554-a125669a314b';
    final draft = ChatFirstRecordDraft(
      kind: ChatFirstRecordKind.formula,
      startedAt: now,
    )..volumeMl = 70;
    final wire = babyRow('feeding');
    await expectLater(
      ChatFirstRecordRepository(
        transport: FixtureApiJsonTransport(wire),
        ownerUserId: 'owner-1',
        babyId: babyId,
      ).save(
        draft,
        now: now,
        timezone: 'Asia/Shanghai',
        idempotencyKey: 'wrong-method',
      ),
      throwsFormatException,
    );
  });

  test('growth writes weight and length atomically to baby records', () async {
    const babyId = '5d56ff19-4f29-4414-9554-a125669a314b';
    Map<String, Object?> growthRow(String id, String metric, double value) => {
      'id': id,
      'baby_id': babyId,
      'version': 1,
      'observation': {
        'kind': 'growth',
        'recorded_on': '2026-10-15',
        'timezone': 'Asia/Shanghai',
        'metric': metric,
        'value': value,
        'unit': metric == 'weight' ? 'kg' : 'cm',
      },
      'deleted_at': null,
      'created_at': '2026-10-15T01:30:00Z',
      'updated_at': '2026-10-15T01:30:00Z',
    };
    final transport = FixtureApiJsonTransport({
      'items': [
        growthRow('weight-1', 'weight', 3.2),
        growthRow('length-1', 'length', 52),
      ],
    });
    final draft =
        ChatFirstRecordDraft(kind: ChatFirstRecordKind.growth, startedAt: now)
          ..weightKg = 3.2
          ..heightCm = 52;
    expect(
      await ChatFirstRecordRepository(
        transport: transport,
        ownerUserId: 'owner-1',
        babyId: babyId,
      ).save(
        draft,
        now: now,
        timezone: 'Asia/Shanghai',
        idempotencyKey: 'growth-once',
      ),
      'weight-1',
    );
    expect(transport.lastPath, '/v1/babies/$babyId/records/batch');
    expect(transport.lastHeaders?['Idempotency-Key'], 'growth-once');
    final observations = transport.lastBody!['observations'] as List;
    expect(observations, hasLength(2));
    expect(
      observations.every(
        (value) => !(value as Map).containsKey('measurement_source'),
      ),
      isTrue,
    );
    expect(observations.map((value) => (value as Map)['metric']).toSet(), {
      'weight',
      'length',
    });
  });

  test('pumping remains an owner-scoped maternal record', () async {
    final transport = FixtureApiJsonTransport(const {
      'id': 'saved-1',
      'owner_user_id': 'owner-1',
      'status': 'active',
    });
    final draft = ChatFirstRecordDraft(
      kind: ChatFirstRecordKind.pumping,
      startedAt: now,
    )..volumeMl = 50;
    await ChatFirstRecordRepository(
      transport: transport,
      ownerUserId: 'owner-1',
    ).save(
      draft,
      now: now,
      timezone: 'Asia/Shanghai',
      idempotencyKey: 'pump-once',
    );
    expect(transport.lastPath, '/v1/records/pumping');
    expect(transport.lastHeaders?['Idempotency-Key'], 'pump-once');
  });

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
          await repository.save(
            draft,
            now: now,
            timezone: 'Asia/Shanghai',
            idempotencyKey: 'baby-once',
          ),
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
        ).save(
          diaper,
          now: now,
          timezone: 'Asia/Shanghai',
          idempotencyKey: 'wrong-kind',
        ),
        throwsFormatException,
      );
    },
  );

  test('all baby record kinds require an actual selected baby', () async {
    for (final kind in [
      ChatFirstRecordKind.nursing,
      ChatFirstRecordKind.formula,
      ChatFirstRecordKind.expressed,
      ChatFirstRecordKind.diaper,
      ChatFirstRecordKind.sleep,
      ChatFirstRecordKind.growth,
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
        repository.save(
          draft,
          now: now,
          timezone: 'Asia/Shanghai',
          idempotencyKey: 'safe-key-2',
        ),
        throwsStateError,
      );
      expect(transport.mutationPaths, isEmpty);
    }
  });

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
        kind: ChatFirstRecordKind.pumping,
        startedAt: now,
      )..volumeMl = 50;
      await expectLater(
        repository.save(
          draft,
          now: now,
          timezone: 'Asia/Shanghai',
          idempotencyKey: 'safe-key',
        ),
        throwsFormatException,
      );
    },
  );
}
