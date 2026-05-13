import 'dart:async';

import '../../data/models/device_config.dart';
import '../../data/models/watch_spec.dart';
import '../modbus/mb_client.dart';
import '../modbus/raw_packet.dart';
import 'poll_loop.dart';
import 'poll_result.dart';

/// Per-device connection state.
enum DeviceConnState { disconnected, connecting, connected, error }

class DeviceState {
  final DeviceConfig config;
  DeviceConnState conn = DeviceConnState.disconnected;
  String? lastError;

  DeviceState(this.config);
}

/// Owns all live [MbClient]s and per-device [DevicePollLoop]s.
///
/// Multiple panes that target the same device share one [MbClient] — that's
/// the whole point of routing concurrent requests through transaction IDs
/// (TCP) or a half-duplex mutex (RTU). Polling is now device-wide: one loop
/// per device sweeps all of its watches in sequence, respecting the
/// device's `pollIntervalMs` and the client's `minRequestGapMs`.
class DeviceHub {
  final Map<String, _DeviceEntry> _devices = {};
  final Map<String, DevicePollLoop> _polls = {};

  final StreamController<RawPacket> _allRawCtrl =
      StreamController<RawPacket>.broadcast();

  /// Combined raw packet stream from every device (each event tagged with
  /// the source [DeviceConfig.id] via [TaggedRawPacket]).
  Stream<TaggedRawPacket> get rawPackets$ => _allRawCtrl.stream
      .map((p) => p as TaggedRawPacket);

  /// All devices currently registered.
  Iterable<DeviceState> get devices => _devices.values.map((e) => e.state);

  DeviceState? device(String id) => _devices[id]?.state;

  // ─── Device lifecycle ───────────────────────────────────────────────────

  void addDevice(DeviceConfig config) {
    if (_devices.containsKey(config.id)) return;
    _devices[config.id] = _DeviceEntry(DeviceState(config));
  }

  /// Replace a device's config. The new config may have a different
  /// transport, so we drop the old client + connection state entirely —
  /// the user must reconnect with the new settings.
  Future<void> updateDevice(DeviceConfig config) async {
    final entry = _devices[config.id];
    if (entry == null) {
      addDevice(config);
      return;
    }
    _polls.remove(config.id)?.stop();
    await entry.client?.dispose();
    entry.client = null;
    entry.state = DeviceState(config); // fresh: conn=disconnected, lastError=null
  }

  Future<void> removeDevice(String id) async {
    final entry = _devices.remove(id);
    if (entry == null) return;
    _polls.remove(id)?.stop();
    await entry.client?.dispose();
  }

  Future<void> connect(String deviceId) async {
    final entry = _devices[deviceId];
    if (entry == null) {
      throw StateError('unknown device $deviceId');
    }
    if (entry.client != null && entry.client!.isConnected) return;

    entry.state.conn = DeviceConnState.connecting;
    entry.state.lastError = null;

    final cfg = entry.state.config;
    final c = switch (cfg.transport) {
      ModbusTransport.tcp => MbClient.tcp(
          host: cfg.host,
          port: cfg.port,
          timeout: Duration(milliseconds: cfg.timeoutMs),
          serializeRequests: cfg.serializeRequests,
          minRequestGapMs: cfg.minRequestGapMs,
        ),
      ModbusTransport.rtu => MbClient.rtu(
          serialPortName: cfg.serialPort,
          baudRate: cfg.baudRate,
          dataBits: cfg.dataBits,
          stopBits: cfg.stopBits,
          parity: cfg.parity,
          timeout: Duration(milliseconds: cfg.timeoutMs),
          minRequestGapMs: cfg.minRequestGapMs,
        ),
    };
    // Tag each raw packet with the device id and forward to the global stream.
    c.rawPackets$.listen(
      (p) => _allRawCtrl.add(TaggedRawPacket(deviceId: deviceId, packet: p)),
    );

    try {
      await c.open();
      entry.client = c;
      entry.state.conn = DeviceConnState.connected;
    } catch (e) {
      await c.dispose();
      entry.state.conn = DeviceConnState.error;
      entry.state.lastError = e.toString();
      rethrow;
    }
  }

