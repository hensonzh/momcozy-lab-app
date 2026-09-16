import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
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
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(MomCozyRadii.featured),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Ink(
        decoration: const BoxDecoration(gradient: MomCozyGradients.lactation),
        child: Container(
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x80fff9f1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const MomCozyLineIcon(
                  MomCozyLineGlyph.baby,
                  size: 26,
                  color: MomCozyColors.warmIcon,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        color: MomCozyColors.statusText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: MomCozyTypography.labelSize,
                        color: MomCozyColors.statusTertiary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const MomCozyLineIcon(
                MomCozyLineGlyph.arrow,
                size: 20,
                color: MomCozyColors.statusIcon,
              ),
            ],
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MomCozyRadii.featured),
        child: ColoredBox(
          color: MomCozyColors.warmQuietSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/me_baby_overview/nursery_camera_clean.png',
                height: 150,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.14),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 78),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0x80fff9f1),
                        borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                      ),
                      child: const MomCozyLineIcon(
                        MomCozyLineGlyph.moon,
                        size: 20,
                        color: MomCozyColors.warmIcon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '睡眠节奏与趋势',
                            style: TextStyle(
                              fontSize: MomCozyTypography.bodySize,
                              fontWeight: FontWeight.w500,
                              color: MomCozyColors.statusText,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '基于连续睡眠记录整理',
                            style: TextStyle(
                              fontSize: MomCozyTypography.labelSize,
                              color: MomCozyColors.statusTertiary,
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
    required this.gradient,
    required this.onTap,
  });
  final String label, value, detail;
  final MomCozyLineGlyph icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 359;
    final cumulative = value.startsWith('累计 ');
    return Semantics(
      label: '今日$label，$value，$detail',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            narrow ? 19 : MomCozyRadii.featured,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(gradient: gradient),
              child: Container(
                constraints: BoxConstraints(minHeight: narrow ? 140 : 148),
                padding: EdgeInsets.symmetric(
                  vertical: narrow ? 14 : 16,
                  horizontal: narrow ? 10 : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MomCozyLineIcon(
                          icon,
                          size: 30,
                          color: MomCozyColors.warmIcon,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: MomCozyTypography.secondarySize,
                            color: MomCozyColors.statusSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cumulative)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              '累计',
                              style: TextStyle(
                                fontSize: MomCozyTypography.microSize,
                                color: MomCozyColors.statusTertiary,
                              ),
                            ),
                          ),
                        Text(
                          cumulative ? value.substring(3) : value,
                          style: TextStyle(
                            fontSize: narrow ? 17 : 20,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: MomCozyColors.statusText,
                          ),
                        ),
                        if (value == '正在睡')
                          Text(
                            detail,
                            style: const TextStyle(
                              fontSize: MomCozyTypography.microSize,
                              color: MomCozyColors.statusTertiary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      final narrow = MediaQuery.sizeOf(context).width < 359;
      final columns = MediaQuery.textScalerOf(context).scale(1) > 1.5 ? 1 : 3;
      final gap = narrow ? 8.0 : 10.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metric in GrowthMetric.values)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * gap) / columns,
              child: Material(
                color: MomCozyColors.warmMetricSurface,
                borderRadius: BorderRadius.circular(MomCozyRadii.card),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onRecord(metric),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 106),
                    padding: EdgeInsets.symmetric(
                      vertical: narrow ? 14 : 15,
                      horizontal: narrow ? 10 : 12,
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
                                fontSize: MomCozyTypography.captionSize,
                                color: MomCozyColors.statusSecondary,
                              ),
                            ),
                            const SizedBox(height: 9),
                            if (record != null) ...[
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: babyNumber(record.value)),
                                    TextSpan(
                                      text: ' ${record.unit}',
                                      style: const TextStyle(
                                        fontSize: MomCozyTypography.labelSize,
                                        color: MomCozyColors.statusTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  fontSize: narrow ? 21 : 24,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                  color: MomCozyColors.statusText,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                '${record.recordedOn.month}/${record.recordedOn.day}',
                                style: const TextStyle(
                                  fontSize: MomCozyTypography.microSize,
                                  color: MomCozyColors.statusTertiary,
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
                                  fontSize: MomCozyTypography.titleSize,
                                  fontWeight: FontWeight.w500,
                                  color: MomCozyColors.statusIcon,
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
