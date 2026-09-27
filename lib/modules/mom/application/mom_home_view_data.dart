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
    eyebrow: 'Momcozy AI · Waiting for your first record',
    title: 'Start with a record.\nI\'ll get to know your recovery as you go.',
    body:
        'Track pumping and nursing, or talk with Momcozy AI about feeding and recovery.',
  );
  static const unavailable = MomDailyInsight(
    status: MomInsightStatus.unavailable,
    eyebrow: 'Momcozy AI · Daily insights unavailable',
    title: 'Notice the little changes,\nwith Momcozy AI by your side',
    body:
        'Daily insights aren\'t available right now. You can still talk with Momcozy AI about your day.',
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
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final milk = c.milk;
    final hasMilk = (milk?.recordCount ?? 0) > 0;
    return MomHomeViewData(
      greeting:
          '$greeting${profile?.displayName.isNotEmpty == true ? ', ${profile!.displayName}' : ''}',
      phaseLabel: day == null
          ? 'Here for every stage'
          : formatPostpartumDay(day),
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
                ? '${milk.nursingMinutes} min'
                : '${milk.recordCount} times'
          : c.lactation.loading
          ? 'Loading…'
          : c.lactation.failure != null
          ? 'Not loaded yet'
          : 'Not recorded yet',
      lactationMeta: hasMilk
          ? 'Pumping ${milk!.pumpCount} times · Nursing ${milk.nursingCount} times'
          : 'Log pumping and nursing to see daily changes',
    );
  }
}
