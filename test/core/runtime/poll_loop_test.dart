import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/modbus/mb_client.dart';
import 'package:modbeak/core/runtime/poll_loop.dart';
import 'package:modbeak/core/runtime/poll_result.dart';
import 'package:modbeak/data/models/watch_spec.dart';

import '../modbus/fake_modbus_server.dart';

void main() {
  group('DevicePollLoop', () {
    test(
        'cycles through every non-manual watch in sequence, respects interval',
        () async {
      final server = await FakeModbusServer.start();
      final client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(milliseconds: 500),
      );
      await client.open();

      // 3 watches × several cycles of canned responses.
      for (var i = 0; i < 30; i++) {
        server.enqueueResponse(Uint8List.fromList(
            [0x01, 0x03, 0x02, (i >> 8) & 0xFF, i & 0xFF]));
      }

      final w1 = WatchSpec(
        id: 'w1',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 1,
        quantity: 1,
      );
      final w2 = WatchSpec(
        id: 'w2',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 10,
        quantity: 1,
      );
      final w3 = WatchSpec(
        id: 'w3',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 20,
        quantity: 1,
        manualOnly: true, // should be skipped by the cycle
      );

      final hits = <String>[];
      final loop = DevicePollLoop(
        deviceId: 'd1',
        client: client,
        watchesProvider: () => [w1, w2, w3],
        pollIntervalMsProvider: () => 100,
        onResult: (spec, _) => hits.add(spec.id),
      );
      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      loop.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // At least 2 full cycles of 2 non-manual watches each → ≥ 4 hits,
      // and w3 must never appear.
      expect(hits.length, greaterThanOrEqualTo(4));
      expect(hits.contains('w3'), isFalse);
      // Order within a cycle must be w1 → w2 (loop iterates in order).
      for (var i = 0; i + 1 < hits.length; i += 2) {
        expect(hits[i], 'w1');
        expect(hits[i + 1], 'w2');
      }

      await client.dispose();
      await server.close();
    });

    test('per-watch stats record success and error separately', () async {
      final server = await FakeModbusServer.start();
      final client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(milliseconds: 500),
      );
      await client.open();

      server.enqueueResponse(Uint8List.fromList([0x01, 0x03, 0x02, 0, 0]));
      server.enqueueResponse(Uint8List.fromList([0x01, 0x83, 0x02])); // err
      server.enqueueResponse(Uint8List.fromList([0x01, 0x03, 0x02, 0, 0]));

      final spec = WatchSpec(
        id: 'w2',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 1,
        quantity: 1,
        manualOnly: true,
      );

      final loop = DevicePollLoop(
        deviceId: 'd1',
        client: client,
        watchesProvider: () => [spec],
        pollIntervalMsProvider: () => 1000,
        onResult: (_, r) {},
      );
      // Use fetchOnce so we drive the count deterministically.
      await loop.fetchOnce(spec);
      await loop.fetchOnce(spec);
      await loop.fetchOnce(spec);

      final stats = loop.statsFor('w2');
      expect(stats.success, 2);
      expect(stats.errors, 1);
      expect(stats.successRate, closeTo(2 / 3, 0.001));

      await client.dispose();
      await server.close();
    });

    test('one failing watch does not break the cycle for the rest', () async {
      final server = await FakeModbusServer.start();
      final client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(milliseconds: 300),
      );
      await client.open();

      // Cycle 1: w1 fails (exception), w2 succeeds.
      // Cycle 2: w1 succeeds, w2 succeeds.
      server.enqueueResponse(Uint8List.fromList([0x01, 0x83, 0x02]));
      server.enqueueResponse(Uint8List.fromList([0x01, 0x03, 0x02, 0, 0x10]));
      server.enqueueResponse(Uint8List.fromList([0x01, 0x03, 0x02, 0, 0x01]));
      server.enqueueResponse(Uint8List.fromList([0x01, 0x03, 0x02, 0, 0x11]));

      final w1 = WatchSpec(
        id: 'w1',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 1,
        quantity: 1,
      );
      final w2 = WatchSpec(
        id: 'w2',
        deviceId: 'd1',
        unitId: 1,
        functionCode: 3,
        startAddress: 10,
        quantity: 1,
      );

      final byId = <String, List<PollResult>>{};
      final loop = DevicePollLoop(
        deviceId: 'd1',
        client: client,
        watchesProvider: () => [w1, w2],
        pollIntervalMsProvider: () => 50,
        onResult: (spec, r) =>
            (byId[spec.id] ??= <PollResult>[]).add(r),
      );
      loop.start();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      loop.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // w2 must have at least one PollOk even though w1 errored mid-cycle.
      expect(byId['w2']?.whereType<PollOk>().isNotEmpty, isTrue);

      await client.dispose();
      await server.close();
    });
  });
}