  Future<void> disconnect(String deviceId) async {
    final entry = _devices[deviceId];
    if (entry == null) return;

    // Stop the device's polling loop (if any).
    _polls.remove(deviceId)?.stop();

    await entry.client?.close();
    entry.client = null;
    entry.state.conn = DeviceConnState.disconnected;
    entry.state.lastError = null;
  }

  // ─── Polling ────────────────────────────────────────────────────────────

  /// Start (or recycle) the device's polling loop. The loop reads its
  /// current watch list + interval fresh on every cycle via the supplied
  /// callbacks, so add/remove/edit of watches takes effect on the next
  /// sweep with no restart needed.
  ///
  /// Idempotent — calling again while a loop is already running is a no-op.
  /// Returns null if the device isn't connected (caller should retry after
  /// `connect()` succeeds).
  DevicePollLoop? startDevicePolling(
    String deviceId, {
    required List<WatchSpec> Function() watchesProvider,
    required int Function() pollIntervalMsProvider,
    required void Function(WatchSpec, PollResult) onResult,
  }) {
    final entry = _devices[deviceId];
    if (entry == null) {
      throw StateError('unknown device $deviceId');
    }
    final client = entry.client;
    if (client == null) return null;

    final existing = _polls[deviceId];
    if (existing != null && existing.isRunning) return existing;

    final loop = DevicePollLoop(
      deviceId: deviceId,
      client: client,
      watchesProvider: watchesProvider,
      pollIntervalMsProvider: pollIntervalMsProvider,
      onResult: onResult,
    );
    _polls[deviceId] = loop;
    loop.start();
    return loop;
  }

  void stopDevicePolling(String deviceId) {
    _polls.remove(deviceId)?.stop();
  }

  DevicePollLoop? devicePoll(String deviceId) => _polls[deviceId];

  /// One-shot read for [spec]. Used by manual refresh and the write-back
  /// read after a successful coil/register write. Requires the device to
  /// have an active poll loop (so the result feeds back through the same
  /// onResult sink). If the loop isn't running, falls back to a direct read.
  Future<PollResult?> refreshWatch(WatchSpec spec) async {
    final loop = _polls[spec.deviceId];
    if (loop != null) return loop.fetchOnce(spec);
    return null;
  }

  /// Zero out poll counters for every watch on this device.
  void resetStatsForDevice(String deviceId) {
    _polls[deviceId]?.resetAllStats();
  }

  // ─── Direct write (used by in-cell editor) ──────────────────────────────

  /// [address] is the 1-based UI address (ModScan convention). The wire
  /// address is `address - 1`.
  Future<void> writeRegisters(
    String deviceId,
    int unitId,
    int address,
    List<int> values,
  ) async {
    final c = _requireClient(deviceId);
    final wire = address - 1;
    if (values.length == 1) {
      await c.writeReg(unitId, wire, values[0]);
    } else {
      await c.writeRegs(unitId, wire, values);
    }
  }

  /// [address] is the 1-based UI address (ModScan convention).
  Future<void> writeCoil(
    String deviceId,
    int unitId,
    int address,
    bool value,
  ) async {
    final c = _requireClient(deviceId);
    await c.writeCoil(unitId, address - 1, value);
  }

  MbClient _requireClient(String deviceId) {
    final c = _devices[deviceId]?.client;
    if (c == null) {
      throw StateError('device $deviceId not connected');
    }
    return c;
  }

  // ─── Disposal ───────────────────────────────────────────────────────────

  Future<void> dispose() async {
    for (final loop in _polls.values) {
      loop.stop();
    }
    _polls.clear();
    for (final entry in _devices.values) {
      await entry.client?.dispose();
    }
    _devices.clear();
    await _allRawCtrl.close();
  }
}

class _DeviceEntry {
  DeviceState state;
  MbClient? client;
  _DeviceEntry(this.state);
}

class TaggedRawPacket extends RawPacket {
  final String deviceId;
  TaggedRawPacket({required this.deviceId, required RawPacket packet})
      : super(
          time: packet.time,
          isTx: packet.isTx,
          bytes: packet.bytes,
          transport: packet.transport,
          transactionId: packet.transactionId,
        );
}
