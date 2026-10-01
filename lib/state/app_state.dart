import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/runtime/device_hub.dart';
import '../core/runtime/poll_result.dart';
import '../data/models/device_config.dart';
import '../data/models/pane_layout.dart';
import '../data/models/watch_spec.dart';
import '../data/models/watch_window.dart';
import '../data/persistence/config_io.dart';

/// One [DeviceHub] for the whole app.
final deviceHubProvider = Provider<DeviceHub>((ref) {
  final hub = DeviceHub();
  ref.onDispose(hub.dispose);
  return hub;
});

// ─── Devices ────────────────────────────────────────────────────────────────

class DeviceListNotifier extends Notifier<List<DeviceConfig>> {
  @override
  List<DeviceConfig> build() => const [];

  void add(DeviceConfig cfg) {
    ref.read(deviceHubProvider).addDevice(cfg);
    state = [...state, cfg];
  }

  Future<void> update(DeviceConfig cfg) async {
    await ref.read(deviceHubProvider).updateDevice(cfg);
    // Old client + connection were dropped; reset the user-visible conn
    // state too so a stale "error" or "connected" indicator doesn't linger.
    ref.read(deviceConnProvider.notifier).markDisconnected(cfg.id);
    state = [for (final d in state) d.id == cfg.id ? cfg : d];
  }

  Future<void> remove(String id) async {
    await ref.read(deviceHubProvider).removeDevice(id);
    ref.read(watchListProvider.notifier).removeByDevice(id);
    ref.read(liveWatchProvider.notifier).dropByDevice(id);
    state = state.where((d) => d.id != id).toList();
  }

  void replaceAll(List<DeviceConfig> all) {
    final hub = ref.read(deviceHubProvider);
    for (final d in all) {
      hub.addDevice(d);
    }
    state = List.of(all);
  }
}

final deviceListProvider =
    NotifierProvider<DeviceListNotifier, List<DeviceConfig>>(
        DeviceListNotifier.new);

class DeviceConnNotifier extends Notifier<Map<String, DeviceConnState>> {
  /// Per-device token. Bumping it cancels any in-flight auto-reconnect
  /// loop for that device (manual connect / disconnect supersede it).
  final Map<String, int> _reconnectGen = {};

  @override
  Map<String, DeviceConnState> build() {
    final sub = ref
        .read(deviceHubProvider)
        .connectionLost$
        .listen(_onConnectionLost);
    ref.onDispose(sub.cancel);
    return const {};
  }

  /// The hub already stopped polling and dropped the dead client — here we
  /// sync the UI state, log ONE entry, and honour the device's
  /// autoReconnect flag.
  void _onConnectionLost(String id) {
    _bumpGen(id);
    state = {...state, id: DeviceConnState.error};
    ref.read(errorLogProvider.notifier).add(ErrorLogEntry(
          deviceId: id,
          time: DateTime.now(),
          message:
              'Connection lost — closed by remote or network failure',
          source: ErrorSource.connect,
        ));
    DeviceConfig? cfg;
    for (final d in ref.read(deviceListProvider)) {
      if (d.id == id) {
        cfg = d;
        break;
      }
    }
    if (cfg != null && cfg.autoReconnect) {
      unawaited(_reconnectLoop(id));
    }
  }

  int _bumpGen(String id) =>
      _reconnectGen[id] = (_reconnectGen[id] ?? 0) + 1;

  /// Retry every 3 s until connected, superseded by a manual action, or the
  /// device is removed. Failed attempts are silent — the single
  /// "Connection lost" entry above already tells the story; one line per
  /// retry would recreate the flood this fix removes.
  Future<void> _reconnectLoop(String id) async {
    final gen = _reconnectGen[id];
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (_reconnectGen[id] != gen) return;
      if (!ref.read(deviceListProvider).any((d) => d.id == id)) return;
      if (state[id] == DeviceConnState.connected) return;
      try {
        await ref.read(deviceHubProvider).connect(id);
        if (_reconnectGen[id] != gen) {
          // A manual action raced us mid-connect; let it win.
          await ref.read(deviceHubProvider).disconnect(id);
          return;
        }
        state = {...state, id: DeviceConnState.connected};
        return;
      } catch (_) {
        // Still down — next round.
      }
    }
  }

  Future<void> connect(String id) async {
    _bumpGen(id);
    state = {...state, id: DeviceConnState.connecting};
    try {
      await ref.read(deviceHubProvider).connect(id);
      state = {...state, id: DeviceConnState.connected};
    } catch (e) {
      state = {...state, id: DeviceConnState.error};
      ref.read(errorLogProvider.notifier).add(ErrorLogEntry(
            deviceId: id,
            time: DateTime.now(),
            message: e.toString(),
            source: ErrorSource.connect,
          ));
    }
  }

  Future<void> disconnect(String id) async {
    _bumpGen(id);
    await ref.read(deviceHubProvider).disconnect(id);
    state = {...state, id: DeviceConnState.disconnected};
  }

  /// Force-reset the user-visible conn state to disconnected without
  /// touching the hub. Used when a config update has already torn down the
  /// underlying client, so the UI shouldn't keep showing the prior state.
  void markDisconnected(String id) {
    state = {...state, id: DeviceConnState.disconnected};
  }
}

