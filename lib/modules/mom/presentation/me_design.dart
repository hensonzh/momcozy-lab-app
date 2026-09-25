import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../baby/presentation/baby_design.dart';
import '../domain/me_experience.dart';

abstract final class MeDesign {
  static const ink = Color(0xff2b2826),
      muted = Color(0xff80716e),
      rose = Color(0xffb44e78),
      surface = Color(0xfffffcfa),
      border = Color(0xffe8dde3);
  static const profileBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xfff4f0fb), Color(0xfffbf8f4), Color(0xfffbf8f4)],
    stops: [0, .45, 1],
  );
  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xfff4f0fb),
      Color(0xfffbf5f6),
      Color(0xfffbf8f4),
      Color(0xfffbf8f4),
    ],
    stops: [0, .32, .51, 1],
  );
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double? line,
  }) => BabyDesign.text(
    size,
    weight: weight,
    color: color,
    line: line ?? size * 1.4,
  );
  static Widget asset(String name, {double? width, double? height}) =>
      name.endsWith('.svg')
      ? SvgPicture.asset(
          'assets/images/me_figma/$name',
          width: width,
          height: height,
        )
      : Image.asset(
          'assets/images/me_figma/$name',
          width: width,
          height: height,
          fit: BoxFit.contain,
        );
  static Widget art(MeMetric kind, double size) =>
      asset('Illustration${kind.artwork}.png', width: size, height: size);
  static BoxDecoration card({double radius = 22, Color color = surface}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );
  static LinearGradient metricGradient(MeMetric kind) => LinearGradient(
    colors: switch (kind) {
      MeMetric.energy => [const Color(0xfffffdf6), const Color(0xfff6edd9)],
      MeMetric.sleep => [const Color(0xfffcfafe), const Color(0xffeae4f7)],
      MeMetric.mood ||
      MeMetric.pain => [const Color(0xfffff9f5), const Color(0xfff8e6df)],
      _ => [const Color(0xfffff9f6), const Color(0xfff6e3e7)],
    },
  );
}

class MeButton extends StatelessWidget {
  const MeButton(
    this.label, {
    super.key,
    this.onPressed,
    this.busy = false,
    this.fontSize = 14,
    this.weight = FontWeight.w700,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double fontSize;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: MeDesign.rose,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xffe4dee1),
      disabledForegroundColor: const Color(0xff958a90),
      minimumSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
      textStyle: MeDesign.text(fontSize, weight: weight),
    ),
    child: busy
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label),
  );
}

class MePage extends StatelessWidget {
  const MePage({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.trailing,
    this.onBack,
    this.scroll = true,
    this.background = MeDesign.background,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 24, 20, 24),
  });
  final String title;
  final Widget body;
  final Widget? footer, trailing;
  final VoidCallback? onBack;
  final bool scroll;
  final Gradient background;
  final EdgeInsets bodyPadding;
  @override
  Widget build(BuildContext context) => Theme(
    data: BabyDesign.theme(Theme.of(context)),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: background),
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 24),
          bottom: false,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final style = MeDesign.text(
                    18,
                    weight: FontWeight.w500,
                    line: 26,
                  );
                  final text = TextPainter(
                    text: TextSpan(text: title, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: box.maxWidth - 136);
                  final height = text.height + 16 > 56
                      ? text.height + 16
                      : 56.0;
                  text.dispose();
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 68),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: style,
                          ),
                        ),
                        Positioned(
                          left: 8,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: onBack ?? () => Navigator.pop(context),
                            icon: MeDesign.asset(
                              'IconChevronLeft.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          Positioned(right: 20, child: trailing!),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: scroll
                    ? SingleChildScrollView(padding: bodyPadding, child: body)
                    : body,
              ),
              if (footer != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    MediaQuery.paddingOf(context).bottom > 28
                        ? MediaQuery.paddingOf(context).bottom
                        : 28,
                  ),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MeChoice extends StatelessWidget {
  const MeChoice(
    this.label, {
    super.key,
    required this.selected,
    required this.onTap,
    this.height = 56,
    this.fontSize = 15,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final double height, fontSize;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? BabyDesign.selected : MeDesign.surface,
        foregroundColor: selected ? BabyDesign.selectedInk : MeDesign.ink,
        side: BorderSide(color: selected ? MeDesign.rose : MeDesign.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: Size.fromHeight(height),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: MeDesign.text(
          fontSize,
          weight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: Text(label)),
    ),
  );
}

class MeMetricRow extends StatelessWidget {
  const MeMetricRow(this.kind, {super.key, this.onTap});
  final MeMetric kind;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 64,
        decoration: BoxDecoration(
          gradient: MeDesign.metricGradient(kind),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .65)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                left: -12,
                top: -24,
                child: MeDesign.asset(
                  'DecorationAmbientRing.svg',
                  width: 114,
                  height: 114,
                ),
              ),
              Positioned(
                right: -16,
                top: 36,
                child: MeDesign.asset(
                  'DecorationAmbientPetal.svg',
                  width: 132,
                  height: 62,
                ),
              ),
              Positioned(
                left: 14,
                top: 8,
                child: Opacity(opacity: .84, child: MeDesign.art(kind, 48)),
              ),
              Positioned(
                left: 78,
                right: 18,
                top: 23,
                child: Text(
                  kind.label,
                  style: MeDesign.text(14, weight: FontWeight.w500, line: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MeError extends StatelessWidget {
  const MeError({super.key, this.message = 'Could not save. Please try again.'});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfff5ebf0),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      message,
      style: MeDesign.text(14, color: MeDesign.rose, weight: FontWeight.w700),
    ),
  );
}

Future<bool> meDiscard(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Discard your changes?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Keep editing'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Discard changes'),
      ),
    ],
  ),
).then((v) => v ?? false);
