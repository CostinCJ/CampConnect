import 'package:flutter/material.dart';

/// "Trail Adventure" design system (see DESIGN.md).
///
/// Light = daylight trail: sun-bleached canvas, forest green, sunset orange.
/// Dark = campfire night: deep green-black with warm accents.
/// Red is reserved for emergency features only.
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Nunito';

  static ThemeData light() => _buildTheme(_lightScheme, _lightCamp);

  static ThemeData dark() => _buildTheme(_darkScheme, _darkCamp);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2E5339),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD9E9D2),
    onPrimaryContainer: Color(0xFF1C3A25),
    secondary: Color(0xFF5B6E52),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDEE7D2),
    onSecondaryContainer: Color(0xFF19301F),
    tertiary: Color(0xFFC75B1E),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFBDFC9),
    onTertiaryContainer: Color(0xFF7A3410),
    error: Color(0xFFBA2D22),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDA),
    onErrorContainer: Color(0xFF5E120C),
    surface: Color(0xFFFAF3E5),
    onSurface: Color(0xFF26302A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFDF7),
    surfaceContainer: Color(0xFFF5EDDD),
    surfaceContainerHigh: Color(0xFFF2E9D8),
    surfaceContainerHighest: Color(0xFFEDE3CF),
    onSurfaceVariant: Color(0xFF57604F),
    outline: Color(0xFF6F7866),
    outlineVariant: Color(0xFFD8D2BE),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2B322C),
    onInverseSurface: Color(0xFFF0F1EA),
    inversePrimary: Color(0xFFA6D3AA),
    surfaceTint: Colors.transparent,
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA6D3AA),
    onPrimary: Color(0xFF12351D),
    primaryContainer: Color(0xFF2B4A33),
    onPrimaryContainer: Color(0xFFC6E5C8),
    secondary: Color(0xFFB9C4AC),
    onSecondary: Color(0xFF242E1E),
    secondaryContainer: Color(0xFF3A4534),
    onSecondaryContainer: Color(0xFFD5E0C8),
    tertiary: Color(0xFFF09B5F),
    onTertiary: Color(0xFF4A2408),
    tertiaryContainer: Color(0xFF6B3312),
    onTertiaryContainer: Color(0xFFFFDCC2),
    error: Color(0xFFF2887C),
    onError: Color(0xFF4A0E08),
    errorContainer: Color(0xFF7A2018),
    onErrorContainer: Color(0xFFFADAD5),
    surface: Color(0xFF161C17),
    onSurface: Color(0xFFE7EAE1),
    surfaceContainerLowest: Color(0xFF121712),
    surfaceContainerLow: Color(0xFF1B221B),
    surfaceContainer: Color(0xFF1F261F),
    surfaceContainerHigh: Color(0xFF283128),
    surfaceContainerHighest: Color(0xFF2F3A2F),
    onSurfaceVariant: Color(0xFFA9B2A4),
    outline: Color(0xFF8B937F),
    outlineVariant: Color(0xFF3C453B),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE7EAE1),
    onInverseSurface: Color(0xFF2B322C),
    inversePrimary: Color(0xFF2E5339),
    surfaceTint: Colors.transparent,
  );

  static const _lightCamp = CampColors(
    sunset: Color(0xFFE8712D),
    sunsetDeep: Color(0xFFC75B1E),
    sunsetSoft: Color(0xFFFBDFC9),
    onSunsetSoft: Color(0xFF7A3410),
  );

  static const _darkCamp = CampColors(
    sunset: Color(0xFFF09B5F),
    sunsetDeep: Color(0xFFF09B5F),
    sunsetSoft: Color(0xFF6B3312),
    onSunsetSoft: Color(0xFFFFDCC2),
  );

  static TextTheme _textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    TextStyle style(double size, FontWeight weight,
        {double? spacing, double? height, Color? color}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing ?? 0,
        height: height,
        color: color ?? ink,
      );
    }

    return TextTheme(
      displayLarge: style(56, FontWeight.w800, spacing: -1),
      displayMedium: style(44, FontWeight.w800, spacing: -0.5),
      displaySmall: style(36, FontWeight.w800, spacing: -0.5),
      headlineLarge: style(32, FontWeight.w800, spacing: -0.5, height: 1.15),
      headlineMedium: style(27, FontWeight.w800, spacing: -0.25, height: 1.2),
      headlineSmall: style(23, FontWeight.w800, height: 1.25),
      titleLarge: style(20, FontWeight.w700, height: 1.3),
      titleMedium: style(17, FontWeight.w700, height: 1.35),
      titleSmall: style(14, FontWeight.w700, height: 1.4),
      bodyLarge: style(16, FontWeight.w400, height: 1.5),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(12, FontWeight.w400, height: 1.4, color: muted),
      labelLarge: style(15, FontWeight.w700, spacing: 0.1),
      labelMedium: style(12, FontWeight.w600, spacing: 0.2),
      labelSmall: style(11, FontWeight.w600, spacing: 0.3, color: muted),
    );
  }

  static ThemeData _buildTheme(ColorScheme scheme, CampColors camp) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(scheme);
    final cardColor =
        isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      extensions: [camp],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outline, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: camp.sunsetDeep,
        foregroundColor: isDark ? scheme.onTertiary : Colors.white,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimaryContainer);
          }
          return IconThemeData(color: scheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelMedium!;
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            );
          }
          return base.copyWith(color: scheme.onSurfaceVariant);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        elevation: 4,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        elevation: 3,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          textStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Camp-specific colors that sit outside the Material [ColorScheme]:
/// the sunset accent family. Access via
/// `Theme.of(context).extension<CampColors>()!`.
@immutable
class CampColors extends ThemeExtension<CampColors> {
  final Color sunset;
  final Color sunsetDeep;
  final Color sunsetSoft;
  final Color onSunsetSoft;

  const CampColors({
    required this.sunset,
    required this.sunsetDeep,
    required this.sunsetSoft,
    required this.onSunsetSoft,
  });

  @override
  CampColors copyWith({
    Color? sunset,
    Color? sunsetDeep,
    Color? sunsetSoft,
    Color? onSunsetSoft,
  }) {
    return CampColors(
      sunset: sunset ?? this.sunset,
      sunsetDeep: sunsetDeep ?? this.sunsetDeep,
      sunsetSoft: sunsetSoft ?? this.sunsetSoft,
      onSunsetSoft: onSunsetSoft ?? this.onSunsetSoft,
    );
  }

  @override
  CampColors lerp(ThemeExtension<CampColors>? other, double t) {
    if (other is! CampColors) return this;
    return CampColors(
      sunset: Color.lerp(sunset, other.sunset, t)!,
      sunsetDeep: Color.lerp(sunsetDeep, other.sunsetDeep, t)!,
      sunsetSoft: Color.lerp(sunsetSoft, other.sunsetSoft, t)!,
      onSunsetSoft: Color.lerp(onSunsetSoft, other.onSunsetSoft, t)!,
    );
  }
}