final deviceConnProvider =
    NotifierProvider<DeviceConnNotifier, Map<String, DeviceConnState>>(
        DeviceConnNotifier.new);

final connStateProvider = Provider.family<DeviceConnState, String>((ref, id) {
  return ref.watch(deviceConnProvider)[id] ?? DeviceConnState.disconnected;
});

// ─── Watches (specs) ────────────────────────────────────────────────────────

class WatchListNotifier extends Notifier<List<WatchSpec>> {
  @override
  List<WatchSpec> build() => const [];

  void add(WatchSpec spec) {
    state = [...state, spec];
  }

  void update(WatchSpec spec) {
    state = [for (final w in state) w.id == spec.id ? spec : w];
    // No loop restart needed: the device loop reads its watch list fresh
    // on every cycle, so the new addr / qty / FC takes effect within one
    // polling interval.
  }

  void remove(String id) {
    ref.read(liveWatchProvider.notifier).drop(id);
    state = state.where((w) => w.id != id).toList();
  }

  void removeByDevice(String deviceId) {
    // No loop teardown needed — DeviceHub.removeDevice / disconnect handle
    // the device-level loop. Simply forget the watches.
    state = state.where((w) => w.deviceId != deviceId).toList();
  }

  void replaceAll(List<WatchSpec> all) {
    state = List.of(all);
  }
}

final watchListProvider =
    NotifierProvider<WatchListNotifier, List<WatchSpec>>(
        WatchListNotifier.new);

// ─── Live watch data ────────────────────────────────────────────────────────

/// Central map of latest poll results keyed by watch id. Family providers
/// below expose per-watch slices.
///
/// The runtime model is one polling loop per device (see [DevicePollLoop]):
/// every watch on the device is queried in sequence, then the cycle waits
/// `pollIntervalMs - elapsed`. So adding / editing / removing a watch
/// doesn't restart the loop — the loop reads its watch list fresh every
/// cycle via the [DeviceHub] callback.
class LiveWatchNotifier extends Notifier<Map<String, PollResult?>> {
  @override
  Map<String, PollResult?> build() => const {};

  /// Ensure the polling loop is running for [deviceId]. No-op if already
  /// running, the device is unknown, or the device isn't connected — in
  /// the disconnected case the caller should retry once the device comes
  /// online (the watch pane does this via `ref.listen` on conn state).
  void ensureDevicePolling(String deviceId) {
    final hub = ref.read(deviceHubProvider);
    final dev = hub.device(deviceId);
    if (dev == null || dev.conn != DeviceConnState.connected) return;
    hub.startDevicePolling(
      deviceId,
      watchesProvider: () => ref
          .read(watchListProvider)
          .where((w) => w.deviceId == deviceId)
          .toList(growable: false),
      pollIntervalMsProvider: () =>
          ref.read(deviceHubProvider).device(deviceId)?.config.pollIntervalMs ??
          1000,
      onResult: _onResult,
    );
  }

  /// One-shot read (manual refresh / write-back). Routes through the
  /// device's existing loop so the result feeds back through the same sink.
  /// If polling isn't running yet, kicks it on first.
  Future<void> refreshOnce(WatchSpec spec) async {
    final hub = ref.read(deviceHubProvider);
    if (hub.devicePoll(spec.deviceId) == null) {
      ensureDevicePolling(spec.deviceId);
    }
    await hub.refreshWatch(spec);
  }

  void _onResult(WatchSpec spec, PollResult r) {
    state = {...state, spec.id: r};
    if (r is PollErr) {
      ref.read(errorLogProvider.notifier).add(ErrorLogEntry(
            deviceId: spec.deviceId,
            watchId: spec.id,
            watchLabel: _watchLabel(spec),
            time: r.time,
            message: r.error.toString(),
            source: ErrorSource.poll,
          ));
    }
  }

