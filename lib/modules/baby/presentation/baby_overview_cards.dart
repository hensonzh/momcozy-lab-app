import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/baby_home_controller.dart';
import 'baby_labels.dart';

class BabyFeedingSummary extends StatelessWidget {
  const BabyFeedingSummary({
    super.key,
    required this.value,
    required this.hasRecord,
    required this.detail,
    required this.onTap,
  });
  final String value, detail;
  final bool hasRecord;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => MomHomeSurface(
    gradient: MomHomeTokens.milk,
    backgroundDecoration: MomCardDecoration.feeding,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const MomCozyLineIcon(
                MomCozyLineGlyph.drop,
                size: 28,
                color: MomHomeTokens.rose,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: MomHomeTokens.text(
                    hasRecord ? 22 : 18,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const MomCozyLineIcon(
                MomCozyLineGlyph.arrow,
                size: 22,
                color: MomHomeTokens.rose,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
          ),
        ],
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
        borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
        child: ColoredBox(
          color: MomHomeTokens.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/me_baby_overview/nursery_camera_clean.png',
                height: 150,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -.14),
              ),
              MomCardBackground(
                decoration: MomCardDecoration.monitor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '睡眠节奏与趋势',
                        style: MomHomeTokens.text(14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '基于连续睡眠记录整理',
                        style: MomHomeTokens.text(
                          12,
                          color: MomHomeTokens.secondary,
                        ),
                      ),
                    ],
                  ),
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
    required this.hasRecord,
    required this.detail,
    required this.icon,
    required this.gradient,
    required this.backgroundDecoration,
    required this.onTap,
  });
  final String label, value, detail;
  final bool hasRecord;
  final MomCozyLineGlyph icon;
  final Gradient gradient;
  final MomCardDecoration backgroundDecoration;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final cumulative = value.startsWith('累计 ');
    final heading = Text(
      label,
      style: MomHomeTokens.text(14, color: MomHomeTokens.secondary),
    );
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cumulative)
          Text(
            '累计',
            style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
          ),
        Text(
          cumulative ? value.substring(3) : value,
          style: MomHomeTokens.text(
            hasRecord ? 22 : 18,
            weight: FontWeight.w700,
          ),
        ),
        if (value == '正在睡')
          Text(
            detail,
            style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
          ),
      ],
    );
    final glyph = MomCozyLineIcon(icon, size: 28, color: MomHomeTokens.teal);
    return MomHomeSurface(
      semanticLabel: '今日$label，$value，$detail',
      gradient: gradient,
      backgroundDecoration: backgroundDecoration,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: large ? 0 : 148),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: large
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    glyph,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [heading, const SizedBox(height: 8), facts],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [glyph, const SizedBox(height: 8), heading],
                    ),
                    const SizedBox(height: 16),
                    facts,
                  ],
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
                color: MomHomeTokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
                  side: const BorderSide(color: MomHomeTokens.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onRecord(metric),
                  child: MomCardBackground(
                    decoration: MomCardDecoration.measurement,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 106),
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
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
                                  fontFamily: 'NotoSansSCHome',
                                  fontSize: 13,
                                  color: MomHomeTokens.secondary,
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
                                          fontFamily: 'NotoSansSCHome',
                                          fontSize: 22,
                                          color: MomHomeTokens.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'NotoSansSCHome',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    color: MomHomeTokens.ink,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  '${record.recordedOn.month}/${record.recordedOn.day}',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansSCHome',
                                    fontSize: 12,
                                    color: MomHomeTokens.secondary,
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
                                    fontFamily: 'NotoSansSCHome',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: MomHomeTokens.secondary,
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
            ),
        ],
      );
    },
  );
}
