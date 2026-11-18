import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool get isTouchPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

const double kCompactBreakpoint = 600;

/// Mono font family stack — IBM Plex Mono if installed, else system mono.
const String kMonoFontFamily = 'monospace';
const List<String> kMonoFontFamilyFallback = <String>[
  'IBM Plex Mono',
  'JetBrains Mono',
  'SF Mono',
  'Consolas',
  'monospace',
];
const List<String> kSansFontFamilyFallback = <String>[
  'IBM Plex Sans',
  'Inter',
  'system-ui',
  '-apple-system',
];

/// Brightness mode. Listened to by the root [MbtApp] and the few widgets
/// (e.g. the cockatiel brand mark) that need to know. Named with an `App`
/// prefix so it doesn't clash with Flutter's own [ThemeMode].
enum AppThemeMode { dark, light }

class _Palette {
  // Backgrounds — layered deepest → surface
  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color bg4;
  final Color bgSelected;

  // Borders
  final Color border;
  final Color borderStrong;
  final Color borderFaint;

  // Text
  final Color text;
  final Color textMuted;
  final Color textDim;
  final Color textFaint;

  // Brand accent
  final Color accent;
  final Color accentDim;
  final Color accentBg;
  final Color onAccent;

  // Status
  final Color online;
  final Color onlineDim;
  final Color onlineBg;
  final Color onOnline;

  final Color connecting;
  final Color connectingDim;
  final Color connectingBg;

  final Color error;
  final Color errorDim;
  final Color errorBg;
  final Color onError;

  final Color offline;
  final Color offlineBg;

  final Color warn;
  final Color warnBg;

  // TX / RX direction
  final Color tx;
  final Color rx;

  // Format hint chips
  final Color fmtNum;
  final Color fmtHex;
  final Color fmtBin;
  final Color fmtFloat;
  final Color fmtAscii;
  final Color fmtBool;

  const _Palette({
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.bg3,
    required this.bg4,
    required this.bgSelected,
    required this.border,
    required this.borderStrong,
    required this.borderFaint,
    required this.text,
    required this.textMuted,
    required this.textDim,
    required this.textFaint,
    required this.accent,
    required this.accentDim,
    required this.accentBg,
    required this.onAccent,
    required this.online,
    required this.onlineDim,
    required this.onlineBg,
    required this.onOnline,
    required this.connecting,
    required this.connectingDim,
    required this.connectingBg,
    required this.error,
    required this.errorDim,
    required this.errorBg,
    required this.onError,
    required this.offline,
    required this.offlineBg,
    required this.warn,
    required this.warnBg,
    required this.tx,
    required this.rx,
    required this.fmtNum,
    required this.fmtHex,
    required this.fmtBin,
    required this.fmtFloat,
    required this.fmtAscii,
    required this.fmtBool,
  });
}

const _Palette _darkPalette = _Palette(
  bg0: Color(0xFF0A0F14),
  bg1: Color(0xFF0D1419),
  bg2: Color(0xFF151C23),
  bg3: Color(0xFF1C242C),
  bg4: Color(0xFF252F38),
  bgSelected: Color(0xFF13303D),
  border: Color(0xFF2A3540),
  borderStrong: Color(0xFF3A4754),
  borderFaint: Color(0xFF1F2832),
  text: Color(0xFFE6EDF3),
  textMuted: Color(0xFF8B98A5),
  textDim: Color(0xFF5A6675),
  textFaint: Color(0xFF3F4A55),
  accent: Color(0xFF39BAE6),
  accentDim: Color(0xFF2A8FB3),
  accentBg: Color(0xFF13303D),
  onAccent: Color(0xFF06121A),
  online: Color(0xFFAAD94C),
  onlineDim: Color(0xFF7BA534),
  onlineBg: Color(0xFF1F2A14),
  onOnline: Color(0xFF0D1419),
  connecting: Color(0xFFFFB454),
  connectingDim: Color(0xFFC4862F),
  connectingBg: Color(0xFF2A1F0E),
  error: Color(0xFFF07178),
  errorDim: Color(0xFFB8454C),
  errorBg: Color(0xFF2A141A),
  onError: Color(0xFF0D0809),
  offline: Color(0xFF5A6675),
  offlineBg: Color(0xFF1A2028),
  warn: Color(0xFFFFB454),
  warnBg: Color(0xFF2A1F0E),
  tx: Color(0xFFFFB454),
  rx: Color(0xFF39BAE6),
  fmtNum: Color(0xFFAAD94C),
  fmtHex: Color(0xFF39BAE6),
  fmtBin: Color(0xFFC39BF0),
  fmtFloat: Color(0xFFFFB454),
  fmtAscii: Color(0xFF7CD1C0),
  fmtBool: Color(0xFFF07178),
);

