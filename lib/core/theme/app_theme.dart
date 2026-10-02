import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';

export 'motion.dart';

/// MindNoron's theme — Apple "Liquid Glass" language (dark-first, light too).
///
/// * **Colour**: Apple's system palette ([AppleColors]) over a near-black
///   (dark) / grouped-grey (light) canvas, with a living aurora behind
///   translucent glass. System blue is the tint, as on iPhone.
/// * **Shape**: continuous-curvature corners (superellipse "squircles") and
///   capsule buttons — see [AppRadii] and [AppShapes].
/// * **Type**: Inter (the open cousin of SF Pro) for text, the tighter
///   InterDisplay cut for titles, SF-style negative tracking throughout.
/// * **Motion**: springs, see [AppSprings] / [AppMotion].
///
/// The whole app is styled from here: overriding [ColorScheme] surface ramps
/// and the component themes propagates the look to every screen without
/// touching feature logic.
class AppTheme {
  AppTheme._();

  /// Primary tint — Apple system blue.
  static const Color seed = AppleColors.blue;

  /// Secondary accents. Names kept for existing call sites; values are the
  /// Apple system hues that best fill each role.
  static const Color accentBlue = AppleColors.cyan;
  static const Color accentViolet = AppleColors.indigo;
  static const Color accentAmber = AppleColors.orange;

  /// Ambient backdrop hues — the iOS-wallpaper wash the glass floats above.
  static const List<Color> aurora = [
    AppleColors.blue,
    AppleColors.indigo,
    AppleColors.purple,
    AppleColors.teal,
  ];

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  // ---- Dark ramp: OLED near-black with Apple's elevated greys. ----
  static const _darkBg = Color(0xFF050507);
  static const _darkSurfaceLowest = Color(0xFF000000);
  static const _darkSurfaceLow = Color(0xFF0E0E11);
  static const _darkSurface = Color(0xFF1C1C1E); // secondarySystemBackground
  static const _darkSurfaceHigh = Color(0xFF242427);
  // Highest is used across the app as a *fill* (tracks, chips, idle tiles),
  // so it is iOS's translucent tertiarySystemFill — it tints whatever glass
  // or aurora it sits on instead of punching an opaque grey hole in it.
  static const _darkSurfaceHighest = Color(0x3D767680);
  static const _darkOutline = Color(0xFF48484A); // systemGray3
  static const _darkOutlineVariant = Color(0xFF2E2E31); // separator
  static const _darkOnSurface = Color(0xFFF5F5F7);
  static const _darkOnSurfaceVariant = Color(0xFF98989F); // secondaryLabel

