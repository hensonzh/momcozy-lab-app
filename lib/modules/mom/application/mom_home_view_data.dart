import '../../../domain/mother/postpartum_stage.dart';
import '../../../domain/shared/local_date.dart';
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
    body: '可以记录泵奶与亲喂，也可以与 Cozymate 交流喂养和恢复情况。',
  );
  static const unavailable = MomDailyInsight(
    status: MomInsightStatus.unavailable,
    eyebrow: 'Cozymate · 每日分析暂不可用',
    title: '记录每一点变化，\n与 Cozymate 一起了解自己',
    body: '每日分析暂不可用，你仍可以与 Cozymate 交流今天的状态。',
  );
}

class MomHomeViewData {
  const MomHomeViewData({
    required this.greeting,
    required this.phaseLabel,
    required this.insight,
    required this.hasTodayRecords,
    required this.lactationValue,
    required this.lactationMeta,
    this.lactationRecorded = false,
  });
  final String greeting, phaseLabel, lactationValue, lactationMeta;
  final MomDailyInsight insight;
  final bool hasTodayRecords, lactationRecorded;

  factory MomHomeViewData.fromController(MotherHomeController c) {
    final profile = c.profile.value;
    final day = profile?.postpartumDay(c.date);
    final hour = c.now().toLocal().hour;
    final greeting = hour < 12
        ? '早上好'
        : hour < 18
        ? '下午好'
        : '晚上好';
    final milk = c.milk;
    final hasMilk = (milk?.recordCount ?? 0) > 0;
    return MomHomeViewData(
      greeting:
          '$greeting${profile?.displayName.isNotEmpty == true ? '，${profile!.displayName}' : ''}',
      phaseLabel: day == null ? '陪伴每个阶段' : formatPostpartumDay(day),
      insight: hasMilk
          ? c.insight.value ?? MomDailyInsight.unavailable
          : c.lactation.hasValue
          ? MomDailyInsight.waiting
          : MomDailyInsight.unavailable,
      hasTodayRecords: hasMilk,
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
          : '待记录',
      lactationMeta: hasMilk
          ? '泵奶 ${milk!.pumpCount} 次 · 亲喂 ${milk.nursingCount} 次'
          : '记录泵奶与亲喂，了解每天的变化',
    );
  }
}
