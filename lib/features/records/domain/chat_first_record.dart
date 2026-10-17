import '../../agent_hub/presentation/chat_first_actions.dart';

/// A draft is held until the server confirms the write; a failed attempt keeps
/// both the fields and the caller's idempotency key for an exact retry.
class ChatFirstRecordDraft {
  ChatFirstRecordDraft({required this.kind, required this.startedAt});

  final ChatFirstRecordKind kind;
  DateTime startedAt;
  DateTime? endedAt;
  String? side;
  String? diaperKind;
  int? durationMinutes;
  double? volumeMl;
  double? weightKg;
  double? heightCm;
  String note = '';

  Map<String, Object?> payload(DateTime now) {
    if (startedAt.isAfter(now)) {
      throw const FormatException('记录时间不能晚于当前时间。');
    }
    if (endedAt != null &&
        (!endedAt!.isAfter(startedAt) || endedAt!.isAfter(now))) {
      throw const FormatException('结束时间应晚于开始时间，且不能在未来。');
    }
    if (note.runes.length >
        (kind == ChatFirstRecordKind.diaper || kind == ChatFirstRecordKind.sleep
            ? 2000
            : 255)) {
      throw const FormatException('备注过长。');
    }
    final at = startedAt.toUtc().toIso8601String();
    final text = note.trim();
    return switch (kind) {
      ChatFirstRecordKind.nursing => _nursing(at, text),
      ChatFirstRecordKind.formula => _bottle(at, text, 'formula'),
      ChatFirstRecordKind.expressed => _bottle(at, text, 'expressed_milk'),
      ChatFirstRecordKind.pumping => _pumping(at, text),
      ChatFirstRecordKind.growth => _growth(at),
      ChatFirstRecordKind.diaper => _diaper(at, text),
      ChatFirstRecordKind.sleep => _sleep(at, text),
    };
  }

  Map<String, Object?> _nursing(String at, String text) {
    if (!const {'left', 'right', 'both'}.contains(side) ||
        durationMinutes == null ||
        durationMinutes! < 1 ||
        durationMinutes! > 240) {
      throw const FormatException('请选择喂养侧，并填写 1–240 分钟的时长。');
    }
    return {
      'feed_time': at,
      'feed_type': 'breastfeeding',
      'feed_action': side,
      'duration_seconds': durationMinutes! * 60,
      if (text.isNotEmpty) 'title': text,
    };
  }

  Map<String, Object?> _bottle(String at, String text, String type) {
    if (volumeMl == null ||
        !volumeMl!.isFinite ||
        volumeMl! < 1 ||
        volumeMl! > 1000) {
      throw const FormatException('请填写 1–1000 ml 的奶量。');
    }
    return {
      'feed_time': at,
      'feed_type': type,
      'volume_ml': volumeMl,
      if (text.isNotEmpty) 'title': text,
    };
  }

  Map<String, Object?> _pumping(String at, String text) {
    if (volumeMl == null ||
        !volumeMl!.isFinite ||
        volumeMl! < 1 ||
        volumeMl! > 3000) {
      throw const FormatException('请填写 1–3000 ml 的奶量。');
    }
    return {
      'pump_start_time': at,
      'milk_volume_ml': volumeMl,
      if (endedAt != null) 'pump_end_time': endedAt!.toUtc().toIso8601String(),
      'source': 'manual',
      if (text.isNotEmpty) 'title': text,
    };
  }

  Map<String, Object?> _growth(String at) {
    final weight = weightKg, height = heightCm;
    if ((weight == null && height == null) ||
        (weight != null && (!weight.isFinite || weight <= 0 || weight > 50)) ||
        (height != null && (!height.isFinite || height <= 0 || height > 150))) {
      throw const FormatException('请填写有效的体重或身长。');
    }
    return {'measured_at': at, 'weight_kg': ?weight, 'height_cm': ?height};
  }

  Map<String, Object?> _diaper(String at, String text) {
    if (!const {'wet', 'dirty', 'both'}.contains(diaperKind)) {
      throw const FormatException('请选择尿布状态。');
    }
    return {
      'changed_at': at,
      'diaper_kind': diaperKind,
      if (text.isNotEmpty) 'note': text,
    };
  }

  Map<String, Object?> _sleep(String at, String text) {
    if (endedAt == null) throw const FormatException('请选择睡眠结束时间。');
    return {
      'started_at': at,
      'ended_at': endedAt!.toUtc().toIso8601String(),
      if (text.isNotEmpty) 'note': text,
    };
  }
}
