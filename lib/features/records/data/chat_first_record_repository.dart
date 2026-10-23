import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart' as baby;
import 'package:momcozy_flutter_app/services/baby/baby_records_api_repository.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';

import '../../agent_hub/presentation/chat_first_actions.dart';
import '../domain/chat_first_record.dart';

class ChatFirstRecordRepository {
  const ChatFirstRecordRepository({
    required this.transport,
    required this.ownerUserId,
    this.babyId,
  });

  final ApiJsonTransport transport;
  final String ownerUserId;
  final String? babyId;

  Future<String> save(
    ChatFirstRecordDraft draft, {
    required DateTime now,
    required String timezone,
    required String idempotencyKey,
  }) async {
    final key = idempotencyKey.trim();
    if (key.isEmpty) throw const FormatException('Idempotency key required.');

    if (draft.kind == ChatFirstRecordKind.pumping) {
      final body = draft.payload(now);
      final result = await transport.postJson(
        '/v1/records/pumping',
        body: body,
        headers: {'Idempotency-Key': key},
      );
      final id = result['id'];
      if (id is! String ||
          id.isEmpty ||
          result['owner_user_id'] != ownerUserId ||
          result['status'] != 'active') {
        throw const FormatException('记录未由当前账号确认保存。');
      }
      return id;
    }

    final selectedBaby = babyId?.trim() ?? '';
    if (selectedBaby.isEmpty) {
      throw StateError('请先创建并选择真实的宝宝档案，才能同步此类记录。');
    }
    draft.payload(now);
    final repository = BabyRecordsApiRepository(transport: transport);

    if (draft.kind == ChatFirstRecordKind.growth) {
      final zone = timezone.trim();
      if (zone.isEmpty) throw const FormatException('Timezone required.');
      final recordedOn = dateInTimezone(draft.startedAt, zone);
      final records = <baby.BabyGrowthRecord>[
        if (draft.weightKg != null)
          baby.BabyGrowthRecord(
            id: '',
            babyId: selectedBaby,
            recordedOn: recordedOn,
            timezone: zone,
            metric: baby.GrowthMetric.weight,
            value: draft.weightKg!,
          ),
        if (draft.heightCm != null)
          baby.BabyGrowthRecord(
            id: '',
            babyId: selectedBaby,
            recordedOn: recordedOn,
            timezone: zone,
            metric: baby.GrowthMetric.length,
            value: draft.heightCm!,
          ),
      ];
      final localNow = inTimezone(now, zone);
      if (records.isEmpty ||
          records.any((record) => record.validate(localNow).isNotEmpty)) {
        throw const FormatException('记录字段无效。');
      }
      final saved = await repository.saveBatch(records, idempotencyKey: key);
      final savedGrowth = saved.whereType<baby.BabyGrowthRecord>().toList();
      if (savedGrowth.length != records.length ||
          records.any(
            (expected) => !savedGrowth.any(
              (actual) => _sameGrowth(expected, actual, selectedBaby),
            ),
          )) {
        throw const FormatException('宝宝生长记录保存范围不匹配。');
      }
      return saved.first.id;
    }

    final record = switch (draft.kind) {
      ChatFirstRecordKind.nursing => baby.BabyFeedingRecord(
        id: '',
        babyId: selectedBaby,
        occurredAt: draft.startedAt,
        method: baby.BabyFeedingMethod.breastfeeding,
        side: switch (draft.side) {
          'left' => baby.FeedingSide.left,
          'right' => baby.FeedingSide.right,
          _ => baby.FeedingSide.both,
        },
        durationMinutes: draft.durationMinutes,
        note: draft.note.trim(),
      ),
      ChatFirstRecordKind.formula => baby.BabyFeedingRecord(
        id: '',
        babyId: selectedBaby,
        occurredAt: draft.startedAt,
        method: baby.BabyFeedingMethod.formula,
        volumeMl: draft.volumeMl,
        note: draft.note.trim(),
      ),
      ChatFirstRecordKind.expressed => baby.BabyFeedingRecord(
        id: '',
        babyId: selectedBaby,
        occurredAt: draft.startedAt,
        method: baby.BabyFeedingMethod.expressedMilk,
        volumeMl: draft.volumeMl,
        note: draft.note.trim(),
      ),
      ChatFirstRecordKind.diaper => baby.BabyDiaperRecord(
        id: '',
        babyId: selectedBaby,
        occurredAt: draft.startedAt,
        kind: switch (draft.diaperKind) {
          'wet' => baby.DiaperKind.wet,
          'dirty' => baby.DiaperKind.dirty,
          _ => baby.DiaperKind.both,
        },
        note: draft.note.trim(),
      ),
      ChatFirstRecordKind.sleep => baby.BabySleepRecord(
        id: '',
        babyId: selectedBaby,
        occurredAt: draft.startedAt,
        endedAt: draft.endedAt,
        note: draft.note.trim(),
      ),
      _ => throw StateError('Unsupported record kind'),
    };
    if (record.validate(now).isNotEmpty) {
      throw const FormatException('记录字段无效。');
    }
    final saved = await repository.save(record, idempotencyKey: key);
    if (!_matchesSavedRecord(record, saved, selectedBaby)) {
      throw const FormatException('宝宝记录保存范围不匹配。');
    }
    return saved.id;
  }
}

bool _matchesSavedRecord(
  baby.BabyRecord expected,
  baby.BabyRecord actual,
  String babyId,
) {
  if (actual.id.isEmpty || actual.babyId != babyId) return false;
  return switch ((expected, actual)) {
    (
      baby.BabyFeedingRecord(
        occurredAt: final expectedAt,
        note: final expectedNote,
        method: final expectedMethod,
        side: final expectedSide,
        volumeMl: final expectedVolume,
        durationMinutes: final expectedDuration,
      ),
      baby.BabyFeedingRecord(
        occurredAt: final actualAt,
        note: final actualNote,
        method: final actualMethod,
        side: final actualSide,
        volumeMl: final actualVolume,
        durationMinutes: final actualDuration,
      ),
    ) =>
      expectedAt.toUtc() == actualAt.toUtc() &&
          expectedNote == actualNote &&
          expectedMethod == actualMethod &&
          expectedSide == actualSide &&
          expectedVolume == actualVolume &&
          expectedDuration == actualDuration,
    (
      baby.BabyDiaperRecord(
        occurredAt: final expectedAt,
        note: final expectedNote,
        kind: final expectedKind,
      ),
      baby.BabyDiaperRecord(
        occurredAt: final actualAt,
        note: final actualNote,
        kind: final actualKind,
      ),
    ) =>
      expectedAt.toUtc() == actualAt.toUtc() &&
          expectedNote == actualNote &&
          expectedKind == actualKind,
    (
      baby.BabySleepRecord(
        occurredAt: final expectedAt,
        note: final expectedNote,
        endedAt: final expectedEnd,
      ),
      baby.BabySleepRecord(
        occurredAt: final actualAt,
        note: final actualNote,
        endedAt: final actualEnd,
      ),
    ) =>
      expectedAt.toUtc() == actualAt.toUtc() &&
          expectedNote == actualNote &&
          expectedEnd?.toUtc() == actualEnd?.toUtc(),
    _ => false,
  };
}

bool _sameGrowth(
  baby.BabyGrowthRecord expected,
  baby.BabyGrowthRecord actual,
  String babyId,
) =>
    actual.id.isNotEmpty &&
    actual.babyId == babyId &&
    actual.recordedOn == expected.recordedOn &&
    actual.timezone == expected.timezone &&
    actual.metric == expected.metric &&
    actual.value == expected.value;
