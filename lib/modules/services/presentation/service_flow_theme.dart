import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

class ServiceFlowTheme extends StatelessWidget {
  const ServiceFlowTheme({super.key, required this.child});
  final Widget child;

  static ButtonStyle cancellationStyle(
    BuildContext context, {
    bool tinted = false,
  }) => OutlinedButton.styleFrom(
    foregroundColor: MomCozyColors.primaryDark,
    backgroundColor: tinted ? MomCozyColors.roseSoft : MomCozyColors.card,
    minimumSize: const Size(double.infinity, 48),
    side: BorderSide(color: MomCozyColors.primary.withValues(alpha: .4)),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: MomCozyColors.border),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          isDense: true,
          filled: true,
          fillColor: MomCozyColors.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 14,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: MomCozyColors.primary),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: MomCozyColors.foreground,
            foregroundColor: MomCozyColors.card,
            minimumSize: const Size(double.infinity, 48),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
          ),
        ),
      ),
      child: child,
    );
  }
}
