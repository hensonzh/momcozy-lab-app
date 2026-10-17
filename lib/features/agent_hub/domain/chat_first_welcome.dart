import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../onboarding/domain/chat_first_onboarding.dart';

const _welcomeVersion = 'momcozy-chat-first-welcome-v1';
const _welcomePrefix = '[Momcozy Chat 欢迎引导]';

bool isChatFirstWelcomePrompt(String text) =>
    text.trimLeft().startsWith(_welcomePrefix);

String? chatFirstWelcomeKeyForPrompt(String text) {
  final marker = RegExp(
    r'^\[Momcozy Chat 欢迎引导\]\[([0-9a-f]{24})\]',
  ).firstMatch(text.trimLeft());
  return marker == null ? null : 'chat-first-welcome:${marker.group(1)}';
}

/// The model reads account-scoped Product Backend context; the client never
/// invents a name, feeding mode, infant profile or medical conclusion.
class ChatFirstWelcomeRequest {
  const ChatFirstWelcomeRequest({
    required this.idempotencyKey,
    required this.message,
  });

  factory ChatFirstWelcomeRequest.forCompletedDraft(
    ChatFirstOnboardingDraft draft, {
    required String userId,
    required DateTime asOfDate,
  }) {
    if (draft.role != FamilyRole.mother || userId.trim().isEmpty) {
      throw const FormatException('A confirmed mother account is required.');
    }
    final input = draft.toMap();
    return ChatFirstWelcomeRequest._fromFacts(
      userId: userId,
      asOfDate: asOfDate,
      facts: _facts(
        age: input['age'],
        deliveries: input['delivery_count'],
        deliveryDate: input['delivery_date'],
        weeks: input['gestation_weeks'],
        days: input['gestation_days'],
        babies: input['baby_count'],
        concerns: draft.concerns.map((key) => chatFirstConcerns[key]!).toList(),
      ),
    );
  }

  factory ChatFirstWelcomeRequest.forAuthoritativeProfile({
    required String userId,
    required DateTime asOfDate,
    required Map<String, Object?> profile,
    required List<Object?> concerns,
  }) {
    final savedConcerns = <String>[];
    for (final raw in concerns) {
      if (raw is! Map || raw['ended'] == true) continue;
      final note = raw['note'];
      if (note is String && note.trim().isNotEmpty) {
        savedConcerns.add(note.trim());
      }
    }
    final birth = profile['actual_delivery_date'];
    if (userId.trim().isEmpty ||
        profile['age'] is! int ||
        profile['delivery_count'] is! int ||
        birth is! String ||
        DateTime.tryParse(birth) == null ||
        profile['gestation_weeks'] is! int ||
        profile['gestation_days'] is! int ||
        profile['baby_count'] is! int) {
      throw const FormatException(
        'Authoritative postpartum profile is incomplete.',
      );
    }
    return ChatFirstWelcomeRequest._fromFacts(
      userId: userId,
      asOfDate: asOfDate,
      facts: _facts(
        age: profile['age'],
        deliveries: profile['delivery_count'],
        deliveryDate: birth,
        weeks: profile['gestation_weeks'],
        days: profile['gestation_days'],
        babies: profile['baby_count'],
        concerns: savedConcerns,
      ),
    );
  }

  static Map<String, Object?> _facts({
    required Object? age,
    required Object? deliveries,
    required Object? deliveryDate,
    required Object? weeks,
    required Object? days,
    required Object? babies,
    required List<String> concerns,
  }) => {
    'role': 'mother',
    'stage': 'postpartum',
    'age': age,
    'delivery_count': deliveries,
    'delivery_date': deliveryDate,
    'gestation_weeks': weeks,
    'gestation_days': days,
    'baby_count': babies,
    'concerns': concerns.toSet().toList()..sort(),
  };

  static ChatFirstWelcomeRequest _fromFacts({
    required String userId,
    required DateTime asOfDate,
    required Map<String, Object?> facts,
  }) {
    final day =
        '${asOfDate.year}-${asOfDate.month.toString().padLeft(2, '0')}-${asOfDate.day.toString().padLeft(2, '0')}';
    final signature = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'version': _welcomeVersion,
              'user_id': userId,
              'day': day,
              'facts': facts,
            }),
          ),
        )
        .toString()
        .substring(0, 24);
    final marker = '$_welcomePrefix[$signature]';
    return ChatFirstWelcomeRequest(
      idempotencyKey: 'chat-first-welcome:$signature',
      message:
          '$marker 我刚完成这次资料填写，来到 Momcozy AI 首页。'
          '请以 Momcozy AI 第一人称，用轻松、温暖的中文写简短欢迎语。'
          '第一段直接介绍自己是专属母婴智能助手，可回答宝宝成长、喂养与照顾自己的日常问题，'
          '并能陪我持续整理我愿意记录的信息。'
          '第二段仅依据当前账号的权威资料选一项真实的阶段信息和至多两项确实采集的关注点；'
          '资料缺失就省略，绝不要猜姓名、喂养方式、宝宝档案、健康状况或医学诊断。'
          '第三段换行介绍通用快捷入口，每项一行，按 **「记录」**、**「听哭闹」**、'
          '**「看便便」** 的顺序：记录可整理日常并回顾变化；听哭闹可描述情境一起寻找可能原因；'
          '看便便可发照片或文字一起观察线索。最后另起一行问“你想先体验哪一个？”。'
          '不要说音频识别、自动保存或医学诊断已经实现；不要创造用户没填的事实。'
          '全文不超过 180 个汉字，不要标题、编号或项目符号。',
    );
  }

  final String idempotencyKey;
  final String message;

  Map<String, Object?> get metadata => const {'source': 'chat_first_welcome'};

  Map<String, Object?> toRouteExtra() => {
    'agentAutoRun': {
      'requestMessage': message,
      'idempotencyKey': idempotencyKey,
      'metadata': metadata,
    },
  };
}
