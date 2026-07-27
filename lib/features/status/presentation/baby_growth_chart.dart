import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/records/domain/records.dart';
import 'package:app/features/status/domain/baby_status_projection.dart';
import 'package:app/features/status/presentation/status_dashboard_controller.dart';

class BabyGrowthChart extends StatefulWidget {
  const BabyGrowthChart({
    super.key,
    required this.records,
    required this.birthDate,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  final ValueListenable<StatusResource<List<GrowthRecord>>> records;
  final DateTime? birthDate;
  final String selectedMetric;
  final ValueChanged<String> onMetricChanged;

  @override
  State<BabyGrowthChart> createState() => _BabyGrowthChartState();
}

class _BabyGrowthChartState extends State<BabyGrowthChart> {
  var _expanded = true;
  int? _selectedPoint;

  @override
  void didUpdateWidget(covariant BabyGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMetric != widget.selectedMetric) {
      _selectedPoint = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('status-baby-growth-curve-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffbf7ff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe6d9fb)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('status-baby-growth-chart-toggle'),
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xffe6d9fb),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    size: 16,
                    color: Color(0xff7d64aa),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '宝宝成长曲线',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ValueListenableBuilder<StatusResource<List<GrowthRecord>>>(
                valueListenable: widget.records,
                builder: (context, resource, _) {
                  final projection = BabyGrowthProjection(
                    records: resource.data ?? const <GrowthRecord>[],
                    birthDate: widget.birthDate,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GrowthChartToolbar(
                        selectedMetric: widget.selectedMetric,
                        onMetricChanged: widget.onMetricChanged,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '当前查看：${widget.selectedMetric}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xff7d64aa),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GrowthChartBody(
                        resource: resource,
                        projection: projection,
                        selectedMetric: widget.selectedMetric,
                        selectedPoint: _selectedPoint,
                        onPointSelected: (index) {
                          setState(() => _selectedPoint = index);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartToolbar extends StatelessWidget {
  const _GrowthChartToolbar({
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  final String selectedMetric;
  final ValueChanged<String> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _GrowthLegend(label: '实际测量', color: Color(0xff7d64aa)),
        const SizedBox(width: 8),
        const _GrowthLegend(
          label: '同龄参考区间',
          color: Color(0xffeee6ff),
          band: true,
        ),
        const Spacer(),
        Container(
          height: 25,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xfff2ecff),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            children: [
              for (final metric in const ['体重', '身高'])
                InkWell(
                  key: ValueKey('status-baby-growth-segment-$metric'),
                  onTap: () => onMetricChanged(metric),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    width: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedMetric == metric
                          ? const Color(0xff7d64aa)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      metric,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selectedMetric == metric
                            ? Colors.white
                            : const Color(0xff7560a0),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrowthChartBody extends StatelessWidget {
  const _GrowthChartBody({
    required this.resource,
    required this.projection,
    required this.selectedMetric,
    required this.selectedPoint,
    required this.onPointSelected,
  });

  final StatusResource<List<GrowthRecord>> resource;
  final BabyGrowthProjection projection;
  final String selectedMetric;
  final int? selectedPoint;
  final ValueChanged<int> onPointSelected;

  @override
  Widget build(BuildContext context) {
    if (resource.isLoading || resource.phase == StatusResourcePhase.initial) {
      return const _GrowthChartMessage(text: '正在加载生长发育历史…');
    }
    if (resource.hasError && resource.data == null) {
      return const _GrowthChartMessage(text: '生长发育历史暂时无法同步，请稍后重试。');
    }
    if (projection.chartPoints.isEmpty) {
      return const _GrowthChartMessage(text: '暂无成长曲线数据，录入多项测量后与同龄参考一同展示。');
    }
    final points = projection.chartPoints;
    final activeIndex = selectedPoint?.clamp(0, points.length - 1);
    return Semantics(
      label: '宝宝成长曲线，$selectedMetric，共 ${points.length} 个周数据点',
      child: SizedBox(
        key: const ValueKey('status-baby-growth-chart'),
        height: 188,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const chartLeft = 43.0;
            const chartRight = 8.0;
            final chartWidth = math.max(
              1.0,
              constraints.maxWidth - chartLeft - chartRight,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                final ratio =
                    ((details.localPosition.dx - chartLeft) / chartWidth).clamp(
                      0.0,
                      1.0,
                    );
                onPointSelected((ratio * (points.length - 1)).round());
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _GrowthChartPainter(
                          points: points,
                          weekTicks: projection.weekTicks,
                          metric: selectedMetric,
                          selectedIndex: activeIndex,
                        ),
                      ),
                    ),
                  ),
                  if (activeIndex != null)
                    Positioned(
                      key: const ValueKey('status-baby-growth-tooltip'),
                      top: 2,
                      left: _tooltipLeft(
                        activeIndex,
                        points.length,
                        chartLeft,
                        chartWidth,
                        constraints.maxWidth,
                      ),
                      child: _GrowthTooltip(
                        point: points[activeIndex],
                        metric: selectedMetric,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  const _GrowthChartPainter({
    required this.points,
    required this.weekTicks,
    required this.metric,
    required this.selectedIndex,
  });

  final List<BabyGrowthChartPoint> points;
  final List<String> weekTicks;
  final String metric;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 43.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 25.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final actual = metric == '体重'
        ? points.map((point) => point.weightKg).toList(growable: false)
        : points.map((point) => point.heightCm).toList(growable: false);
    final lower = metric == '体重'
        ? points.map((point) => point.weightP25).toList(growable: false)
        : points.map((point) => point.heightP25).toList(growable: false);
    final upper = metric == '体重'
        ? points.map((point) => point.weightP75).toList(growable: false)
        : points.map((point) => point.heightP75).toList(growable: false);
    final values = <double>[...actual, ...lower, ...upper];
    final rawMin = values.reduce(math.min);
    final rawMax = values.reduce(math.max);
    final padding = metric == '体重'
        ? math.max(0.15, (rawMax - rawMin) * 0.12)
        : math.max(1.0, (rawMax - rawMin) * 0.12);
    final minY = math.max(metric == '体重' ? 1.5 : 40, rawMin - padding);
    final maxY = rawMax + padding;
    final span = math.max(0.01, maxY - minY);
    double x(int index) => points.length == 1
        ? chart.center.dx
        : chart.left + chart.width * index / (points.length - 1);
    double y(double value) =>
        chart.bottom - (value - minY) / span * chart.height;

    final gridPaint = Paint()
      ..color = const Color(0xffeadff8)
      ..strokeWidth = 1;
    for (var line = 0; line < 4; line += 1) {
      final lineY = chart.top + chart.height * line / 3;
      _drawDashedLine(
        canvas,
        Offset(chart.left, lineY),
        Offset(chart.right, lineY),
        gridPaint,
      );
      final value = maxY - span * line / 3;
      _paintText(
        canvas,
        '${_compact(value)} ${metric == '体重' ? 'kg' : 'cm'}',
        Offset(0, lineY - 6),
        const TextStyle(color: Color(0xff7560a0), fontSize: 9),
        maxWidth: left - 4,
        align: TextAlign.right,
      );
    }

    final band = Path()..moveTo(x(0), y(upper[0]));
    for (var index = 1; index < points.length; index += 1) {
      band.lineTo(x(index), y(upper[index]));
    }
    for (var index = points.length - 1; index >= 0; index -= 1) {
      band.lineTo(x(index), y(lower[index]));
    }
    band.close();
    canvas.drawPath(band, Paint()..color = const Color(0xcceee6ff));

    final lineColor = metric == '体重'
        ? const Color(0xff7d64aa)
        : const Color(0xff9479c4);
    final line = Path()..moveTo(x(0), y(actual[0]));
    for (var index = 1; index < points.length; index += 1) {
      line.lineTo(x(index), y(actual[index]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var index = 0; index < points.length; index += 1) {
      final center = Offset(x(index), y(actual[index]));
      canvas.drawCircle(
        center,
        selectedIndex == index ? 5 : 4,
        Paint()..color = const Color(0xfff7fffc),
      );
      canvas.drawCircle(
        center,
        selectedIndex == index ? 5 : 4,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selectedIndex == index ? 2 : 1.5,
      );
    }

    final tickSet = weekTicks.toSet();
    for (var index = 0; index < points.length; index += 1) {
      final label = points[index].weekLabel;
      if (!tickSet.contains(label)) continue;
      _paintText(
        canvas,
        label,
        Offset(x(index) - 14, chart.bottom + 7),
        const TextStyle(color: Color(0xff7560a0), fontSize: 9),
        maxWidth: 28,
        align: TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.weekTicks != weekTicks ||
        oldDelegate.metric != metric ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _GrowthTooltip extends StatelessWidget {
  const _GrowthTooltip({required this.point, required this.metric});

  final BabyGrowthChartPoint point;
  final String metric;

  @override
  Widget build(BuildContext context) {
    final value = metric == '体重' ? point.weightKg : point.heightCm;
    final unit = metric == '体重' ? 'kg' : 'cm';
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe6d9fb)),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Text(
        '${point.weekLabel}  ${_compact(value)}$unit',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: const Color(0xff67548e),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GrowthLegend extends StatelessWidget {
  const _GrowthLegend({
    required this.label,
    required this.color,
    this.band = false,
  });

  final String label;
  final Color color;
  final bool band;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: band ? 8 : 2, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: const Color(0xff7560a0),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GrowthChartMessage extends StatelessWidget {
  const _GrowthChartMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: MomCozyColors.mutedForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

double _tooltipLeft(
  int index,
  int count,
  double chartLeft,
  double chartWidth,
  double totalWidth,
) {
  final pointX = count == 1
      ? chartLeft + chartWidth / 2
      : chartLeft + chartWidth * index / (count - 1);
  return (pointX - 42).clamp(0, math.max(0, totalWidth - 84));
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 3.0;
  const gap = 3.0;
  var x = start.dx;
  while (x < end.dx) {
    canvas.drawLine(
      Offset(x, start.dy),
      Offset(math.min(x + dash, end.dx), end.dy),
      paint,
    );
    x += dash + gap;
  }
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset,
  TextStyle style, {
  required double maxWidth,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, offset);
}

String _compact(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
