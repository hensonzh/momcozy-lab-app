import 'package:flutter/material.dart';
import 'momcozy_design_system.dart';
import 'momcozy_text_roles.dart';

ThemeData momCozyTheme() {
  final colorScheme = const ColorScheme.light(
    primary: MomCozyColors.primary,
    onPrimary: MomCozyColors.background,
    primaryContainer: MomCozyColors.roseSoft,
    onPrimaryContainer: MomCozyColors.foreground,
    secondary: MomCozyColors.secondary,
    onSecondary: MomCozyColors.foreground,
    secondaryContainer: MomCozyColors.secondary,
    onSecondaryContainer: MomCozyColors.foreground,
    tertiary: MomCozyColors.warm,
    onTertiary: MomCozyColors.foreground,
    surface: MomCozyColors.background,
    onSurface: MomCozyColors.foreground,
    surfaceContainerLowest: MomCozyColors.background,
    surfaceContainerLow: MomCozyColors.card,
    surfaceContainer: MomCozyColors.muted,
    surfaceContainerHigh: MomCozyColors.secondary,
    surfaceContainerHighest: MomCozyColors.roseSoft,
    onSurfaceVariant: MomCozyColors.mutedForeground,
    outline: MomCozyColors.border,
    outlineVariant: MomCozyColors.border,
    error: MomCozyColors.danger,
    errorContainer: MomCozyColors.errorSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: MomCozyColors.background,
    fontFamily: MomCozyTypography.fontFamily,
    fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
    textTheme: _textTheme(),
    extensions: [const MomCozyTextRoles()],
    dividerTheme: const DividerThemeData(
      color: MomCozyColors.border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(
      color: MomCozyColors.iconPrimary,
      size: MomCozyIconSizes.standard,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: MomCozyColors.background,
      foregroundColor: MomCozyColors.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: MomCozyLayout.headerHeight,
      titleTextStyle: TextStyle(
        fontFamily: MomCozyTypography.displayFontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        fontSize: 21,
        height: 1.2,
        letterSpacing: -.525,
        fontWeight: FontWeight.w700,
        color: MomCozyColors.foreground,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: MomCozyColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.dialog),
      ),
      insetPadding: const EdgeInsets.all(MomCozySpacing.content),
      titleTextStyle: TextStyle(
        fontFamily: MomCozyTypography.displayFontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        fontSize: 21,
        height: 1.2,
        letterSpacing: -.525,
        fontWeight: FontWeight.w700,
        color: MomCozyColors.foreground,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: MomCozyColors.background,
      modalBackgroundColor: MomCozyColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MomCozyRadii.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: MomCozyColors.foreground,
      contentTextStyle: const TextStyle(
        fontFamily: MomCozyTypography.fontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        fontSize: MomCozyTypography.bodySize,
        color: MomCozyColors.raised,
      ),
      actionTextColor: MomCozyColors.roseSoft,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: MomCozyColors.iconPrimary,
      textColor: MomCozyColors.foreground,
      contentPadding: EdgeInsets.symmetric(horizontal: MomCozySpacing.page),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: MomCozyColors.raised,
      selectedColor: MomCozyColors.roseSoft,
      disabledColor: MomCozyColors.disabled,
      side: MomCozyBorders.subtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.badge),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: MomCozyColors.primaryDark,
      unselectedLabelColor: MomCozyColors.mutedForeground,
      dividerColor: MomCozyColors.border,
      indicatorColor: MomCozyColors.primary,
    ),
    cardTheme: CardThemeData(
      color: MomCozyColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.card),
        side: const BorderSide(color: MomCozyColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, MomCozyLayout.buttonHeight),
        backgroundColor: MomCozyColors.foreground,
        foregroundColor: MomCozyColors.raised,
        disabledBackgroundColor: MomCozyColors.secondary,
        disabledForegroundColor: MomCozyColors.mutedForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, MomCozyLayout.buttonHeight),
        foregroundColor: MomCozyColors.primary,
        side: const BorderSide(color: MomCozyColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, MomCozyTapTargets.minimum),
        foregroundColor: MomCozyColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        textStyle: const TextStyle(
          fontFamily: MomCozyTypography.fontFamily,
          fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(MomCozyTapTargets.minimum),
        foregroundColor: MomCozyColors.mutedForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.raised;
        }
        return MomCozyColors.mutedForeground.withValues(alpha: 0.82);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.primary;
        }
        return MomCozyColors.border.withValues(alpha: 0.72);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return MomCozyColors.care;
        }
        return MomCozyColors.raised;
      }),
      checkColor: WidgetStateProperty.all(MomCozyColors.raised),
      side: const BorderSide(color: MomCozyColors.care, width: 1.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: MomCozyColors.primary,
      inactiveTrackColor: MomCozyColors.border.withValues(alpha: 0.7),
      overlayColor: MomCozyColors.primary.withValues(alpha: 0.12),
      thumbColor: MomCozyColors.primary,
      valueIndicatorColor: MomCozyColors.primary,
      valueIndicatorTextStyle: const TextStyle(
        color: MomCozyColors.background,
        fontFamily: MomCozyTypography.fontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
        fontWeight: FontWeight.w800,
      ),
      trackHeight: 5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: MomCozyColors.primary,
      linearTrackColor: MomCozyColors.roseSoft,
      circularTrackColor: MomCozyColors.roseSoft,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MomCozyColors.roseSoft
              : MomCozyColors.card;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MomCozyColors.primary
              : MomCozyColors.mutedForeground;
        }),
        side: WidgetStateProperty.all(
          const BorderSide(color: MomCozyColors.border),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MomCozyRadii.control),
          ),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(
            fontFamily: MomCozyTypography.fontFamily,
            fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MomCozyColors.card,
      errorMaxLines: 3,
      helperMaxLines: 3,
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.secondary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(
          color: MomCozyColors.danger,
          width: MomCozyBorders.focusWidth,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(color: MomCozyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        borderSide: const BorderSide(
          color: MomCozyColors.primary,
          width: MomCozyBorders.focusWidth,
        ),
      ),
    ),
  );
}