const _Palette _lightPalette = _Palette(
  bg0: Color(0xFFF5F3EF),
  bg1: Color(0xFFFFFFFF),
  bg2: Color(0xFFFAFAF7),
  bg3: Color(0xFFF0EDE8),
  bg4: Color(0xFFE4E0D8),
  bgSelected: Color(0xFFD6ECF5),
  border: Color(0xFFD4CFC6),
  borderStrong: Color(0xFFB0AAA0),
  borderFaint: Color(0xFFECE8E0),
  text: Color(0xFF1A1F24),
  textMuted: Color(0xFF525C66),
  textDim: Color(0xFF7A8390),
  textFaint: Color(0xFFA8AEB5),
  accent: Color(0xFF0277A8),
  accentDim: Color(0xFF015A82),
  accentBg: Color(0xFFCDE9F5),
  onAccent: Color(0xFFFFFFFF),
  online: Color(0xFF3D7A16),
  onlineDim: Color(0xFF2C5A10),
  onlineBg: Color(0xFFE3EDD0),
  onOnline: Color(0xFFFFFFFF),
  connecting: Color(0xFFA05C08),
  connectingDim: Color(0xFF7A4406),
  connectingBg: Color(0xFFFAECD0),
  error: Color(0xFFB8262E),
  errorDim: Color(0xFF8E1C22),
  errorBg: Color(0xFFF5D8DA),
  onError: Color(0xFFFFFFFF),
  offline: Color(0xFF8A9099),
  offlineBg: Color(0xFFECE8E0),
  warn: Color(0xFFA05C08),
  warnBg: Color(0xFFFAECD0),
  tx: Color(0xFFA05C08),
  rx: Color(0xFF0277A8),
  fmtNum: Color(0xFF3D7A16),
  fmtHex: Color(0xFF0277A8),
  fmtBin: Color(0xFF7A3AA0),
  fmtFloat: Color(0xFFA05C08),
  fmtAscii: Color(0xFF0A7066),
  fmtBool: Color(0xFFB8262E),
);

/// Active palette. Mutable so widgets can read static-style `AppColors.bg0`,
/// while [setThemeMode] flips it under everyone in one place.
_Palette _active = _darkPalette;
AppThemeMode _activeMode = AppThemeMode.dark;

AppThemeMode get currentThemeMode => _activeMode;

/// Notifies listeners (root app + ad-hoc consumers) when the palette changes.
final ValueNotifier<AppThemeMode> themeModeNotifier =
    ValueNotifier<AppThemeMode>(AppThemeMode.dark);

const String _kPrefThemeMode = 'ui.themeMode';

void _applyThemeMode(AppThemeMode mode) {
  _activeMode = mode;
  _active = mode == AppThemeMode.light ? _lightPalette : _darkPalette;
  themeModeNotifier.value = mode;
}

/// Switches the palette and remembers the choice for the next launch.
void setThemeMode(AppThemeMode mode) {
  if (mode == _activeMode) return;
  _applyThemeMode(mode);
  SharedPreferences.getInstance()
      .then((prefs) => prefs.setString(_kPrefThemeMode, mode.name));
}

/// Restores the persisted theme. Call before `runApp` so the first frame
/// already uses the right palette (no dark→light flash).
Future<void> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kPrefThemeMode);
    for (final m in AppThemeMode.values) {
      if (m.name == name) {
        _applyThemeMode(m);
        return;
      }
    }
  } catch (_) {
    // Prefs unavailable — keep the default palette.
  }
}

/// Token façade. Static-style call sites (`AppColors.bg`) keep working but
/// now resolve to the live palette.
class AppColors {
  // Backgrounds (new layered names)
  static Color get bg0 => _active.bg0;
  static Color get bg1 => _active.bg1;
  static Color get bg2 => _active.bg2;
  static Color get bg3 => _active.bg3;
  static Color get bg4 => _active.bg4;
  static Color get bgSelected => _active.bgSelected;

  // Legacy aliases — keep the rest of the codebase compiling without churn.
  static Color get bg => _active.bg0;            // app shell
  static Color get bgRaised => _active.bg3;      // toolbar / pane header
  static Color get panel => _active.bg2;         // pane body / sidebar

