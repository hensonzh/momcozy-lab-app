import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/widgets/mom_settings_widgets.dart';
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
    final periods = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final period in [7, 30]) ...[
          if (period == 30) const SizedBox(width: 8),
          Semantics(
            selected: _days == period,
            child: OutlinedButton(
              onPressed: () => setState(() => _days = period),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 12,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: MomHomeTokens.text(12, weight: FontWeight.w700),
                foregroundColor: _days == period
                    ? MomHomeTokens.teal
                    : MomHomeTokens.secondary,
                backgroundColor: _days == period
                    ? MomHomeTokens.mint
                    : MomHomeTokens.surface,
                side: BorderSide(
                  color: _days == period
                      ? MomHomeTokens.teal
                      : MomHomeTokens.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('$period days'),
            ),
          ),
        ],
      ],
    );
    final title = Text(
      'Milk supply trends',
      style: MomHomeTokens.text(16, weight: FontWeight.w700),
    );
    return MomSettingsCard(
      children: [
        if (MediaQuery.textScalerOf(context).scale(1) > 1.4) ...[
          title,
          periods,
        ] else
          Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              periods,
            ],
          ),
        Text(
          '${values.last == null ? '—' : _number(values.last!)} ml',
          style: MomHomeTokens.text(36, weight: FontWeight.w700),
        ),
        Text(
          'Pumped milk today',
          style: MomHomeTokens.text(13, color: MomHomeTokens.secondary),
        ),
        Semantics(
          label:
              'Pumped milk over $_days days. ${List.generate(days.length, (index) => '${days[index].month}/${days[index].day}: ${values[index] == null ? 'Not recorded' : '${_number(values[index]!)} ml'}').join('; ')}',
          child: ExcludeSemantics(
            child: AspectRatio(
              aspectRatio: 320 / 192,
              child: CustomPaint(painter: _TrendPainter(days, values)),
            ),
          ),
        ),
        Text(
          measured == 0
              ? 'No pumping records yet. Add one to see trends.'
              : measured == 1
              ? 'Only one day recorded so far. Keep tracking to see a trend.'
              : 'Only recorded pumping amounts are shown. Unrecorded days are left blank.',
          style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
        ),
      ],
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
      ..color = MomHomeTokens.border
      ..strokeWidth = 1;
    for (double left = 20; left < 300; left += 7) {
      canvas.drawLine(Offset(left, 150), Offset(left + 3, 150), baseline);
    }
    final line = Paint()
      ..color = MomHomeTokens.teal
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
                colors: [MomHomeTokens.mint, MomHomeTokens.surface],
              ).createShader(Rect.fromCircle(center: point, radius: 30)),
          );
          canvas.drawCircle(
            point,
            7,
            Paint()
              ..color = MomHomeTokens.teal
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          for (double top = pointY + 10; top < 150; top += 7) {
            canvas.drawLine(
              Offset(pointX, top),
              Offset(pointX, math.min(top + 3, 150)),
              Paint()..color = MomHomeTokens.border,
            );
          }
          _label(
            canvas,
            'Today: ${_number(value)} ml',
            pointX,
            pointY - 24,
            MomHomeTokens.secondary,
            alignEnd: true,
          );
        }
        canvas.drawCircle(
          Offset(pointX, pointY),
          index == days.length - 1 ? 3.8 : 2.8,
          Paint()..color = MomHomeTokens.teal,
        );
      }
      if (days.length == 7 ||
          index == 0 ||
          index == days.length - 1 ||
          index % 7 == 0) {
        _label(
          canvas,
          index == days.length - 1
              ? 'Today'
              : '${days[index].month}/${days[index].day}',
          pointX,
          166,
          MomHomeTokens.secondary,
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
          fontSize: 10,
          fontFamily: 'NotoSansSCHome',
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
