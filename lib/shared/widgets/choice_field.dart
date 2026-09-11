import 'package:flutter/material.dart';
import '../design_system/momcozy_design_system.dart';

/// Wraps instead of truncating choices on small screens or at large text scales.
class ChoiceField<T extends Enum> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiple = false,
    this.exclusiveValue,
  });
  final String title;
  final Map<T, String> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiple;
  final T? exclusiveValue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: MomCozySpacing.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MomCozySpacing.content),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: MomCozyTypography.titleSize,
              fontWeight: FontWeight.w600,
              color: MomCozyColors.foreground,
            ),
          ),
        ),
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
                onSelected: (value) {
                  final next = multiple ? {...selected} : <T>{};
                  if (value) {
                    if (entry.key == exclusiveValue) {
                      next.clear();
                    } else {
                      next.remove(exclusiveValue);
                    }
                    next.add(entry.key);
                  } else {
                    next.remove(entry.key);
                  }
                  onChanged(Set.unmodifiable(next));
                },
              ),
          ],
        ),
      ],
    ),
  );
}