  // ---- Light ramp: systemGroupedBackground with white cards. ----
  static const _lightBg = Color(0xFFF2F2F7);
  static const _lightSurfaceLowest = Color(0xFFFFFFFF);
  static const _lightSurfaceLow = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFF7F7FA);
  static const _lightSurfaceHigh = Color(0xFFEDEDF2);
  static const _lightSurfaceHighest = Color(0x1F767680);
  static const _lightOutline = Color(0xFFC7C7CC); // systemGray4
  static const _lightOutlineVariant = Color(0xFFDDDDE2);
  static const _lightOnSurface = Color(0xFF1D1D1F);
  static const _lightOnSurfaceVariant = Color(0xFF6E6E73);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    // Take Material's tonal pairs (correct contrast) but replace the surface
    // ramp and the key colours with Apple's system palette.
    final colorScheme = isDark
        ? base.copyWith(
            surface: _darkBg,
            surfaceContainerLowest: _darkSurfaceLowest,
            surfaceContainerLow: _darkSurfaceLow,
            surfaceContainer: _darkSurface,
            surfaceContainerHigh: _darkSurfaceHigh,
            surfaceContainerHighest: _darkSurfaceHighest,
            surfaceDim: _darkBg,
            surfaceBright: const Color(0xFF2C2C2E),
            onSurface: _darkOnSurface,
            onSurfaceVariant: _darkOnSurfaceVariant,
            outline: _darkOutline,
            outlineVariant: _darkOutlineVariant,
            primary: AppleColors.blue,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFF0A2A4D),
            onPrimaryContainer: const Color(0xFFB4D8FF),
            secondary: AppleColors.indigo,
            onSecondary: Colors.white,
            // Tonal buttons = iOS "tinted": blue wash with a blue label.
            secondaryContainer: const Color(0xFF0E2744),
            onSecondaryContainer: const Color(0xFF5AAEFF),
            tertiary: AppleColors.purple,
            onTertiary: Colors.white,
            error: AppleColors.red,
            onError: Colors.white,
            // Tinted, not alarming: iOS-style red wash with a soft red label.
            errorContainer: const Color(0xFF3A1A1D),
            onErrorContainer: const Color(0xFFFF8F87),
            tertiaryContainer: const Color(0xFF34203F),
            onTertiaryContainer: const Color(0xFFE5B8FF),
            inverseSurface: const Color(0xFFF5F5F7),
            onInverseSurface: const Color(0xFF1D1D1F),
          )
        : base.copyWith(
            surface: _lightBg,
            surfaceContainerLowest: _lightSurfaceLowest,
            surfaceContainerLow: _lightSurfaceLow,
            surfaceContainer: _lightSurface,
            surfaceContainerHigh: _lightSurfaceHigh,
            surfaceContainerHighest: _lightSurfaceHighest,
            surfaceDim: const Color(0xFFE5E5EA),
            surfaceBright: _lightSurfaceLowest,
            onSurface: _lightOnSurface,
            onSurfaceVariant: _lightOnSurfaceVariant,
            outline: _lightOutline,
            outlineVariant: _lightOutlineVariant,
            primary: AppleColors.blueLight,
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFFD6E9FF),
            onPrimaryContainer: const Color(0xFF002E5C),
            secondary: AppleColors.indigoLight,
            onSecondary: Colors.white,
            secondaryContainer: const Color(0xFFDDECFF),
            onSecondaryContainer: AppleColors.blueLight,
            tertiary: AppleColors.purpleLight,
            onTertiary: Colors.white,
            error: AppleColors.redLight,
            onError: Colors.white,
            errorContainer: const Color(0xFFFFE6E4),
            onErrorContainer: const Color(0xFFB3261E),
            inverseSurface: const Color(0xFF1D1D1F),
            onInverseSurface: const Color(0xFFF5F5F7),
          );

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Inter',
      // Apple surfaces highlight, they don't ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.06),
      hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
      focusColor: colorScheme.primary.withValues(alpha: 0.14),
      scaffoldBackgroundColor: colorScheme.surface,
    );

    final textTheme = _textTheme(baseTheme.textTheme, colorScheme);
    // iOS tertiarySystemFill — the soft grey behind fields and controls.
    final fill = const Color(0xFF767680).withValues(alpha: isDark ? 0.24 : 0.12);
    // Popovers/menus: a near-opaque raised material.
    final raised = isDark ? const Color(0xF2252528) : const Color(0xF7FFFFFF);
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);

    return baseTheme.copyWith(
      textTheme: textTheme,
      // Content settles in with a soft rise on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _GentleRisePageTransitionsBuilder(),
          TargetPlatform.macOS: _GentleRisePageTransitionsBuilder(),
          TargetPlatform.linux: _GentleRisePageTransitionsBuilder(),
          TargetPlatform.android: _GentleRisePageTransitionsBuilder(),
          TargetPlatform.iOS: _GentleRisePageTransitionsBuilder(),
        },
      ),
      shadowColor: isDark ? Colors.black : const Color(0x1F1D1D3A),
      cardTheme: CardThemeData(
        elevation: 0,
        // Glass: translucent fill + light-catch border so every Card in the
        // app floats over the aurora backdrop without per-screen changes.
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white.withValues(alpha: 0.68),
        surfaceTintColor: Colors.transparent,
        shadowColor: baseTheme.shadowColor,
        shape: AppShapes.squircle(
          AppRadii.card,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.95),
          ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black,
        barrierColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.28),
        shape: AppShapes.squircle(
          AppRadii.dialog,
          side: BorderSide(color: hairline),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1C1C1F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.dialog),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 8,
        color: raised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
        shape: AppShapes.squircle(AppRadii.md, side: BorderSide(color: hairline)),
        textStyle: textTheme.bodyMedium,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: isDark ? 0.6 : 0.18)),
          shape: WidgetStatePropertyAll(
            AppShapes.squircle(AppRadii.md, side: BorderSide(color: hairline)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            AppShapes.squircle(AppRadii.md, side: BorderSide(color: hairline)),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        // Transparent: the shell wraps the rail in its own glass material.
        backgroundColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.14),
        indicatorShape: AppShapes.squircle(AppRadii.md),
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 22),
        unselectedIconTheme:
            IconThemeData(color: colorScheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      // Capsule buttons — the iOS 26 control silhouette.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: fill,
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          // Apple has no outlined buttons — render as a tinted "gray" button
          // with a hairline so existing call sites read as iOS bordered.
          backgroundColor: fill,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: hairline),
          shape: const StadiumBorder(),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: fill,
          selectedBackgroundColor: isDark
              ? const Color(0xFF636366).withValues(alpha: 0.9)
              : Colors.white,
          selectedForegroundColor: colorScheme.onSurface,
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: hairline),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: AppShapes.squircle(AppRadii.lg),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: const CircleBorder()),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: colorScheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        checkmarkColor: colorScheme.primary,
        side: BorderSide(color: hairline),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: hairline),
        ),
        // macOS-style focus ring: a soft tinted halo, not a hard outline.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.75),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error.withValues(alpha: 0.7)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: AppShapes.squircle(AppRadii.md),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        space: 1,
        thickness: 0.8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xF22C2C2E) : const Color(0xF21D1D1F),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppleColors.blue,
        elevation: 6,
        shape: AppShapes.squircle(AppRadii.lg),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(milliseconds: 1800),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          color: isDark ? const Color(0xF22C2C2E) : const Color(0xF7FFFFFF),
          shape: AppShapes.squircle(AppRadii.xs, side: BorderSide(color: hairline)),
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        textStyle: textTheme.labelMedium?.copyWith(color: colorScheme.onSurface),
      ),
      // iOS slider: thin track, white knob.
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: fill,
        thumbColor: Colors.white,
        overlayColor: colorScheme.primary.withValues(alpha: 0.10),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 10,
          elevation: 3,
          pressedElevation: 5,
        ),
      ),
      // iOS switch: green track, white knob, no outline.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        // A (transparent) thumb icon keeps the knob full-size when off, as on
        // iOS, instead of Material's shrunken unselected thumb.
        thumbIcon: const WidgetStatePropertyAll(
          Icon(Icons.circle, color: Colors.transparent),
        ),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? (isDark ? AppleColors.green : AppleColors.greenLight)
                : const Color(0xFF787880)
                    .withValues(alpha: isDark ? 0.32 : 0.16)),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: colorScheme.outline, width: 1.6),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: fill,
        circularTrackColor: fill,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        strokeCap: StrokeCap.round,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        // A sliding capsule, like an iOS segmented control.
        indicator: ShapeDecoration(
          color: colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.08),
          shape: const StadiumBorder(),
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
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
    // SF-style rhythm: titles on the tighter InterDisplay cut with strong
    // negative tracking; text sizes on Inter with Apple's slight tightening.
    TextStyle? display(TextStyle? s, double tracking,
            [FontWeight w = FontWeight.w700]) =>
        s?.copyWith(
          fontFamily: 'InterDisplay',
          fontWeight: w,
          letterSpacing: tracking,
          height: 1.12,
          color: cs.onSurface,
        );

    return base.copyWith(
      displayLarge: display(base.displayLarge, -1.6),
      displayMedium: display(base.displayMedium, -1.2),
      displaySmall: display(base.displaySmall, -0.9),
      headlineLarge: display(base.headlineLarge, -0.9),
      headlineMedium: display(base.headlineMedium, -0.7),
      headlineSmall: display(base.headlineSmall, -0.55),
      titleLarge: display(base.titleLarge, -0.4, FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: cs.onSurface,
      ),
      bodyLarge: base.bodyLarge
          ?.copyWith(height: 1.45, letterSpacing: -0.18, color: cs.onSurface),
      bodyMedium: base.bodyMedium
          ?.copyWith(height: 1.45, letterSpacing: -0.08, color: cs.onSurface),
      bodySmall: base.bodySmall?.copyWith(height: 1.4, letterSpacing: 0),
      labelLarge: base.labelLarge?.copyWith(letterSpacing: -0.08),
      labelMedium: base.labelMedium?.copyWith(letterSpacing: 0),
      labelSmall: base.labelSmall?.copyWith(letterSpacing: 0.1),
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

/// Apple's system colours. The plain names are the dark-appearance (vibrant)
/// variants — they read well as accents on both themes; `…Light` are the
/// light-appearance variants for text and fills on light backgrounds.
abstract final class AppleColors {
  static const blue = Color(0xFF0A84FF);
  static const indigo = Color(0xFF5E5CE6);
  static const purple = Color(0xFFBF5AF2);
  static const pink = Color(0xFFFF375F);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const yellow = Color(0xFFFFD60A);
  static const green = Color(0xFF30D158);
  static const mint = Color(0xFF63E6E2);
  static const teal = Color(0xFF40CBE0);
  static const cyan = Color(0xFF64D2FF);
  static const brown = Color(0xFFAC8E68);
  static const gray = Color(0xFF8E8E93);

  static const blueLight = Color(0xFF007AFF);
  static const indigoLight = Color(0xFF5856D6);
  static const purpleLight = Color(0xFFAF52DE);
  static const pinkLight = Color(0xFFFF2D55);
  static const redLight = Color(0xFFFF3B30);
  static const orangeLight = Color(0xFFFF9500);
  static const yellowLight = Color(0xFFFFCC00);
  static const greenLight = Color(0xFF34C759);
  static const mintLight = Color(0xFF00C7BE);
  static const tealLight = Color(0xFF30B0C7);
  static const cyanLight = Color(0xFF32ADE6);
}

/// Corner radii — generous, concentric geometry (inner radius = outer radius
/// minus padding), drawn as continuous-curvature squircles via [AppShapes].
abstract final class AppRadii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 14;
  static const double button = 14;
  static const double card = 22;
  static const double lg = 26;
  static const double dialog = 30;
  static const double xl = 34;
  static const double pill = 999;
}

