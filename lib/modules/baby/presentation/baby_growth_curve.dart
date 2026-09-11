import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/baby/growth_reference.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/resource_state.dart';
import '../../../shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';
import 'baby_labels.dart';

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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 9),
      decoration: BoxDecoration(
        color: MomCozyColors.card,
        border: Border.all(color: MomCozyColors.border),
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '生长趋势',
                    style: TextStyle(
                      fontSize: MomCozyTypography.secondarySize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '出生至 6 月 · ${babySexLabel(baby.sex)} · $unit',
                    style: const TextStyle(
                      fontSize: MomCozyTypography.microSize,
                      color: MomCozyColors.mutedForeground,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final value in GrowthMetric.values)
                    Semantics(
                      selected: value == metric,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: value == metric
                              ? MomCozyColors.care
                              : MomCozyColors.mutedForeground,
                          backgroundColor: value == metric
                              ? MomCozyColors.careSoft
                              : Colors.transparent,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: MomCozyTypography.bodyFontFamily,
                            fontFamilyFallback:
                                MomCozyTypography.fontFamilyFallback,
                            fontSize: MomCozyTypography.microSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => onMetricChanged(value),
                        child: Text(growthMetricLabel(value)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (references.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MomCozyColors.secondary,
                borderRadius: BorderRadius.circular(MomCozyRadii.control),
              ),
              child: Column(
                children: [
                  const Text(
                    '补充出生日期和出生记录性别后，才能显示对应的生长参考范围。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: MomCozyTypography.captionSize),
                  ),
                  TextButton(
                    onPressed: onEditProfile,
                    child: const Text('完善资料'),
                  ),
                ],
              ),
            )
          else if (records.failure != null)
            ProductErrorView(failure: records.failure!, onRetry: onRetry)
          else if (records.loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: 8),
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
                    fontSize: MomCozyTypography.labelSize,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: MomCozyColors.border),
          const SizedBox(height: 8),
          Text(
            '深色线是${baby.name}的记录，浅绿色为 WHO 同龄参考范围。适合观察长期变化，不能根据单次测量下结论。',
            style: const TextStyle(
              fontSize: MomCozyTypography.microSize,
              color: MomCozyColors.mutedForeground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
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
    final font = textScaler.scale(9);
    final plot = Rect.fromLTRB(
      math.min(font * 3.5, size.width * .28),
      10,
      size.width - font * 1.6,
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
          style: TextStyle(
            fontSize: font,
            color: MomCozyColors.mutedForeground,
            fontFamily: MomCozyTypography.bodyFontFamily,
            fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
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
        Paint()..color = MomCozyColors.border,
      );
      label(
        value.toStringAsFixed(1),
        Offset(plot.left - 6, y(value)),
        right: true,
      );
    }
    for (final month in [0, 2, 4, 6]) {
      label(
        '$month月',
        Offset(
          x(birth.addMonths(month).daysSince(birth)),
          plot.bottom + font * 1.8,
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
      Paint()..color = MomCozyColors.careSoft.withValues(alpha: .78),
    );
    final boundary = Paint()
      ..color = MomCozyColors.border
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
        ..color = MomCozyColors.foreground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = MomCozyColors.card);
      canvas.drawCircle(point, 3.5, Paint()..color = MomCozyColors.foreground);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) =>
      oldDelegate.birth != birth ||
      oldDelegate.metric != metric ||
      oldDelegate.records != records ||
      oldDelegate.textScaler != textScaler;
}