  /// Drop a single watch's last result (used after the watch is deleted).
  /// The loop will simply skip the missing watch on its next cycle.
  void drop(String watchId) {
    final next = Map<String, PollResult?>.from(state);
    next.remove(watchId);
    state = next;
  }

  void dropByDevice(String deviceId) {
    final keep = <String, PollResult?>{};
    final watches = ref.read(watchListProvider);
    for (final w in watches) {
      if (w.deviceId == deviceId) continue;
      if (state.containsKey(w.id)) keep[w.id] = state[w.id];
    }
    state = keep;
  }
}

final liveWatchProvider =
    NotifierProvider<LiveWatchNotifier, Map<String, PollResult?>>(
        LiveWatchNotifier.new);

/// Per-pane subscription — only this slice rebuilds on each tick.
final watchResultProvider = Provider.family<PollResult?, String>((ref, id) {
  return ref.watch(liveWatchProvider)[id];
});

/// Bumped whenever poll counters are reset so footers / stats UI rebuild
/// immediately without waiting for the next poll cycle.
class StatsTickNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state = state + 1;
}

final statsTickProvider =
    NotifierProvider<StatsTickNotifier, int>(StatsTickNotifier.new);

// ─── Watch Windows (containers + layouts) ───────────────────────────────────

class WatchWindowNotifier extends Notifier<List<WatchWindow>> {
  @override
  List<WatchWindow> build() => const [];

  void add(WatchWindow w) => state = [...state, w];
  void update(WatchWindow w) =>
      state = [for (final x in state) x.id == w.id ? w : x];
  void remove(String id) => state = state.where((w) => w.id != id).toList();
  void replaceAll(List<WatchWindow> all) => state = List.of(all);

  /// Walks the layout tree and returns every [WatchSpec] contained in [w].
  static List<WatchSpec> watchesIn(WatchWindow w) {
    final out = <WatchSpec>[];
    void walk(PaneLayout n) {
      switch (n) {
        case LeafPane(:final watch):
          out.add(watch);
        case SplitPane(:final children):
          for (final c in children) {
            walk(c);
          }
      }
    }

    walk(w.layout);
    return out;
  }
}

final watchWindowProvider =
    NotifierProvider<WatchWindowNotifier, List<WatchWindow>>(
        WatchWindowNotifier.new);

// ─── Raw packet log (M7) ────────────────────────────────────────────────────

const _rawLogCap = 2000;

class RawLogNotifier extends Notifier<List<TaggedRawPacket>> {
  StreamSubscription<TaggedRawPacket>? _sub;

  @override
  List<TaggedRawPacket> build() {
    final hub = ref.read(deviceHubProvider);
    _sub = hub.rawPackets$.listen((p) {
      final next = [...state, p];
      if (next.length > _rawLogCap) {
        next.removeRange(0, next.length - _rawLogCap);
      }
      state = next;
    });
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const [];
  }

  void clear() => state = const [];
}

final rawLogProvider =
    NotifierProvider<RawLogNotifier, List<TaggedRawPacket>>(
        RawLogNotifier.new);

// ─── Error log ─────────────────────────────────────────────────────────────

enum ErrorSource { connect, poll }

class ErrorLogEntry {
  final String deviceId;
  final String? watchId;
  final String? watchLabel;
  final DateTime time;
  final String message;
  final ErrorSource source;

  const ErrorLogEntry({
    required this.deviceId,
    this.watchId,
    this.watchLabel,
    required this.time,
    required this.message,
    required this.source,
  });
}

const _errorLogCap = 500;

class ErrorLogNotifier extends Notifier<List<ErrorLogEntry>> {
  @override
  List<ErrorLogEntry> build() => const [];

  void add(ErrorLogEntry e) {
    final next = [...state, e];
    if (next.length > _errorLogCap) {
      next.removeRange(0, next.length - _errorLogCap);
    }
    state = next;
  }

  void clear() => state = const [];

  void clearDevice(String deviceId) {
    state = state.where((e) => e.deviceId != deviceId).toList();
  }
}

final errorLogProvider =
    NotifierProvider<ErrorLogNotifier, List<ErrorLogEntry>>(
        ErrorLogNotifier.new);

String _watchLabel(WatchSpec spec) {
  final fc = switch (spec.functionCode) {
    1 => 'FC01',
    2 => 'FC02',
    3 => 'FC03',
    4 => 'FC04',
    _ => 'FC${spec.functionCode}',
  };
  return '$fc ${spec.startAddress}–${spec.startAddress + spec.quantity - 1}';
}

// ─── UI helpers ─────────────────────────────────────────────────────────────

class DeviceDetail {
  final DeviceConfig config;
  final DeviceConnState conn;
  final List<WatchSpec> watches;

