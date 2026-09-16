import '../../../domain/mother/mother_diary.dart';
import '../../../domain/mother/postpartum_stage.dart';
import '../../../domain/shared/local_date.dart';
import '../presentation/diary_labels.dart';
import '../presentation/lactation_panel.dart' show compactNumber;
import 'mother_home_controller.dart';

enum MomInsightStatus { waiting, generating, ready, unavailable }

/// An adapter boundary, not an invented HTTP endpoint. Only a real provider
/// may report generating/ready; the current backend has no daily insight API.
abstract interface class MomDailyInsightRepository {
  Future<MomDailyInsight> read(LocalDate date);
}

class MomDailyInsight {
  const MomDailyInsight({
    required this.status,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.detailId,
    this.generatedAt,
  });
  final MomInsightStatus status;
  final String eyebrow, title, body;
  final String? detailId;
  final DateTime? generatedAt;
  static const waiting = MomDailyInsight(
    status: MomInsightStatus.waiting,
    eyebrow: 'Cozymate · 等待你的首次记录',
    title: '记录一点点，\n我会更懂你的恢复状态',
    body: '完成首次记录后，AI 会结合你的状态，生成每日恢复分析与行动建议。',
  );
  static const unavailable = MomDailyInsight(
    status: MomInsightStatus.unavailable,
    eyebrow: 'Cozymate · 每日分析暂不可用',
    title: '记录每一点变化，\n与 Cozymate 一起了解自己',
    body: '每日分析暂不可用，你仍可以与 Cozymate 交流今天的状态。',
  );
}

/// Business dimensions are independent: a partial diary is not a complete
/// diary, and buying a service does not manufacture today's records.
class MomHomeViewData {
  const MomHomeViewData({
    required this.greeting,
    required this.phaseLabel,
    required this.insight,
    required this.hasTodayRecords,
    required this.lactationValue,
    required this.lactationMeta,
    required this.bodyValue,
    required this.bodyMeta,
    required this.sleepValue,
    required this.sleepMeta,
    required this.moodValue,
    required this.completedGroups,
    this.moodSelection,
    this.bodyRecorded = false,
    this.lactationRecorded = false,
    this.sleepRecorded = false,
  });
  final String greeting, phaseLabel, lactationValue, lactationMeta;
  final String bodyValue, bodyMeta, sleepValue, sleepMeta, moodValue;
  final MomDailyInsight insight;
  final bool hasTodayRecords, lactationRecorded, bodyRecorded, sleepRecorded;
  final int completedGroups;
  final int? moodSelection;

  factory MomHomeViewData.fromController(MotherHomeController c) {
    final profile = c.profile.value;
    final day = profile?.postpartumDay(c.date);
    final hour = c.now().toLocal().hour;
    final greeting = hour < 12
        ? '早上好'
        : hour < 18
        ? '下午好'
        : '晚上好';
    final diary = c.todayDiary;
    final milk = c.milk;
    final hasMilk = (milk?.recordCount ?? 0) > 0;
    final hasRecords = hasMilk || (diary != null && !diary.isEmpty);
    final rest = diary?.rest;
    final body = diary?.body;
    final previous = c.diaries.value
        ?.where((e) => e.date == c.date.addDays(-1))
        .firstOrNull
        ?.diary
        .rest;
    String missing(bool loading, bool failed) => loading
        ? '载入中…'
        : failed
        ? '暂未载入'
        : '待记录';
    final missingDiary = missing(c.diaries.loading, c.diaries.failure != null);
    final discomfort = body == null || body.discomfortSites.isEmpty
        ? (body?.impact == BodyImpact.none ? '暂无明显不适' : '未补充不适情况')
        : body.discomfortSites.map((s) => siteLabels[s]!).join('、');
    final tone = diary?.mood.tone;
    return MomHomeViewData(
      greeting:
          '$greeting${profile?.displayName.isNotEmpty == true ? '，${profile!.displayName}' : ''}',
      phaseLabel: day == null ? '陪伴每个阶段' : formatPostpartumDay(day),
      insight: hasRecords
          ? c.insight.value ?? MomDailyInsight.unavailable
          : c.diaries.hasValue && c.lactation.hasValue
          ? MomDailyInsight.waiting
          : MomDailyInsight.unavailable,
      hasTodayRecords: hasRecords,
      lactationRecorded: hasMilk,
      lactationValue: hasMilk
          ? milk!.measuredVolumeMl != null
                ? '${compactNumber(milk.measuredVolumeMl!)} ml'
                : milk.nursingMinutes != null
                ? '${milk.nursingMinutes} 分钟'
                : '${milk.recordCount} 次'
          : c.lactation.loading
          ? '载入中…'
          : c.lactation.failure != null
          ? '暂未载入'
          : '暂未记录',
      lactationMeta: hasMilk
          ? '泵奶 ${milk!.pumpCount} 次 · 亲喂 ${milk.nursingCount} 次'
          : '记录后，AI 会持续判断奶量与供需趋势',
      bodyValue: energyLabels[body?.energy] ?? missingDiary,
      bodyMeta: body == null || body.isEmpty ? '约 10 秒 · 快速完成' : discomfort,
      bodyRecorded: body != null && !body.isEmpty,
      sleepValue:
          sleepTotalLabels[rest?.total] ??
          recoveryLabels[rest?.recovery] ??
          missingDiary,
      sleepMeta: _restComparison(rest, previous),
      sleepRecorded: rest != null && !rest.isEmpty,
      moodValue: toneLabels[tone] ?? '今天感觉怎么样？',
      moodSelection: switch (tone) {
        MoodTone.low || MoodTone.tense || MoodTone.reactive => 0,
        MoodTone.steady => 2,
        MoodTone.unclear => 1,
        _ => null,
      },
      completedGroups: diary?.completedGroups ?? 0,
    );
  }
}

String _restComparison(MotherRest? current, MotherRest? previous) {
  if (current == null || current.isEmpty) return '补充昨夜休息情况';
  final a = current.total, b = previous?.total;
  if (a == null ||
      b == null ||
      a == SleepTotalBand.unknown ||
      b == SleepTotalBand.unknown) {
    return '持续记录，了解休息变化';
  }
  // The API stores bands, not exact durations. Do not invent a one-hour delta.
  return a.index == b.index
      ? '与前一晚处于相同时长区间'
      : a.index > b.index
      ? '比前一晚休息时长增加'
      : '比前一晚休息时长减少';
}
