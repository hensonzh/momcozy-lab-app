import 'baby_motion.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/baby/growth_reference.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/resource_state.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/product_feedback.dart';
import 'baby_labels.dart';
import 'baby_design.dart';
import 'baby_artwork.dart';
import '../../../shared/widgets/mom_companion_widgets.dart';

class BabyGrowthCurve extends StatelessWidget {
  const BabyGrowthCurve({
    super.key,
    required this.baby,
    required this.metric,
    required this.records,
    required this.onMetricChanged,
    required this.onEditProfile,
    required this.onRetry,
  });
  final BabyProfile baby;
  final GrowthMetric metric;
  final ResourceState<List<BabyGrowthRecord>> records;
  final ValueChanged<GrowthMetric> onMetricChanged;
  final VoidCallback onEditProfile, onRetry;

  @override
  Widget build(BuildContext context) {
    final birth = baby.birthDate;
    final references = whoReferencePoints(metric, baby.sex, birth);
    final end = birth?.addMonths(whoGrowthMaxMonths);
    final visible =
        (records.value ?? [])
            .where(
              (record) =>
                  record.babyId == baby.id &&
                  record.metric == metric &&
                  birth != null &&
                  end != null &&
                  record.recordedOn.compareTo(birth) >= 0 &&
                  record.recordedOn.compareTo(end) <= 0,
            )
            .toList()
          ..sort((a, b) {
            final date = a.recordedOn.compareTo(b.recordedOn);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
    final unit = metric == GrowthMetric.weight ? 'kg' : 'cm';
    final metricButtons = <Widget>[
      for (final value in GrowthMetric.values)
        Semantics(
          selected: value == metric,
          child: BabyPressFeedback(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: value == metric
                    ? BabyDesign.selectedInk
                    : MomHomeTokens.rose,
                backgroundColor: value == metric
                    ? BabyDesign.selected
                    : Colors.transparent,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: BabyDesign.text(
                  13,
                  line: 18,
                  weight: FontWeight.w700,
                ),
              ),
              onPressed: () => onMetricChanged(value),
              child: Text(growthMetricLabel(value)),
            ),
          ),
        ),
    ];
    return MomHomeSurface(
      gradient: const LinearGradient(
        colors: [MomHomeTokens.surface, MomHomeTokens.surface],
      ),
      border: MomHomeTokens.border,
      borderInside: true,
      child: BabyArtwork(
        kind: 'chart',
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '生长趋势',
                style: BabyDesign.text(16, line: 22, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '出生至 6 月 · ${babySexLabel(baby.sex)} · $unit',
                style: BabyDesign.text(
                  12,
                  line: 17,
                  color: MomHomeTokens.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: MomHomeTokens.neutralSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final button in metricButtons) Expanded(child: button),
                  ],
                ),
              ),
              if (references.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 11),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MomHomeTokens.neutralSurface,
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '补充出生日期和出生记录性别后，才能显示对应的生长参考范围。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: MomCozyTypography.captionSize,
                        ),
                      ),
                      BabyPressFeedback(
                        child: TextButton(
                          onPressed: onEditProfile,
                          child: const Text('完善资料'),
                        ),
                      ),
                    ],
                  ),
                )
              else if (records.failure != null && !records.hasValue) ...[
                const SizedBox(height: 11),
                ProductErrorView(
                  useMomStyle: true,
                  compactMomStyle: true,
                  failure: records.failure!,
                  onRetry: onRetry,
                ),
              ] else if (records.loading && !records.hasValue)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: _BabyDottedLoader()),
                )
              else ...[
                const SizedBox(height: 12),
                Semantics(
                  label:
                      '${baby.name}的${growthMetricLabel(metric)}记录，出生至六个月。${visible.isEmpty ? '这段时间还没有测量记录。' : visible.map((record) => '${record.recordedOn}：${babyNumber(record.value)} $unit').join('；')}。浅绿色为 WHO 同龄参考范围。',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height:
                          145 *
                          MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
                      child: CustomPaint(
                        painter: _GrowthPainter(
                          birth: birth!,
                          metric: metric,
                          records: visible,
                          references: references,
                          textScaler: MediaQuery.textScalerOf(context),
                          scale: GrowthChartScale.forRecords(metric, visible),
                        ),
                      ),
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '出生至六个月还没有测量记录。',
                      style: TextStyle(
                        fontSize: 13,
                        color: MomHomeTokens.secondary,
                      ),
                    ),
                  ),
              ],
              if (references.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: MomHomeTokens.border),
                const SizedBox(height: 12),
                Text(
                  '${visible.isEmpty ? '记录后会显示${baby.name}的变化' : '深色线是 ${baby.name} 的记录'}，浅绿色为 WHO 同龄参考范围。适合观察长期变化，不能根据单次测量下结论。',
                  style: BabyDesign.text(
                    13,
                    line: 18,
                    color: MomHomeTokens.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BabyDottedLoader extends StatelessWidget {
  const _BabyDottedLoader();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28,
    height: 28,
    child: CustomPaint(painter: _BabyDottedLoaderPainter()),
  );
}

class _BabyDottedLoaderPainter extends CustomPainter {
  const _BabyDottedLoaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = MomHomeTokens.rose;
    const dots = 16;
    const radius = 11.5;
    for (var index = 0; index < dots; index++) {
      final angle = -math.pi / 2 + index * 2 * math.pi / dots;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(point, 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.birth,
    required this.metric,
    required this.records,
    required this.references,
    required this.textScaler,
    required this.scale,
  });
  final LocalDate birth;
  final GrowthMetric metric;
  final List<BabyGrowthRecord> records;
  final List<GrowthReferencePoint> references;
  final TextScaler textScaler;
  final GrowthChartScale scale;

  @override
  void paint(Canvas canvas, Size size) {
    final font = textScaler.scale(10);
    final plot = Rect.fromLTRB(
      math.min(font * 3.5, size.width * .28),
      10,
      size.width - font * 1.8,
      size.height - font * 2.8,
    );
    final days = birth.addMonths(whoGrowthMaxMonths).daysSince(birth);
    double x(int age) => plot.left + age / days * plot.width;
    double y(double value) =>
        plot.bottom -
        (value - scale.minimum) / (scale.maximum - scale.minimum) * plot.height;
    void label(
      String value,
      Offset point, {
      bool right = false,
      bool center = false,
    }) {
      final text = TextPainter(
        text: TextSpan(
          text: value,
          style: BabyDesign.text(
            font,
            line: font * 1.4,
            color: MomHomeTokens.secondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          point.dx -
              (right
                  ? text.width
                  : center
                  ? text.width / 2
                  : 0),
          point.dy - text.height / 2,
        ),
      );
    }

    for (var index = 0; index <= 4; index++) {
      final value = scale.minimum + (scale.maximum - scale.minimum) * index / 4;
      canvas.drawLine(
        Offset(plot.left, y(value)),
        Offset(plot.right, y(value)),
        Paint()..color = MomHomeTokens.border,
      );
      label(value.toStringAsFixed(1), Offset(0, y(value)));
    }
    for (final month in [0, 2, 4, 6]) {
      label(
        '$month月',
        Offset(
          x(birth.addMonths(month).daysSince(birth)),
          plot.bottom + font * 1.5,
        ),
        center: true,
      );
    }
    final lower = Path(), upper = Path(), band = Path();
    for (var i = 0; i < references.length; i++) {
      final point = references[i];
      if (i == 0) {
        lower.moveTo(x(point.ageDays), y(point.lower));
        upper.moveTo(x(point.ageDays), y(point.upper));
        band.moveTo(x(point.ageDays), y(point.lower));
      } else {
        lower.lineTo(x(point.ageDays), y(point.lower));
        upper.lineTo(x(point.ageDays), y(point.upper));
        band.lineTo(x(point.ageDays), y(point.lower));
      }
    }
    for (final point in references.reversed) {
      band.lineTo(x(point.ageDays), y(point.upper));
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()..color = MomHomeTokens.mint.withValues(alpha: .78),
    );
    final boundary = Paint()
      ..color = MomHomeTokens.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final path in [lower, upper]) {
      for (final metric in path.computeMetrics()) {
        for (var distance = 0.0; distance < metric.length; distance += 7) {
          canvas.drawPath(
            metric.extractPath(distance, math.min(distance + 3, metric.length)),
            boundary,
          );
        }
      }
    }
    final actual = Path();
    final points = [
      for (final record in records)
        Offset(x(record.recordedOn.daysSince(birth)), y(record.value)),
    ];
    for (var i = 0; i < points.length; i++) {
      if (i == 0) {
        actual.moveTo(points[i].dx, points[i].dy);
      } else {
        actual.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(
      actual,
      Paint()
        ..color = MomHomeTokens.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = MomHomeTokens.surface);
      canvas.drawCircle(point, 3.5, Paint()..color = MomHomeTokens.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) =>
      oldDelegate.birth != birth ||
      oldDelegate.metric != metric ||
      oldDelegate.records != records ||
      oldDelegate.textScaler != textScaler;
}
