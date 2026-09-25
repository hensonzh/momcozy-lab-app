import 'dart:math' as math;
import '../../../shared/widgets/momcozy_line_icon.dart';
import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

enum MotherCardKind { rest, body, mood, lactation }

class MotherStatusCard extends StatelessWidget {
  const MotherStatusCard({
    super.key,
    required this.kind,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
  });
  final MotherCardKind kind;
  final String label, value;
  final String? detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final gradient = switch (kind) {
      MotherCardKind.rest => MomCozyGradients.rest,
      MotherCardKind.body => MomCozyGradients.body,
      MotherCardKind.mood => MomCozyGradients.mood,
      MotherCardKind.lactation => MomCozyGradients.lactation,
    };
    final measured = RegExp(r'^(.*?)\s*(hr|ml|min|times)$').firstMatch(value);
    return Semantics(
      label: '$label, $value${detail == null ? '' : ', $detail'}',
      button: true,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(MomCozyRadii.featured),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(gradient: gradient),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _Decoration(kind)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: MomCozyTypography.secondarySize,
                                  color: MomCozyColors.statusSecondary,
                                ),
                              ),
                            ),
                            const MomCozyLineIcon(
                              MomCozyLineGlyph.chevronRight,
                              size: 16,
                              color: MomCozyColors.statusIcon,
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text.rich(
                          TextSpan(
                            children: measured == null
                                ? [TextSpan(text: value)]
                                : [
                                    TextSpan(text: measured[1]),
                                    TextSpan(
                                      text: ' ${measured[2]}',
                                      style: const TextStyle(
                                        fontSize:
                                            MomCozyTypography.secondarySize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                          ),
                          style: TextStyle(
                            fontSize: measured == null
                                ? MomCozyTypography.headingSize
                                : MomCozyTypography.metricSize,
                            fontWeight: measured == null
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: MomCozyColors.statusText,
                            height: 1.25,
                          ),
                        ),
                        if (detail != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              detail!,
                              style: const TextStyle(
                                fontSize: MomCozyTypography.microSize,
                                color: MomCozyColors.statusTertiary,
                                height: 1.5,
                              ),
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
      ),
    );
  }
}

class _Decoration extends CustomPainter {
  _Decoration(this.kind);
  final MotherCardKind kind;
  @override
  void paint(Canvas canvas, Size size) {
    final pale = Paint()..color = const Color(0xb8fffbed);
    switch (kind) {
      case MotherCardKind.rest:
        final outer = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(size.width - 44, 85), radius: 34),
          );
        final cut = Path()
          ..addOval(
            Rect.fromCircle(center: Offset(size.width - 29, 71), radius: 35),
          );
        canvas.drawPath(
          Path.combine(PathOperation.difference, outer, cut),
          pale,
        );
      case MotherCardKind.body:
        final rect = Rect.fromCircle(
          center: Offset(size.width - 25, size.height - 6),
          radius: 88,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0x80f3dfbe), Color(0x33fff9ef)],
            ).createShader(rect),
        );
      case MotherCardKind.mood:
        canvas.save();
        canvas.translate(size.width - 10, size.height - 28);
        canvas.rotate(-8 * math.pi / 180);
        for (var index = 0; index < 4; index++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: 145 + index * 16,
              height: 38 + index * 16,
            ),
            Paint()
              ..color = Color.fromRGBO(255, 249, 241, .38 - index * .08)
              ..style = PaintingStyle.stroke,
          );
        }
        canvas.restore();
      case MotherCardKind.lactation:
        final left = size.width - 76;
        final path = Path()
          ..moveTo(left + 36, 42)
          ..cubicTo(left + 66, 69, left + 78, 83, left + 56, 112)
          ..cubicTo(left + 34, 139, left - 6, 123, left + 1, 94)
          ..cubicTo(left + 4, 76, left + 17, 60, left + 36, 42);
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xa6fff9f1)
            ..strokeWidth = 1.3
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _Decoration oldDelegate) =>
      oldDelegate.kind != kind;
}
