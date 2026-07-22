import 'package:package_info_plus/package_info_plus.dart';

/// App identity read from the platform bundle at startup, so the version
/// shown in the UI always tracks `version:` in pubspec.yaml — there is no
/// second copy to keep in sync.
class AppInfo {
  /// Semantic version, e.g. `1.0.0`.
  static String version = '';

  /// Build number, e.g. `1`. Empty when the platform reports none.
  static String build = '';

  /// `v1.0.0` — the compact form for the toolbar. Empty until [load] runs.
  static String get shortLabel => version.isEmpty ? '' : 'v$version';

  /// `1.0.0 (build 1)` — the long form for the About dialog.
  static String get fullLabel {
    if (version.isEmpty) return 'unknown';
    return build.isEmpty ? version : '$version (build $build)';
  }

  /// Populates the fields above. Call once from `main` before `runApp` so
  /// widgets can read the version synchronously.
  static Future<void> load() async {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    build = info.buildNumber;
  }
}
