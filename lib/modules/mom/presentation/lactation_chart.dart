import '../../../shared/design_system/momcozy_design_system.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/shared/local_date.dart';
import '../application/lactation_controller.dart';

class LactationTrendChart extends StatefulWidget {
  const LactationTrendChart({super.key, required this.controller});
  final LactationController controller;
  @override
  State<LactationTrendChart> createState() => _LactationTrendChartState();
}

class _LactationTrendChartState extends State<LactationTrendChart> {
  int _days = 7;
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final days = List.generate(
      _days,
      (index) => controller.date.addDays(index - _days + 1),
    );
    final values = days
        .map((day) => controller.summary(day).measuredVolumeMl)
        .toList();
    final measured = values.whereType<double>().length;
    return Container(
      color: MomCozyColors.milkChartBackground,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(
          context,
        ).style.copyWith(color: MomCozyColors.milkChartInk),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.water_drop_outlined,
                  color: MomCozyColors.milkChartInk,
                  size: 23,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    '奶量趋势',
                    style: TextStyle(
                      fontSize: MomCozyTypography.bodyLargeSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ToggleButtons(
                  isSelected: [_days == 7, _days == 30],
                  onPressed: (index) =>
                      setState(() => _days = index == 0 ? 7 : 30),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 36,
                  ),
                  borderRadius: BorderRadius.circular(MomCozyRadii.badge),
                  color: MomCozyColors.milkChartMuted,
                  selectedColor: MomCozyColors.milkChartInk,
                  fillColor: MomCozyColors.milkChartSelection,
                  borderColor: MomCozyColors.milkChartBorder,
                  selectedBorderColor: MomCozyColors.milkChartBorder,
                  children: const [
                    Text(
                      '7天',
                      style: TextStyle(fontSize: MomCozyTypography.captionSize),
                    ),
                    Text(
                      '30天',
                      style: TextStyle(fontSize: MomCozyTypography.captionSize),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: values.last == null ? '—' : _number(values.last!),
                    style: const TextStyle(
                      fontSize: MomCozyTypography.heroMetricSize,
                      height: 1.1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const TextSpan(
                    text: ' ml',
                    style: TextStyle(
                      color: MomCozyColors.milkChartMuted,
                      fontSize: MomCozyTypography.bodyLargeSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '今日泵奶量',
              style: TextStyle(
                color: MomCozyColors.milkChartMuted,
                fontSize: MomCozyTypography.secondarySize,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label:
                  '$_days天泵奶量趋势。${List.generate(days.length, (index) => '${days[index].month}月${days[index].day}日：${values[index] == null ? '未记录' : '${_number(values[index]!)}毫升'}').join('；')}',
              child: ExcludeSemantics(
                child: AspectRatio(
                  aspectRatio: 320 / 192,
                  child: CustomPaint(painter: _TrendPainter(days, values)),
                ),
              ),
            ),
            Text(
              measured == 0
                  ? '暂无泵奶量记录，添加后即可查看趋势'
                  : measured == 1
                  ? '目前仅有一天数据，连续记录后可查看曲线'
                  : '仅展示已记录的泵奶量，未记录日期留空',
              style: const TextStyle(
                fontSize: MomCozyTypography.microSize,
                color: MomCozyColors.milkChartMuted,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _number(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.days, this.values);
  final List<LocalDate> days;
  final List<double?> values;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320;
    canvas.save();
    canvas.scale(scale, size.height / 192);
    final maximum =
        math.max(50, values.whereType<double>().fold<double>(0, math.max)) *
        1.3;
    double x(int index) => 20 + index * 280 / (days.length - 1);
    double y(double value) => 150 - value / maximum * 108;
    final baseline = Paint()
      ..color = MomCozyColors.milkChartGrid
      ..strokeWidth = 1;
    for (double left = 20; left < 300; left += 7) {
      canvas.drawLine(Offset(left, 150), Offset(left + 3, 150), baseline);
    }
    final line = Paint()
      ..color = MomCozyColors.milkChartInk
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < days.length; index++) {
      final value = values[index];
      final pointX = x(index);
      if (value != null) {
        final pointY = y(value);
        final previous = index == 0 ? null : values[index - 1];
        if (previous != null) {
          final middle = (x(index - 1) + pointX) / 2;
          canvas.drawPath(
            Path()
              ..moveTo(x(index - 1), y(previous))
              ..cubicTo(middle, y(previous), middle, pointY, pointX, pointY),
            line,
          );
        }
        if (index == days.length - 1) {
          final point = Offset(pointX, pointY);
          canvas.drawCircle(
            point,
            30,
            Paint()
              ..shader = const RadialGradient(
                colors: [
                  MomCozyColors.milkChartGlow,
                  MomCozyColors.milkChartGlowFade,
                ],
              ).createShader(Rect.fromCircle(center: point, radius: 30)),
          );
          canvas.drawCircle(
            point,
            7,
            Paint()
              ..color = MomCozyColors.milkChartPoint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          for (double top = pointY + 10; top < 150; top += 7) {
            canvas.drawLine(
              Offset(pointX, top),
              Offset(pointX, math.min(top + 3, 150)),
              Paint()..color = MomCozyColors.milkChartGuide,
            );
          }
          _label(
            canvas,
            '今日 ${_number(value)} ml',
            pointX,
            pointY - 24,
            MomCozyColors.milkChartLabel,
            alignEnd: true,
          );
        }
        canvas.drawCircle(
          Offset(pointX, pointY),
          index == days.length - 1 ? 3.8 : 2.8,
          Paint()..color = MomCozyColors.milkChartInk,
        );
      }
      if (days.length == 7 ||
          index == 0 ||
          index == days.length - 1 ||
          index % 7 == 0) {
        _label(
          canvas,
          index == days.length - 1
              ? '今日'
              : '${days[index].month}/${days[index].day}',
          pointX,
          166,
          MomCozyColors.milkChartMuted,
        );
      }
    }
    canvas.restore();
  }

  void _label(
    Canvas canvas,
    String value,
    double x,
    double y,
    Color color, {
    bool alignEnd = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: MomCozyTypography.microSize,
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: const ['NotoSansSC'],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(x - (alignEnd ? painter.width : painter.width / 2), y),
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.values != values;
}
