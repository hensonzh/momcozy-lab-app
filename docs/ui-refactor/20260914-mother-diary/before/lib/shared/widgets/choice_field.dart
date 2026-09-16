import 'package:flutter/material.dart';
import '../design_system/momcozy_design_system.dart';

enum ChoiceFieldStyle { chips, warmTiles, warmSegmented }

/// Wraps instead of truncating choices on small screens or at large text scales.
class ChoiceField<T extends Enum> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.style = ChoiceFieldStyle.chips,
    this.columns = 3,
    this.hint,
    this.multiple = false,
    this.exclusiveValue,
    this.optionIcon,
  });
  final ChoiceFieldStyle style;
  final int columns;
  final String title;
  final String? hint;
  final Map<T, String> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiple;
  final T? exclusiveValue;
  final Widget Function(T value)? optionIcon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: style == ChoiceFieldStyle.chips ? 24 : 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: MomCozySpacing.content),
            child: _heading(),
          ),
        if (style != ChoiceFieldStyle.chips)
          _warmChoices(context)
        else
          Wrap(
            spacing: MomCozySpacing.compact,
            runSpacing: MomCozySpacing.compact,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selected.contains(entry.key),
                  showCheckmark: true,
                  selectedColor: MomCozyColors.roseSoft,
                  backgroundColor: MomCozyColors.raised,
                  labelStyle: TextStyle(
                    fontSize: MomCozyTypography.bodySize,
                    color: selected.contains(entry.key)
                        ? MomCozyColors.foreground
                        : MomCozyColors.mutedForeground,
                  ),
                  side: BorderSide(
                    color: selected.contains(entry.key)
                        ? MomCozyColors.primaryDark
                        : MomCozyColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  onSelected: (value) => _select(entry.key, value),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _heading() {
    final label = Text(
      title,
      style: TextStyle(
        fontSize: style == ChoiceFieldStyle.chips
            ? MomCozyTypography.titleSize
            : 14,
        height: style == ChoiceFieldStyle.chips ? null : 1.6,
        fontWeight: FontWeight.w600,
        color: style == ChoiceFieldStyle.chips
            ? MomCozyColors.foreground
            : MomCozyColors.diaryInk,
      ),
    );
    if (hint == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        Text(
          hint!,
          style: const TextStyle(
            fontSize: 11,
            height: 1.8,
            color: MomCozyColors.diaryMuted,
          ),
        ),
      ],
    );
  }

  void _select(T key, bool value) {
    final next = multiple ? {...selected} : <T>{};
    if (value) {
      if (key == exclusiveValue) {
        next.clear();
      } else {
        next.remove(exclusiveValue);
      }
      next.add(key);
    } else {
      next.remove(key);
    }
    onChanged(Set.unmodifiable(next));
  }

  Widget _warmChoices(BuildContext context) {
    final segmented = style == ChoiceFieldStyle.warmSegmented;
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 17;
    return Container(
      width: double.infinity,
      padding: segmented ? const EdgeInsets.all(4) : EdgeInsets.zero,
      decoration: segmented
          ? BoxDecoration(
              color: MomCozyColors.warmFormTab,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = largeText
              ? (constraints.maxWidth < 280 ? 1 : 2)
              : columns;
          final gap = segmented ? 4.0 : 8.0;
          final width = (constraints.maxWidth - gap * (count - 1)) / count;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final entry in options.entries)
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: selected.contains(entry.key),
                    child: OutlinedButton(
                      onPressed: () =>
                          _select(entry.key, !selected.contains(entry.key)),
                      style: OutlinedButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size(0, optionIcon == null ? 44 : 64),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 9,
                        ),
                        backgroundColor: selected.contains(entry.key)
                            ? segmented
                                  ? MomCozyColors.warmFormSelected
                                  : MomCozyColors.diarySelection
                            : segmented
                            ? Colors.transparent
                            : MomCozyColors.warmFormField,
                        foregroundColor:
                            selected.contains(entry.key) && segmented
                            ? MomCozyColors.diaryBright
                            : MomCozyColors.diaryMuted,
                        side: BorderSide(
                          color: segmented
                              ? Colors.transparent
                              : selected.contains(entry.key)
                              ? MomCozyColors.diarySelectionBorder
                              : MomCozyColors.warmFormBorder,
                          width: selected.contains(entry.key) && !segmented
                              ? 2
                              : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            segmented ? 8 : 12,
                          ),
                        ),
                        textStyle: TextStyle(
                          fontFamily: MomCozyTypography.fontFamily,
                          fontFamilyFallback:
                              MomCozyTypography.fontFamilyFallback,
                          fontSize: MediaQuery.sizeOf(context).width < 359
                              ? 11
                              : 12,
                          height: 1.5,
                          fontWeight: selected.contains(entry.key)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      child: optionIcon == null
                          ? Text(entry.value, textAlign: TextAlign.center)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                optionIcon!(entry.key),
                                const SizedBox(height: 5),
                                Text(entry.value, textAlign: TextAlign.center),
                              ],
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
