import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

/// Are we currently running on a touch-first OS (iOS or Android)?
/// Used to pick larger hit targets, long-press editing, etc.
bool get isTouchPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Below this width the UI collapses the sidebar into a drawer and
/// folds the secondary toolbar buttons into an overflow menu. 600 is
/// the conventional Material breakpoint between phone and tablet.
const double kCompactBreakpoint = 600;

/// Color tokens from GUI.md §7.2 dark palette.
class AppColors {
  static const bg = Color(0xFF0E1116);
  static const bgRaised = Color(0xFF13171D);
  static const panel = Color(0xFF1A1F26);
  static const border = Color(0xFF2A323D);
  static const text = Color(0xFFE6EAF0);
  static const textMuted = Color(0xFF8A95A5);
  static const brand = Color(0xFF3DDC97);
  static const warn = Color(0xFFF5A524);
  static const danger = Color(0xFFF31260);
  static const updateFlash = Color(0x33FFB357); // 20% alpha orange

  // Connection state colors — high contrast, distinct hues so colour-blind
  // users can also tell them apart by lightness.
  static const connDisconnected = Color(0xFF606A78); // medium grey
  static const connConnecting = Color(0xFFFFC857);   // bright amber
  static const connConnected = Color(0xFF22D88F);    // saturated green
  static const connError = Color(0xFFFF3D6E);        // hot pink-red
}

ThemeData buildDarkTheme() {
  const baseScheme = ColorScheme.dark(
    surface: AppColors.bg,
    onSurface: AppColors.text,
    primary: AppColors.brand,
    onPrimary: Color(0xFF062013),
    secondary: AppColors.brand,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text, fontSize: 13, height: 1.4),
      bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
      titleMedium: TextStyle(
          color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
    ),
    dividerColor: AppColors.border,
    cardTheme: const CardThemeData(
      color: AppColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
  );
}