TextTheme _textTheme() {
  final base = Typography.blackCupertino
      .merge(
        const TextTheme(
          headlineLarge: MomCozyTypography.pageTitle,
          headlineMedium: MomCozyTypography.pageTitle,
          headlineSmall: MomCozyTypography.heading,
          titleLarge: MomCozyTypography.sectionTitle,
          titleMedium: MomCozyTypography.title,
          titleSmall: TextStyle(
            fontSize: MomCozyTypography.bodySize,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontSize: MomCozyTypography.bodyLargeSize),
          bodyMedium: MomCozyTypography.body,
          bodySmall: TextStyle(fontSize: MomCozyTypography.captionSize),
          labelSmall: MomCozyTypography.label,
        ),
      )
      .apply(
        bodyColor: MomCozyColors.foreground,
        displayColor: MomCozyColors.foreground,
        fontFamily: MomCozyTypography.fontFamily,
        fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
      );
  // styles.css h1/h2/h3 and the approved 16-18px section-heading range.
  TextStyle heading(
    TextStyle style,
    double size,
    double height,
    double spacing,
  ) => style.copyWith(
    fontFamily: MomCozyTypography.displayFontFamily,
    fontWeight: FontWeight.w700,
    fontSize: size,
    height: height,
    letterSpacing: spacing,
  );
  return base.copyWith(
    headlineLarge: heading(base.headlineLarge!, 28, 1.1, -1.12),
    headlineMedium: heading(base.headlineMedium!, 28, 1.1, -1.12),
    headlineSmall: heading(base.headlineSmall!, 21, 1.2, -.525),
    titleLarge: heading(base.titleLarge!, 18, 1.2, -.45),
    // Material dropdowns also use titleMedium for input values. Keep these
    // control roles in the body family; feature headings have explicit styles.
  );
}
