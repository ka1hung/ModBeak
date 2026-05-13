/// Result of one poll cycle. The pane stores the most recent one and
/// re-renders when [PollResult] arrives — switching format never requires
/// a new poll, since we keep raw register values here.
sealed class PollResult {
  final DateTime time;
  final Duration latency;

  const PollResult(this.time, this.latency);
}

class PollOk extends PollResult {
  /// Raw 16-bit register values, or 0/1 ints for coil reads.
  final List<int> values;

  /// True when [values] are bits (coil / discrete input read).
  final bool isBitRead;

  const PollOk({
    required DateTime time,
    required Duration latency,
    required this.values,
    required this.isBitRead,
  }) : super(time, latency);
}

class PollErr extends PollResult {
  final Object error;

  const PollErr({
    required DateTime time,
    required Duration latency,
    required this.error,
  }) : super(time, latency);
}

/// Rolling counters for a single watch / device.
class PollStats {
  int success = 0;
  int errors = 0;
  Duration totalLatency = Duration.zero;
  Duration minLatency = Duration.zero;
  Duration maxLatency = Duration.zero;

  void record(PollResult r) {
    if (r is PollOk) {
      success++;
    } else {
      errors++;
    }
    totalLatency += r.latency;
    if (success + errors == 1) {
      minLatency = r.latency;
      maxLatency = r.latency;
    } else {
      if (r.latency < minLatency) minLatency = r.latency;
      if (r.latency > maxLatency) maxLatency = r.latency;
    }
  }

  Duration get avgLatency {
    final n = success + errors;
    if (n == 0) return Duration.zero;
    return Duration(microseconds: totalLatency.inMicroseconds ~/ n);
  }

  double get successRate {
    final n = success + errors;
    return n == 0 ? 1.0 : success / n;
  }

  void reset() {
    success = 0;
    errors = 0;
    totalLatency = Duration.zero;
    minLatency = Duration.zero;
    maxLatency = Duration.zero;
  }
}