  DeviceDetail({
    required this.config,
    required this.conn,
    required this.watches,
  });
}

const _missing = DeviceConfig(id: '__missing__', name: '');

final deviceDetailProvider = Provider.family<DeviceDetail?, String>((ref, id) {
  final cfg = ref.watch(deviceListProvider).firstWhere(
        (d) => d.id == id,
        orElse: () => _missing,
      );
  if (identical(cfg, _missing)) return null;
  final conn =
      ref.watch(deviceConnProvider)[id] ?? DeviceConnState.disconnected;
  final watches =
      ref.watch(watchListProvider).where((w) => w.deviceId == id).toList();
  return DeviceDetail(config: cfg, conn: conn, watches: watches);
});

@visibleForTesting
DeviceConfig get debugMissingDevice => _missing;

// ─── Persistence ────────────────────────────────────────────────────────────

/// Snapshot of all persisted state into a single [AppConfig].
AppConfig snapshotConfig(Ref ref) {
  return AppConfig(
    devices: ref.read(deviceListProvider),
    watches: ref.read(watchListProvider),
    savedLayouts: ref.read(watchWindowProvider),
  );
}

/// Replace all in-memory state from a config bundle.
Future<void> applyConfig(WidgetRef ref, AppConfig cfg) async {
  ref.read(deviceListProvider.notifier).replaceAll(cfg.devices);
  ref.read(watchListProvider.notifier).replaceAll(cfg.watches);
  ref.read(watchWindowProvider.notifier).replaceAll(cfg.savedLayouts);
}

// ─── MDI workspace layout (session-only) ───────────────────────────────────

/// Position + size for a single MDI sub-window. Keyed by watchId.
class MdiRect {
  final double x, y, w, h;
  const MdiRect(this.x, this.y, this.w, this.h);
  MdiRect copyWith({double? x, double? y, double? w, double? h}) =>
      MdiRect(x ?? this.x, y ?? this.y, w ?? this.w, h ?? this.h);
}

enum MdiWindowMode { normal, minimized, maximized, hidden }

/// Per-window MDI state: current rect, mode, and the rect to restore to
/// when un-minimizing / un-maximizing.
class MdiWindowSlot {
  final MdiRect rect;
  final MdiWindowMode mode;
  final MdiRect? savedNormal;

  const MdiWindowSlot({
    required this.rect,
    this.mode = MdiWindowMode.normal,
    this.savedNormal,
  });

  MdiWindowSlot copyWith({
    MdiRect? rect,
    MdiWindowMode? mode,
    MdiRect? savedNormal,
    bool clearSaved = false,
  }) =>
      MdiWindowSlot(
        rect: rect ?? this.rect,
        mode: mode ?? this.mode,
        savedNormal: clearSaved ? null : (savedNormal ?? this.savedNormal),
      );
}

/// State of each watch's MDI sub-window. Session-only — not persisted to
/// disk so that closing/reopening the app gives a fresh cascade layout
/// (and avoids leaking obsolete watch ids).
class MdiLayoutNotifier extends Notifier<Map<String, MdiWindowSlot>> {
  @override
  Map<String, MdiWindowSlot> build() => const {};

  void replace(Map<String, MdiWindowSlot> next) => state = next;

  void setRect(String id, MdiRect r) {
    final m = Map<String, MdiWindowSlot>.from(state);
    final cur = m[id];
    m[id] = cur == null ? MdiWindowSlot(rect: r) : cur.copyWith(rect: r);
    state = m;
  }

  void maximize(String id, MdiRect fullRect) {
    final m = Map<String, MdiWindowSlot>.from(state);
    final cur = m[id];
    if (cur == null) return;
    m[id] = cur.copyWith(
      rect: fullRect,
      mode: MdiWindowMode.maximized,
      // Only save normal rect once; second maximize call keeps the original.
      savedNormal: cur.mode == MdiWindowMode.normal ? cur.rect : cur.savedNormal,
    );
    state = m;
  }

  void minimize(String id) {
    final m = Map<String, MdiWindowSlot>.from(state);
    final cur = m[id];
    if (cur == null) return;
    m[id] = cur.copyWith(
      mode: MdiWindowMode.minimized,
      savedNormal: cur.mode == MdiWindowMode.normal ? cur.rect : cur.savedNormal,
    );
    state = m;
  }

  void hide(String id) {
    final m = Map<String, MdiWindowSlot>.from(state);
    final cur = m[id];
    if (cur == null) return;
    m[id] = cur.copyWith(
      mode: MdiWindowMode.hidden,
      savedNormal: cur.mode == MdiWindowMode.normal ? cur.rect : cur.savedNormal,
    );
    state = m;
  }