  // Borders
  static Color get border => _active.border;
  static Color get borderStrong => _active.borderStrong;
  static Color get borderFaint => _active.borderFaint;

  // Text
  static Color get text => _active.text;
  static Color get textMuted => _active.textMuted;
  static Color get textDim => _active.textDim;
  static Color get textFaint => _active.textFaint;

  // Brand
  static Color get brand => _active.accent;
  static Color get accent => _active.accent;
  static Color get accentDim => _active.accentDim;
  static Color get accentBg => _active.accentBg;
  static Color get onAccent => _active.onAccent;

  // Status
  static Color get warn => _active.warn;
  static Color get warnBg => _active.warnBg;
  static Color get danger => _active.error;
  static Color get error => _active.error;
  static Color get errorDim => _active.errorDim;
  static Color get errorBg => _active.errorBg;
  static Color get onError => _active.onError;

  static Color get online => _active.online;
  static Color get onlineDim => _active.onlineDim;
  static Color get onlineBg => _active.onlineBg;
  static Color get onOnline => _active.onOnline;

  static Color get connecting => _active.connecting;
  static Color get connectingBg => _active.connectingBg;

  static Color get offline => _active.offline;
  static Color get offlineBg => _active.offlineBg;

  // Connection-state aliases (used by older widgets)
  static Color get connDisconnected => _active.offline;
  static Color get connConnecting => _active.connecting;
  static Color get connConnected => _active.online;
  static Color get connError => _active.error;

  // Direction
  static Color get tx => _active.tx;
  static Color get rx => _active.rx;

  // Format chip tints
  static Color get fmtNum => _active.fmtNum;
  static Color get fmtHex => _active.fmtHex;
  static Color get fmtBin => _active.fmtBin;
  static Color get fmtFloat => _active.fmtFloat;
  static Color get fmtAscii => _active.fmtAscii;
  static Color get fmtBool => _active.fmtBool;

  /// Subtle write-flash overlay used by the table view.
  static Color get updateFlash => _active.connecting.withValues(alpha: 0.20);
}

/// Typography helpers — match the design's TY scale.
class AppType {
  static const TextStyle display = TextStyle(
    fontSize: 22,
    height: 1.2,
    letterSpacing: -0.22,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 17,
    height: 1.25,
    letterSpacing: -0.085,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.45,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle bodySm = TextStyle(
    fontSize: 12,
    height: 1.4,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.88,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle labelSm = TextStyle(
    fontSize: 10,
    height: 1.2,
    letterSpacing: 1.0,
    fontWeight: FontWeight.w600,
    fontFamilyFallback: kSansFontFamilyFallback,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontFamilyFallback: kSansFontFamilyFallback,
  );

  // Mono — values, addresses, hex, packets
  static const TextStyle monoLg = TextStyle(
    fontFamily: kMonoFontFamily,
    fontFamilyFallback: kMonoFontFamilyFallback,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle mono = TextStyle(
    fontFamily: kMonoFontFamily,
    fontFamilyFallback: kMonoFontFamilyFallback,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle monoSm = TextStyle(
    fontFamily: kMonoFontFamily,
    fontFamilyFallback: kMonoFontFamilyFallback,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle monoAddr = TextStyle(
    fontFamily: kMonoFontFamily,
    fontFamilyFallback: kMonoFontFamilyFallback,
    fontSize: 11,
    height: 1.2,
  );
}

/// Build the Material theme for the current palette.
ThemeData buildAppTheme(AppThemeMode mode) {
  final pal = mode == AppThemeMode.light ? _lightPalette : _darkPalette;
  final brightness = mode == AppThemeMode.light ? Brightness.light : Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: pal.accent,
    onPrimary: pal.onAccent,
    secondary: pal.accent,
    onSecondary: pal.onAccent,
    error: pal.error,
    onError: pal.onError,
    surface: pal.bg1,
    onSurface: pal.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: pal.bg0,
    canvasColor: pal.bg0,
    fontFamilyFallback: kSansFontFamilyFallback,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: pal.text, fontSize: 13, height: 1.45),
      bodySmall: TextStyle(color: pal.textMuted, fontSize: 12),
      titleMedium: TextStyle(
        color: pal.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: pal.border,
    cardTheme: CardThemeData(
      color: pal.bg2,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.bg2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: pal.borderStrong),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: pal.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: pal.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: pal.bg3,
      contentTextStyle: TextStyle(color: pal.text, fontSize: 12),
    ),
  );
}
