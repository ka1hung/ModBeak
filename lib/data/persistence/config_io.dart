import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_config.dart';
import '../models/watch_spec.dart';
import '../models/watch_window.dart';

/// Top-level config bundle: everything the user has set up.
class AppConfig {
  final List<DeviceConfig> devices;
  final List<WatchSpec> watches;
  final List<WatchWindow> savedLayouts;

  const AppConfig({
    required this.devices,
    required this.watches,
    required this.savedLayouts,
  });

  Map<String, dynamic> toJson() => {
        'version': 1,
        'devices': devices.map((d) => d.toJson()).toList(),
        'watches': watches.map((w) => w.toJson()).toList(),
        'savedLayouts': savedLayouts.map((w) => w.toJson()).toList(),
      };

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      devices: (json['devices'] as List? ?? [])
          .map((e) => DeviceConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      watches: (json['watches'] as List? ?? [])
          .map((e) => WatchSpec.fromJson(e as Map<String, dynamic>))
          .toList(),
      savedLayouts: (json['savedLayouts'] as List? ?? [])
          .map((e) => WatchWindow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static const empty = AppConfig(devices: [], watches: [], savedLayouts: []);
}

/// Persistence: a plain pretty-printed JSON file in the OS-standard
/// "application support" directory. The file is human-readable so users
/// can copy it between machines, version-control it, or hand-edit when
/// debugging.
///
/// Resolved location per OS (bundle id = `com.ka1hung.modbeak`, app is
/// distributed unsandboxed on macOS — see `macos/Runner/*.entitlements`):
/// - macOS: `~/Library/Application Support/com.ka1hung.modbeak/config.json`
/// - Windows: `%APPDATA%\com.ka1hung\modbeak\config.json`
///            (i.e. `C:\Users\<you>\AppData\Roaming\com.ka1hung\modbeak\config.json`)
/// - Linux: `~/.local/share/modbeak/config.json` (honours `$XDG_DATA_HOME`)
/// - iOS / Android: app-private sandbox (not user-visible).
class ConfigStore {
  /// Legacy SharedPreferences key — kept only so we can migrate any
  /// pre-existing config the first time the new JSON path is empty.
  static const _legacyPrefsKey = 'mbt_app_config_v1';
  static const _fileName = 'config.json';
  static const _encoder = JsonEncoder.withIndent('  ');

  /// Returns the absolute path that [load] / [save] read and write.
  /// Useful to surface in the UI ("Settings stored at: …").
  static Future<String> resolvedPath() async {
    final f = await _file();
    return f.path;
  }

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<AppConfig> load() async {
    final f = await _file();
    if (await f.exists()) {
      try {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return AppConfig.fromJson(m);
      } catch (_) {
        return AppConfig.empty;
      }
    }
    // No JSON file yet — try to migrate any config that an earlier build
    // wrote into SharedPreferences. After migration the JSON file becomes
    // the source of truth; the legacy entry is left in place untouched
    // so a downgraded build still has its data.
    final migrated = await _loadFromLegacyPrefs();
    if (migrated != null) {
      await save(migrated);
      return migrated;
    }
    return AppConfig.empty;
  }

  static Future<void> save(AppConfig cfg) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(_encoder.convert(cfg.toJson()), flush: true);
  }

  static Future<void> exportToFile(AppConfig cfg, String path) async {
    final f = File(path);
    await f.writeAsString(_encoder.convert(cfg.toJson()));
  }

  static Future<AppConfig> importFromFile(String path) async {
    final raw = await File(path).readAsString();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return AppConfig.fromJson(m);
  }

  static Future<AppConfig?> _loadFromLegacyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AppConfig.fromJson(m);
    } catch (_) {
      return null;
    }
  }
}
