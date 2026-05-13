import 'dart:async';

import '../../data/models/watch_spec.dart';
import '../modbus/mb_client.dart';
import 'poll_result.dart';

/// One polling cycle per device. Each cycle iterates every non-manual watch
/// bound to the device in sequence and emits a [PollResult] per watch.
///
/// Why one loop per device rather than one per watch:
///   * Predictable cycle time — `pollIntervalMs` measures the whole sweep,
///     not each individual watch.
///   * Back-to-back queries within a cycle are already serialized by the
///     transport client (TCP `serializeRequests` mutex / RTU half-duplex
///     mutex) and spaced by `minRequestGapMs`, so there's no point spinning
///     N independent loops fighting for the same socket.
///   * Eliminates the per-watch restart dance when specs change — the loop
///     just reads the current watch list on each cycle.
class DevicePollLoop {
  final String deviceId;
  final MbClient client;

  /// Fetched fresh each cycle, so watch add / remove / spec edit takes
  /// effect on the next iteration without restarting the loop.
  final List<WatchSpec> Function() watchesProvider;

  /// Read fresh each cycle so a poll-interval edit applies on the next sweep.
  final int Function() pollIntervalMsProvider;

  final void Function(WatchSpec spec, PollResult result) onResult;

  bool _running = false;

  /// Per-watch stats — survives spec edits since we key by watch id.
  final Map<String, PollStats> _stats = {};

  DevicePollLoop({
    required this.deviceId,
    required this.client,
    required this.watchesProvider,
    required this.pollIntervalMsProvider,
    required this.onResult,
  });

  bool get isRunning => _running;

  PollStats statsFor(String watchId) =>
      _stats.putIfAbsent(watchId, PollStats.new);

  void resetAllStats() {
    for (final s in _stats.values) {
      s.reset();
    }
  }

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  void stop() {
    _running = false;
  }

  /// One-shot read for a single spec — used by manual refresh and the
  /// write-back read after a successful coil/register write. Bypasses the
  /// cycle but still goes through the client's mutex.
  Future<PollResult> fetchOnce(WatchSpec spec) async {
    final t0 = DateTime.now();
    try {
      final values = await _doRead(spec);
      final r = PollOk(
        time: DateTime.now(),
        latency: DateTime.now().difference(t0),
        values: values,
        isBitRead: spec.functionCode == 1 || spec.functionCode == 2,
      );
      statsFor(spec.id).record(r);
      onResult(spec, r);
      return r;
    } catch (e) {
      final r = PollErr(
        time: DateTime.now(),
        latency: DateTime.now().difference(t0),
        error: e,
      );
      statsFor(spec.id).record(r);
      onResult(spec, r);
      return r;
    }
  }

  Future<void> _loop() async {
    while (_running) {
      final cycleStart = DateTime.now();
      final watches = watchesProvider()
          .where((w) => !w.manualOnly)
          .toList(growable: false);

      for (final spec in watches) {
        if (!_running) break;
        // fetchOnce already routes through onResult + stats. A failure on
        // one watch doesn't break the cycle — the next watch still runs.
        await fetchOnce(spec);
      }

      if (!_running) break;

      final interval = pollIntervalMsProvider();
      final elapsed = DateTime.now().difference(cycleStart);
      final wait = Duration(milliseconds: interval) - elapsed;
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
      }
      // If the cycle blew the budget, fall straight into the next iteration.
    }
  }

  Future<List<int>> _doRead(WatchSpec spec) async {
    // [WatchSpec.startAddress] is 1-based (ModScan convention); the Modbus
    // wire address starts at 0.
    final wireAddr = spec.startAddress - 1;
    switch (spec.functionCode) {
      case 1:
        final bits = await client.readCoil(spec.unitId, wireAddr, spec.quantity);
        return bits.map((b) => b ? 1 : 0).toList();
      case 2:
        final bits =
            await client.readCoilIn(spec.unitId, wireAddr, spec.quantity);
        return bits.map((b) => b ? 1 : 0).toList();
      case 3:
        return client.readReg(spec.unitId, wireAddr, spec.quantity);
      case 4:
        return client.readRegIn(spec.unitId, wireAddr, spec.quantity);
      default:
        throw StateError('unsupported FC ${spec.functionCode}');
    }
  }
}
