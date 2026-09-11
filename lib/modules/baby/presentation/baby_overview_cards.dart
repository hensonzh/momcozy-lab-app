import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../application/baby_home_controller.dart';
import 'baby_labels.dart';

class BabyFeedingSummary extends StatelessWidget {
  const BabyFeedingSummary({
    super.key,
    required this.value,
    required this.detail,
    required this.onTap,
  });
  final String value, detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: MomCozyColors.card,
    borderRadius: BorderRadius.circular(MomCozyRadii.card),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MomCozyRadii.card),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: MomCozyColors.border),
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: MomCozyColors.roseSoft,
                borderRadius: BorderRadius.circular(MomCozyRadii.badge),
              ),
              child: const Icon(
                Icons.child_care,
                color: MomCozyColors.primaryDark,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: MomCozyTypography.bodySize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: MomCozyTypography.labelSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward,
              color: MomCozyColors.primaryDark,
              size: 17,
            ),
          ],
        ),
      ),
    ),
  );
}

class BabySleepMonitor extends StatelessWidget {
  const BabySleepMonitor({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: '睡眠监测，即将开放',
    child: ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: MomCozyColors.border),
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/me_baby_overview/nursery_camera_clean.png',
                height: 116,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.14),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: MomCozyColors.violetSoft,
                        borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                      ),
                      child: const Icon(
                        Icons.nightlight_outlined,
                        size: 16,
                        color: MomCozyColors.knowledgeLabel,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '睡眠节奏与趋势',
                            style: TextStyle(
                              fontSize: MomCozyTypography.secondarySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '基于连续睡眠记录整理',
                            style: TextStyle(
                              fontSize: MomCozyTypography.microSize,
                              color: MomCozyColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BabyStatusCard extends StatelessWidget {
  const BabyStatusCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final String label, value, detail;
  final IconData icon;
  final Color color, background;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '今日$label，$value，$detail',
    button: true,
    child: ExcludeSemantics(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MomCozyRadii.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                  ),
                  child: Icon(icon, color: color, size: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: MomCozyTypography.labelSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: MomCozyTypography.bodySize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class BabyGrowthMetrics extends StatelessWidget {
  const BabyGrowthMetrics({
    super.key,
    required this.controller,
    required this.onRecord,
  });
  final BabyHomeController controller;
  final ValueChanged<GrowthMetric> onRecord;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 1 : 3;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final metric in GrowthMetric.values)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 6) / columns,
              child: Material(
                color: MomCozyColors.card,
                borderRadius: BorderRadius.circular(MomCozyRadii.card),
                child: InkWell(
                  onTap: () => onRecord(metric),
                  borderRadius: BorderRadius.circular(MomCozyRadii.card),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(MomCozyRadii.card),
                      border: Border.all(color: MomCozyColors.border),
                    ),
                    child: Builder(
                      builder: (context) {
                        final record = controller.latestGrowth.value
                            ?.where((value) => value.metric == metric)
                            .firstOrNull;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              growthMetricLabel(metric),
                              style: const TextStyle(
                                fontSize: MomCozyTypography.microSize,
                                fontWeight: FontWeight.w700,
                                color: MomCozyColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (record != null) ...[
                              Text(
                                '${babyNumber(record.value)} ${record.unit}',
                                style: const TextStyle(
                                  fontSize: MomCozyTypography.bodyLargeSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                record.recordedOn.toString(),
                                style: const TextStyle(
                                  fontSize: MomCozyTypography.microSize,
                                  color: MomCozyColors.mutedForeground,
                                ),
                              ),
                            ] else
                              Text(
                                controller.latestGrowth.loading
                                    ? '载入中…'
                                    : controller.latestGrowth.failure != null
                                    ? '暂未载入'
                                    : '未记录',
                                style: const TextStyle(
                                  fontSize: MomCozyTypography.captionSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
