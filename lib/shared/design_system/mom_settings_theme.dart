import 'package:flutter/material.dart';

import 'mom_home_tokens.dart';
import 'momcozy_design_system.dart';

/// Scoped styling for settings pages adopted into the mother-page design.
/// This does not change the theme of pages awaiting their own Figma redesign.
ThemeData momSettingsTheme(ThemeData base) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final text = MomHomeTokens.text(13, weight: FontWeight.w700);
  return base.copyWith(
    scaffoldBackgroundColor: MomHomeTokens.background,
    colorScheme: base.colorScheme.copyWith(
      primary: MomHomeTokens.rose,
      onPrimary: MomHomeTokens.surface,
      surface: MomHomeTokens.surface,
      onSurface: MomHomeTokens.ink,
      error: MomCozyColors.danger,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSansSCHome',
      bodyColor: MomHomeTokens.ink,
      displayColor: MomHomeTokens.ink,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: MomHomeTokens.background,
      foregroundColor: MomHomeTokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: MomHomeTokens.text(22, weight: FontWeight.w700),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: MomHomeTokens.rose,
        disabledForegroundColor: MomHomeTokens.secondary.withValues(alpha: .4),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(12),
        shape: shape,
        textStyle: text,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MomHomeTokens.rose,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(12),
        side: const BorderSide(color: MomHomeTokens.border),
        shape: shape,
        textStyle: text,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MomHomeTokens.rose,
        foregroundColor: MomHomeTokens.surface,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.all(12),
        shape: shape,
        textStyle: text,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: MomHomeTokens.surface,
      labelStyle: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
      floatingLabelStyle: MomHomeTokens.text(12, color: MomHomeTokens.rose),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MomHomeTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MomHomeTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MomHomeTokens.rose),
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: MomHomeTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: MomHomeTokens.text(20, weight: FontWeight.w700),
      contentTextStyle: MomHomeTokens.text(
        13,
        color: MomHomeTokens.secondary,
        height: 1.55,
      ),
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      color: MomHomeTokens.rose,
      linearTrackColor: MomHomeTokens.mint,
    ),
    switchTheme: base.switchTheme.copyWith(
      trackColor: WidgetStateProperty.resolveWith((states) {
        final color = states.contains(WidgetState.selected)
            ? MomHomeTokens.rose
            : MomHomeTokens.neutralSurface;
        return states.contains(WidgetState.disabled)
            ? color.withValues(alpha: .4)
            : color;
      }),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? MomHomeTokens.surface
            : MomHomeTokens.secondary,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
