import 'package:flutter/material.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';
import '../../../shared/widgets/momcozy_line_icon.dart';
import '../application/baby_home_controller.dart';
import 'baby_labels.dart';
import 'baby_design.dart';
import 'baby_artwork.dart';

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

    onTap: onTap,
    child: BabyArtwork(
      kind: 'feeding',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BabyDesign.asset('IconDrop', width: 28, height: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: BabyDesign.text(
                      hasRecord ? 22 : 16,
                      line: hasRecord ? 31 : 22,
                      weight: FontWeight.w700,
                      color: hasRecord
                          ? MomHomeTokens.ink
                          : MomHomeTokens.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 31,
                  child: Center(
                    child: BabyDesign.asset(
                      'ChevronRightRounded',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              detail,
              style: BabyDesign.text(
                13,
                line: 18,
                color: MomHomeTokens.secondary,
              ),
            ),
          ],
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
    required this.asset,
    required this.gradient,
    required this.artwork,
    required this.onTap,
  });
  final String label, value, detail;
  final bool hasRecord;
  final MomCozyLineGlyph icon;
  final String asset, artwork;
  final Gradient gradient;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    final cumulative = value.startsWith('Total ');
    final heading = Text(
      label == 'Baby\'s mood after feeding' ? 'After-feeding\nmood' : label,
      style: BabyDesign.text(
        label == 'Baby\'s mood after feeding' ? 12 : 14,
        line: label == 'Baby\'s mood after feeding' ? 16 : 20,
        color: MomHomeTokens.secondary,
      ),
    );
    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cumulative || (label == 'Baby\'s mood after feeding' && hasRecord))
          Text(
            cumulative ? 'Total' : 'Latest',
            style: BabyDesign.text(
              12,
              line: 17,
              color: MomHomeTokens.secondary,
            ),
          ),
        Text(
          cumulative ? value.substring('Total '.length) : value,
          style: BabyDesign.text(
            label == 'Baby\'s mood after feeding'
                ? 16
                : hasRecord
                ? 22
                : 16,
            weight: FontWeight.w700,
            line: label == 'Baby\'s mood after feeding' || !hasRecord ? 22 : 31,
            color: hasRecord ? MomHomeTokens.ink : MomHomeTokens.secondary,
          ),
        ),
        if (value == 'Sleeping now')
          Text(
            detail,
            style: BabyDesign.text(
              12,
              line: 17,
              color: MomHomeTokens.secondary,
            ),
          ),
      ],
    );
    final glyph = BabyDesign.asset(asset, width: 28, height: 28);
    return MomHomeSurface(
      semanticLabel: 'Today\'s $label: $value. $detail',
      gradient: gradient,

      onTap: onTap,
      child: BabyArtwork(
        kind: artwork,
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
                      const SizedBox(height: 10),
                      facts,
                    ],
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
            Builder(
              builder: (context) {
                final record = controller.latestGrowth.value
                    ?.where((value) => value.metric == metric)
                    .firstOrNull;
                return SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * gap) / columns,
                  child: Material(
                    color: MomHomeTokens.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MomHomeTokens.cardRadius,
                      ),
                      side: const BorderSide(color: MomHomeTokens.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onRecord(metric),
                      child: BabyArtwork(
                        kind: 'measurement',
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: record == null ? 72 : 106,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                growthMetricLabel(metric),
                                style: BabyDesign.text(
                                  13,
                                  line: 18,
                                  color: MomHomeTokens.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (record != null) ...[
                                Text(
                                  '${babyNumber(record.value)} ${record.unit}',
                                  style: BabyDesign.text(
                                    22,
                                    line: 31,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${record.recordedOn.month}/${record.recordedOn.day}',
                                  style: BabyDesign.text(
                                    12,
                                    line: 17,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                              ] else
                                Text(
                                  controller.latestGrowth.loading
                                      ? 'Loading…'
                                      : controller.latestGrowth.failure != null
                                      ? 'Not loaded yet'
                                      : 'Not recorded yet',
                                  style: const TextStyle(
                                    fontFamily: 'NotoSansSCHome',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: MomHomeTokens.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
