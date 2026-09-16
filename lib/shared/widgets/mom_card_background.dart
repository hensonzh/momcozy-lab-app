import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum MomCardDecoration {
  ai,
  sleep,
  wet,
  stool,
  feeding,
  measurement,
  chart,
  calendar,
  appointment,
  task,
  personal,
  account,
  plan,
  utility,
  resource,
  monitor,
}

/// Me's original vectors, with placement and opacity from the Figma card family.
/// This layer never contributes to layout, hit testing or spoken content.
class MomCardBackground extends StatelessWidget {
  const MomCardBackground({
    super.key,
    required this.decoration,
    required this.child,
  });
  final MomCardDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final height = switch (decoration) {
                  MomCardDecoration.chart => 76.0,
                  MomCardDecoration.calendar => 78.0,
                  MomCardDecoration.resource => h < 70 ? h : 70.0,
                  _ => h,
                };
                Widget element(
                  String name,
                  double x,
                  double y,
                  double width,
                  double opacity, {
                  Color? color,
                }) => Positioned(
                  left: x,
                  top: y,
                  width: width,
                  child: Opacity(
                    opacity: opacity,
                    child: SvgPicture.asset(
                      'assets/images/mom_home/card_decoration_$name.svg',
                      width: width,
                      colorFilter: color == null
                          ? null
                          : ColorFilter.mode(color, BlendMode.srcIn),
                    ),
                  ),
                );
                final elements = switch (decoration) {
                  MomCardDecoration.ai => [
                    element('lilac', w - 106, -30, 140, .24),
                    element('blush', -38, h - 49, 150, .30),
                    element('spark', w - 49, 78, 18, .48),
                  ],
                  MomCardDecoration.sleep => [
                    element('warm', w - 64, h - 58, 90, .70),
                    element('moon', w - 34, 17, 38, .72),
                  ],
                  MomCardDecoration.wet => [
                    element('warm', w - 55, h - 51, 82, .56),
                    element('drop', w - 38, 17, 34, .64),
                  ],
                  MomCardDecoration.stool => [
                    element('blush', w - 74, h - 49, 108, .32),
                    element('wave', w - 129, h - 46, 160, .55),
                  ],
                  MomCardDecoration.feeding => [
                    element('blush', w - 83, -24, 125, .30),
                    element('drop', w - 113, 5, 38, .62),
                    element('wave', w - 213, h - 44, 210, .40),
                  ],
                  MomCardDecoration.measurement => [
                    element('warm', w - 40, h - 48, 76, .28),
                    element(
                      'ring',
                      w - 46,
                      h - 50,
                      64,
                      .34,
                      color: const Color(0xffe5d5c1),
                    ),
                  ],
                  MomCardDecoration.chart || MomCardDecoration.calendar => [
                    element('mint', w - 69, -47, 118, .25),
                    element(
                      'ring',
                      w - 56,
                      -25,
                      80,
                      .36,
                      color: const Color(0xffc9ded5),
                    ),
                  ],
                  MomCardDecoration.appointment => [
                    element('mint', w - 70, -23, 116, .28),
                    element(
                      'leaves',
                      w - 77,
                      h - 81,
                      65,
                      .30,
                      color: const Color(0xffb9d4c7),
                    ),
                  ],
                  MomCardDecoration.task => [
                    element('mint', w - 72, -23, 116, .38),
                    element(
                      'ring',
                      w - 80,
                      h - 73,
                      96,
                      .55,
                      color: Colors.white,
                    ),
                  ],
                  MomCardDecoration.personal || MomCardDecoration.account => [
                    element('blush', w - 94, -21, 138, .34),
                    element('wave', w - 198, h - 55, 218, .60),
                  ],
                  MomCardDecoration.plan => [
                    element('warm', w - 68, h - 60, 100, .52),
                    element('ring', w - 57, h - 67, 94, .56),
                  ],
                  MomCardDecoration.utility => [
                    element('mint', w - 72, -29, 112, .22),
                    element(
                      'wave',
                      w - 175,
                      h - 59,
                      200,
                      .24,
                      color: const Color(0xffbbd2c8),
                    ),
                  ],
                  MomCardDecoration.resource => [
                    element('mint', w - 60, -30, 104, .22),
                    element(
                      'leaves',
                      w - 70,
                      5,
                      50,
                      .20,
                      color: const Color(0xffb9d4c7),
                    ),
                  ],
                  MomCardDecoration.monitor => [
                    element(
                      'wave',
                      w - 168,
                      h - 52,
                      194,
                      .25,
                      color: const Color(0xffbbd2c8),
                    ),
                  ],
                };
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: w,
                    height: height,
                    child: ClipRect(child: Stack(children: elements)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      child,
    ],
  );
}
