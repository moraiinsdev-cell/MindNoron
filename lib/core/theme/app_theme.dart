import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium, calm theme for MindNoron (dark-first, light available).
///
/// Design language: a controlled deep teal-charcoal palette, hairline-bordered
/// surfaces that lift subtly above the background, soft radii and refined
/// typography. Inspired by Linear / Notion — quiet, dense, professional.
///
/// The whole app is styled from here: overriding [ColorScheme] surface ramps
/// and the component themes propagates the look to every screen without
/// touching feature logic. Reusable tokens live on [AppRadii]/[AppSpace] and
/// the [PremiumSurface] extension.
class AppTheme {
  AppTheme._();

  /// Primary accent — teal.
  static const Color seed = Color(0xFF2DD4BF); // teal-400
  static const Color accentBlue = Color(0xFF38BDF8); // sky-400
  static const Color accentViolet = Color(0xFF8B5CF6); // violet-500
  static const Color accentAmber = Color(0xFFF6B35A); // warm amber

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  // ---- Dark surface ramp: a cool near-black with the faintest teal cast. ----
  static const _darkBg = Color(0xFF0B0F0F);
  static const _darkSurfaceLowest = Color(0xFF080B0B);
  static const _darkSurfaceLow = Color(0xFF101615);
  static const _darkSurface = Color(0xFF141B1A);
  static const _darkSurfaceHigh = Color(0xFF19211F);
  static const _darkSurfaceHighest = Color(0xFF1F2826);
  static const _darkOutline = Color(0xFF39443F);
  static const _darkOutlineVariant = Color(0xFF283130);
  static const _darkOnSurface = Color(0xFFE6ECEA);
  static const _darkOnSurfaceVariant = Color(0xFFA3B1AD);

  // ---- Light ramp: soft warm-white with cool cards. ----
  static const _lightBg = Color(0xFFF6F8F7);
  static const _lightSurfaceLowest = Color(0xFFFFFFFF);
  static const _lightSurfaceLow = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFF1F4F3);
  static const _lightSurfaceHigh = Color(0xFFEBEFEE);
  static const _lightSurfaceHighest = Color(0xFFE4E9E7);
  static const _lightOutline = Color(0xFFC2CCC9);
  static const _lightOutlineVariant = Color(0xFFDCE3E1);
  static const _lightOnSurface = Color(0xFF15201E);
  static const _lightOnSurfaceVariant = Color(0xFF54615D);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    // Take Material's tonal pairs (correct contrast) but replace the surface
    // ramp and a few key colours with our controlled palette.
    final colorScheme = isDark
        ? base.copyWith(
            surface: _darkBg,
            surfaceContainerLowest: _darkSurfaceLowest,
            surfaceContainerLow: _darkSurfaceLow,
            surfaceContainer: _darkSurface,
            surfaceContainerHigh: _darkSurfaceHigh,
            surfaceContainerHighest: _darkSurfaceHighest,
            surfaceDim: _darkBg,
            surfaceBright: _darkSurfaceHighest,
            onSurface: _darkOnSurface,
            onSurfaceVariant: _darkOnSurfaceVariant,
            outline: _darkOutline,
            outlineVariant: _darkOutlineVariant,
            primary: seed,
            onPrimary: const Color(0xFF00201C),
            primaryContainer: const Color(0xFF0F3A35),
            onPrimaryContainer: const Color(0xFF8CF3E4),
            secondary: accentBlue,
            secondaryContainer: const Color(0xFF123243),
            onSecondaryContainer: const Color(0xFFBCE6FA),
          )
        : base.copyWith(
            surface: _lightBg,
            surfaceContainerLowest: _lightSurfaceLowest,
            surfaceContainerLow: _lightSurfaceLow,
            surfaceContainer: _lightSurface,
            surfaceContainerHigh: _lightSurfaceHigh,
            surfaceContainerHighest: _lightSurfaceHighest,
            surfaceDim: _lightSurfaceHighest,
            surfaceBright: _lightSurfaceLowest,
            onSurface: _lightOnSurface,
            onSurfaceVariant: _lightOnSurfaceVariant,
            outline: _lightOutline,
            outlineVariant: _lightOutlineVariant,
            primary: const Color(0xFF0E9B8A),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFB8F3EA),
            onPrimaryContainer: const Color(0xFF00332D),
          );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Segoe UI',
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    final textTheme = _textTheme(baseTheme.textTheme, colorScheme);

    return baseTheme.copyWith(
      textTheme: textTheme,
      // Subtle: shadows in dark are near-invisible; borders carry the depth.
      shadowColor: isDark ? Colors.black : const Color(0x33334B45),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: baseTheme.shadowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.7 : 1),
          ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: isDark ? 0 : 8,
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.8 : 0),
          ),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: isDark ? 0 : 6,
        color: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.16 : 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: colorScheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colorScheme.primary.withValues(alpha: 0.16),
          selectedForegroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        showDuration: const Duration(milliseconds: 1800),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.transparent
                : colorScheme.outlineVariant),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(999),
        thumbColor: WidgetStatePropertyAll(
          colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme cs) {
    // Tighten headings, relax body — a quiet, editorial rhythm.
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: cs.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: cs.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: cs.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: cs.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: cs.onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45, color: cs.onSurface),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45, color: cs.onSurface),
      bodySmall: base.bodySmall?.copyWith(height: 1.4),
      labelLarge: base.labelLarge?.copyWith(letterSpacing: 0.1),
    );
  }

  /// Overlay style so the desktop title-bar area blends with our surfaces.
  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return dark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          );
  }
}

/// Corner radii tokens — one soft, consistent geometry across the app.
abstract final class AppRadii {
  static const double sm = 10;
  static const double md = 12;
  static const double button = 12;
  static const double card = 16;
  static const double dialog = 20;
  static const double lg = 20;
  static const double pill = 999;
}

/// Spacing scale (multiples of 4). Use for consistent gaps and padding.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

/// Reusable premium surface helpers used by feature screens for accent panels
/// and soft-elevated containers that go beyond the default [Card].
extension PremiumSurface on ColorScheme {
  /// A soft-elevated panel decoration: lifted surface + hairline border.
  BoxDecoration panel({double radius = AppRadii.card, Color? tint}) {
    return BoxDecoration(
      color: tint ?? surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: outlineVariant),
    );
  }

  /// A subtle tinted accent panel (e.g. hero cards, callouts).
  BoxDecoration accentPanel(Color accent,
      {double radius = AppRadii.card, double fill = 0.10}) {
    return BoxDecoration(
      color: accent.withValues(alpha: fill),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.28)),
    );
  }

  /// A vertical accent gradient for hero headers.
  Gradient heroGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.16),
          accent.withValues(alpha: 0.02),
        ],
      );
}