/// Apple's continuous-corner ("squircle") shapes. Prefer these over
/// [RoundedRectangleBorder] — the curvature eases into the straight edge
/// instead of snapping, which is most of what makes iOS shapes look soft.
abstract final class AppShapes {
  static RoundedSuperellipseBorder squircle(double radius,
          {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
        side: side,
      );
}

/// Spacing scale (multiples of 4). Use for consistent gaps and padding.
abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;
}

/// Frosted-glass tuning shared by [PremiumSurface.glass] and the glass
/// widgets in ui_kit. One place to tune the whole material.
abstract final class AppGlass {
  /// Backdrop blur sigma for true frosted surfaces (rail, dialogs, pips).
  static const double blur = 30;

  /// Colour saturation boost applied under frosted glass — the "vibrancy"
  /// that makes iOS materials look alive rather than grey.
  static const double saturation = 1.6;
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

  /// Translucent glass-panel decoration (no blur — cheap, use anywhere).
  /// Over the ambient aurora backdrop this reads as vibrancy; pair with a
  /// BackdropFilter (see ui_kit `GlassSurface`) where content scrolls behind.
  BoxDecoration glass({
    double radius = AppRadii.card,
    double opacity = 1,
  }) {
    final dark = brightness == Brightness.dark;
    return BoxDecoration(
      color: dark
          ? Colors.white.withValues(alpha: 0.06 * opacity)
          : Colors.white.withValues(alpha: 0.64 * opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: dark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.9),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  /// The faint top-edge light catch that sells the glass — layer above a
  /// [glass] fill.
  Gradient get glassSheen => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(
              alpha: brightness == Brightness.dark ? 0.06 : 0.4),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.5],
      );

  /// A subtle tinted accent panel (e.g. hero cards, callouts).
  BoxDecoration accentPanel(Color accent,
      {double radius = AppRadii.card, double fill = 0.12}) {
    return BoxDecoration(
      color: accent.withValues(alpha: fill),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: accent.withValues(alpha: 0.26)),
    );
  }

  /// A diagonal accent gradient for hero headers.
  Gradient heroGradient(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: 0.20),
          accent.withValues(alpha: 0.03),
        ],
      );
}

/// Quiet fade + soft rise for route changes — no sliding panes, just content
/// settling into place.
class _GentleRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const _GentleRisePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.easeOutQuint,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
