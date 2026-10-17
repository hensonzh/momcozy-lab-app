import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart' as baby;
import 'package:momcozy_flutter_app/services/baby/baby_records_api_repository.dart';

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
    required String idempotencyKey,
  }) async {
    final body = draft.payload(now);
    final key = idempotencyKey.trim();
    if (key.isEmpty) throw const FormatException('Idempotency key required.');
    if (draft.kind == ChatFirstRecordKind.diaper ||
        draft.kind == ChatFirstRecordKind.sleep) {
      final selectedBaby = babyId?.trim() ?? '';
      if (selectedBaby.isEmpty) {
        throw StateError('请先创建并选择真实的宝宝档案，才能同步此类记录。');
      }
      final record = draft.kind == ChatFirstRecordKind.diaper
          ? baby.BabyDiaperRecord(
              id: '',
              babyId: selectedBaby,
              occurredAt: draft.startedAt,
              kind: switch (draft.diaperKind) {
                'wet' => baby.DiaperKind.wet,
                'dirty' => baby.DiaperKind.dirty,
                _ => baby.DiaperKind.both,
              },
              note: draft.note.trim(),
            )
          : baby.BabySleepRecord(
              id: '',
              babyId: selectedBaby,
              occurredAt: draft.startedAt,
              endedAt: draft.endedAt,
              note: draft.note.trim(),
            );
      if (record.validate(now).isNotEmpty) {
        throw const FormatException('记录字段无效。');
      }
      final saved = await BabyRecordsApiRepository(
        transport: transport,
      ).save(record, idempotencyKey: key);
      if (saved.id.isEmpty ||
          saved.babyId != selectedBaby ||
          saved.recordKind != record.recordKind) {
        throw const FormatException('宝宝记录保存范围不匹配。');
      }
      return saved.id;
    }
    final endpoint = switch (draft.kind) {
      ChatFirstRecordKind.nursing ||
      ChatFirstRecordKind.formula ||
      ChatFirstRecordKind.expressed => '/v1/records/feeding',
      ChatFirstRecordKind.pumping => '/v1/records/pumping',
      ChatFirstRecordKind.growth => '/v1/records/growth',
      _ => throw StateError('Unsupported record kind'),
    };
    final result = await transport.postJson(
      endpoint,
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
}
