import 'package:flutter/material.dart';
import 'baby_motion.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/design_system/mom_home_tokens.dart';
import '../../../shared/design_system/mom_settings_theme.dart';

abstract final class BabyDesign {
  static Widget asset(String name, {double? width, double? height}) =>
      SvgPicture.asset(
        'assets/images/baby_figma/$name.svg',
        width: width,
        height: height,
      );
  static const selected = Color(0xfff7eff7);
  static const selectedInk = Color(0xff865c80);
  static const selectedBorder = Color(0xffcbb0c7);
  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = MomHomeTokens.ink,
    double? line,
  }) =>
      MomHomeTokens.text(
        size,
        weight: weight,
        color: color,
        height:
            (line ??
                (size == 20
                    ? 28
                    : size == 16
                    ? 24
                    : size == 15
                    ? 22
                    : 20)) /
            size,
      ).copyWith(
        fontFamily: 'BabyNotoSans',
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
      );
  static ThemeData theme(
    ThemeData base, {
    bool reduceMotion = false,
  }) => momSettingsTheme(base).copyWith(
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: momSettingsTheme(base).outlinedButtonTheme.style?.copyWith(
        animationDuration: reduceMotion ? Duration.zero : BabyMotion.feedback,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: momSettingsTheme(base).textButtonTheme.style?.copyWith(
        animationDuration: reduceMotion ? Duration.zero : BabyMotion.feedback,
      ),
    ),
    textTheme: momSettingsTheme(
      base,
    ).textTheme.apply(fontFamily: 'BabyNotoSans'),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        animationDuration: reduceMotion ? Duration.zero : BabyMotion.feedback,
        backgroundColor: MomHomeTokens.rose,
        foregroundColor: MomHomeTokens.surface,
        disabledBackgroundColor: const Color(0xffe5e0db),
        disabledForegroundColor: const Color(0xff99918c),
        minimumSize: const Size.fromHeight(52),
        textStyle: text(16, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: momSettingsTheme(base).inputDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.all(14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MomHomeTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MomHomeTokens.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MomHomeTokens.border),
      ),
      hintStyle: text(16, color: MomHomeTokens.muted),
      suffixStyle: text(14, color: MomHomeTokens.secondary),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: selectedBorder),
      ),
    ),
  );
}

class BabyLabel extends StatelessWidget {
  const BabyLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Semantics(
    label: required ? '$text，必填' : text,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: BabyDesign.text(15, weight: FontWeight.w600),
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          BabyDesign.asset('Asterisk', width: 8, height: 8),
        ],
      ],
    ),
  );
}

class BabyChoices<T> extends StatelessWidget {
  const BabyChoices({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.columns = 2,
    this.icon,
    this.enabled = true,
    this.height = 48,
    this.radius = 14,
  });
  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final int columns;
  final Widget Function(T)? icon;
  final bool enabled;
  final double height, radius;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scaled = MediaQuery.textScalerOf(context).scale(15);
      final count = scaled > 21
          ? (box.maxWidth < 300 ? 1 : 2)
          : (box.maxWidth < 270 && columns == 4 ? 2 : columns);
      return Column(
        spacing: 14,
        children: [
          for (var start = 0; start < options.length; start += count)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final e in options.entries.skip(start).take(count))
                    Expanded(
                      child: Semantics(
                        selected: selected == e.key,
                        child: BabyPressFeedback(
                          child: OutlinedButton(
                            onPressed: enabled ? () => onChanged(e.key) : null,
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(0, icon == null ? height : 82),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.standard,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              backgroundColor: selected == e.key
                                  ? BabyDesign.selected
                                  : MomHomeTokens.surface,
                              foregroundColor: selected == e.key
                                  ? BabyDesign.selectedInk
                                  : MomHomeTokens.secondary,
                              disabledForegroundColor: selected == e.key
                                  ? BabyDesign.selectedInk
                                  : MomHomeTokens.secondary,
                              side: BorderSide(
                                color: selected == e.key
                                    ? BabyDesign.selectedBorder
                                    : MomHomeTokens.border,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(radius),
                              ),
                              textStyle: BabyDesign.text(
                                15,
                                weight: selected == e.key
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            child: icon == null
                                ? Text(e.value, textAlign: TextAlign.center)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      icon!(e.key),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height:
                                            44 *
                                            MediaQuery.textScalerOf(
                                              context,
                                            ).scale(1),
                                        child: Center(
                                          child: Text(
                                            e.value,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  for (
                    var i = options.entries.skip(start).take(count).length;
                    i < count;
                    i++
                  )
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      );
    },
  );
}

Future<T?> showBabySheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      sheetAnimationStyle: BabyMotion.sheet(context),
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      barrierColor: const Color(0x472b2629),
      backgroundColor: MomHomeTokens.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => Theme(
        data: BabyDesign.theme(
          Theme.of(context),
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: MediaQuery.viewInsetsOf(context).bottom),
          duration: BabyMotion.duration(context, BabyMotion.content),
          curve: Curves.easeOutCubic,
          child: child,
          builder: (context, inset, child) => Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      (MediaQuery.sizeOf(context).height -
                              MediaQuery.paddingOf(context).top -
                              inset -
                              24)
                          .clamp(0, double.infinity),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

enum BabySheetStyle { form, switcher, knowledge }

class BabySheetBody extends StatelessWidget {
  const BabySheetBody({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.onClose,
    this.style = BabySheetStyle.form,
    this.bodyTop = 16,
  });
  final String title;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onClose;
  final BabySheetStyle style;
  final double bodyTop;
  @override
  Widget build(BuildContext context) {
    final form = style == BabySheetStyle.form;
    final knowledge = style == BabySheetStyle.knowledge;
    final surface = knowledge
        ? MomHomeTokens.background
        : MomHomeTokens.surface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffcec5cc),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13.5),
          child: ColoredBox(
            color: surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                knowledge
                    ? 4
                    : form
                    ? 0
                    : 16,
                16,
                knowledge
                    ? 16
                    : form
                    ? 0
                    : 14,
              ),
              child: Row(
                crossAxisAlignment: knowledge
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: BabyDesign.text(
                        20,
                        line: knowledge ? 29 : 28,
                        weight: form ? FontWeight.w600 : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  BabyPressFeedback(
                    child: SizedBox(
                      width: 44,
                      height: style == BabySheetStyle.switcher ? 34 : 44,
                      child: IconButton(
                        tooltip: '关闭',
                        padding: EdgeInsets.zero,
                        onPressed: onClose ?? () => Navigator.pop(context),
                        icon: knowledge
                            ? BabyDesign.asset('Close', width: 20, height: 20)
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: BabyDesign.asset(
                                    form ? 'FormClose' : 'SwitcherClose',
                                    width: form ? 13 : 16,
                                    height: form ? 13 : 16,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.5),
            child: ColoredBox(
              color: style == BabySheetStyle.switcher
                  ? surface
                  : MomHomeTokens.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, form ? bodyTop : 0, 16, 16),
                child: body,
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13.5),
            child: ColoredBox(
              color: surface,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, knowledge ? 0 : 16, 16, 16),
                child: SizedBox(width: double.infinity, child: footer),
              ),
            ),
          ),
      ],
    );
  }
}