  /// Restore to normal mode using `savedNormal` if available.
  void restore(String id) {
    final m = Map<String, MdiWindowSlot>.from(state);
    final cur = m[id];
    if (cur == null) return;
    m[id] = MdiWindowSlot(
      rect: cur.savedNormal ?? cur.rect,
      mode: MdiWindowMode.normal,
    );
    state = m;
  }

  /// Bulk: set all visible windows to [rects], mode normal, no saved.
  void applyLayout(Map<String, MdiRect> rects) {
    final m = Map<String, MdiWindowSlot>.from(state);
    for (final e in rects.entries) {
      m[e.key] = MdiWindowSlot(rect: e.value);
    }
    state = m;
  }
}

final mdiLayoutProvider =
    NotifierProvider<MdiLayoutNotifier, Map<String, MdiWindowSlot>>(
        MdiLayoutNotifier.new);

/// Stacking order. Last entry is the topmost window.
class MdiZOrderNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void replace(List<String> next) => state = next;

  void bringToFront(String id) {
    if (!state.contains(id) || state.last == id) return;
    state = [...state.where((x) => x != id), id];
  }
}

final mdiZOrderProvider =
    NotifierProvider<MdiZOrderNotifier, List<String>>(MdiZOrderNotifier.new);

// ─── Quick layout algorithms ────────────────────────────────────────────────

enum MdiLayoutMode { cascade, tileHorizontal, tileVertical, grid }

class MdiLayoutComputer {
  static Map<String, MdiRect> compute({
    required MdiLayoutMode mode,
    required List<String> ids,
    required Size bounds,
  }) {
    if (ids.isEmpty || bounds.width < 80 || bounds.height < 80) return const {};
    switch (mode) {
      case MdiLayoutMode.cascade:
        return _cascade(ids, bounds);
      case MdiLayoutMode.tileHorizontal:
        return _tileRows(ids, bounds);
      case MdiLayoutMode.tileVertical:
        return _tileCols(ids, bounds);
      case MdiLayoutMode.grid:
        return _grid(ids, bounds);
    }
  }

  static Map<String, MdiRect> _cascade(List<String> ids, Size b) {
    const step = 28.0;
    final w = (b.width * 0.6).clamp(280.0, b.width - 16);
    final h = (b.height * 0.65).clamp(180.0, b.height - 16);
    final result = <String, MdiRect>{};
    for (var i = 0; i < ids.length; i++) {
      final maxX = (b.width - w - 8).clamp(0.0, double.infinity);
      final maxY = (b.height - h - 8).clamp(0.0, double.infinity);
      final x = (16 + i * step) % (maxX > 0 ? maxX : 1);
      final y = (16 + i * step) % (maxY > 0 ? maxY : 1);
      result[ids[i]] = MdiRect(x, y, w, h);
    }
    return result;
  }

  static Map<String, MdiRect> _tileRows(List<String> ids, Size b) {
    final h = b.height / ids.length;
    final result = <String, MdiRect>{};
    for (var i = 0; i < ids.length; i++) {
      result[ids[i]] = MdiRect(0, i * h, b.width, h);
    }
    return result;
  }

  static Map<String, MdiRect> _tileCols(List<String> ids, Size b) {
    final w = b.width / ids.length;
    final result = <String, MdiRect>{};
    for (var i = 0; i < ids.length; i++) {
      result[ids[i]] = MdiRect(i * w, 0, w, b.height);
    }
    return result;
  }

  static Map<String, MdiRect> _grid(List<String> ids, Size b) {
    final cols = math.sqrt(ids.length).ceil();
    final rows = (ids.length / cols).ceil();
    final cellW = b.width / cols;
    final cellH = b.height / rows;
    final result = <String, MdiRect>{};
    for (var i = 0; i < ids.length; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      result[ids[i]] = MdiRect(c * cellW, r * cellH, cellW, cellH);
    }
    return result;
  }
}

/// Auto-save: subscribes to all config-changing providers and writes them to
/// SharedPreferences after every mutation. Mounted from MainWindow init.
final autoSaveProvider = Provider<void>((ref) {
  Timer? debounce;
  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      final snapshot = snapshotConfig(ref);
      ConfigStore.save(snapshot);
    });
  }

  ref.listen(deviceListProvider, (_, _) => schedule());
  ref.listen(watchListProvider, (_, _) => schedule());
  ref.listen(watchWindowProvider, (_, _) => schedule());
  ref.onDispose(() => debounce?.cancel());
});
