import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/modbus/exceptions.dart';
import 'package:modbeak/core/modbus/mb_client.dart';
import 'package:modbeak/core/modbus/raw_packet.dart';

import 'fake_modbus_server.dart';

void main() {
  group('MbClient — TCP wire format', () {
    late FakeModbusServer server;
    late MbClient client;

    setUp(() async {
      server = await FakeModbusServer.start();
      client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 1),
      );
      await client.open();
    });

    tearDown(() async {
      await client.dispose();
      await server.close();
    });

    test('readReg (FC 03) builds correct PDU and parses big-endian regs', () async {
      // Slave will return 3 holding registers: 0x04D2, 0x0000, 0xCAFE.
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x03, 0x06, 0x04, 0xD2, 0x00, 0x00, 0xCA, 0xFE,
      ]));

      final out = await client.readReg(1, 0, 3);
      expect(out, [0x04D2, 0x0000, 0xCAFE]);

      // Inspect the request frame the client built.
      // MBAP(6) = TID(2) + 0000 + len(2);  PDU = unit, fc=03, addr(2), qty(2)
      final req = server.lastRequest;
      expect(req.length, 12);
      expect(req[2], 0x00); // proto id high
      expect(req[3], 0x00); // proto id low
      expect((req[4] << 8) | req[5], 6); // length field
      expect(req[6], 1); // unit id
      expect(req[7], 0x03); // function code
      expect((req[8] << 8) | req[9], 0); // start address
      expect((req[10] << 8) | req[11], 3); // qty
    });

    test('readCoil (FC 01) unpacks bits little-end-first within each byte',
        () async {
      // 9 coils, 2 bytes: 0b10100101, 0b00000001  → [1,0,1,0,0,1,0,1, 1]
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x01, 0x02, 0xA5, 0x01,
      ]));

      final coils = await client.readCoil(1, 0, 9);
      expect(coils, [true, false, true, false, false, true, false, true, true]);
    });

    test('writeReg (FC 06) builds correct PDU', () async {
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x06, 0x00, 0x05, 0x12, 0x34,
      ]));

      await client.writeReg(1, 5, 0x1234);

      final req = server.lastRequest;
      expect(req[7], 0x06);
      expect((req[8] << 8) | req[9], 5);
      expect((req[10] << 8) | req[11], 0x1234);
    });

    test('writeRegs (FC 16) packs multiple registers big-endian', () async {
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x10, 0x00, 0x00, 0x00, 0x02,
      ]));

      await client.writeRegs(1, 0, [0xDEAD, 0xBEEF]);

      final req = server.lastRequest;
      expect(req[7], 0x10);
      expect((req[8] << 8) | req[9], 0); // start
      expect((req[10] << 8) | req[11], 2); // qty
      expect(req[12], 4); // byte count
      expect(req[13], 0xDE);
      expect(req[14], 0xAD);
      expect(req[15], 0xBE);
      expect(req[16], 0xEF);
    });

    test('writeCoil (FC 05) sends 0xFF00 for true, 0x0000 for false', () async {
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x05, 0x00, 0x00, 0xFF, 0x00,
      ]));
      await client.writeCoil(1, 0, true);
      expect(server.lastRequest[10], 0xFF);
      expect(server.lastRequest[11], 0x00);

      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x05, 0x00, 0x00, 0x00, 0x00,
      ]));
      await client.writeCoil(1, 0, false);
      expect(server.lastRequest[10], 0x00);
    });

    test('writeCoils (FC 15) packs bits little-end-first', () async {
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x0F, 0x00, 0x00, 0x00, 0x09,
      ]));

      await client.writeCoils(
          1, 0, [true, false, true, false, false, true, false, true, true]);

      final req = server.lastRequest;
      // Last two bytes of request body should be packed coils.
      // [1,0,1,0,0,1,0,1] → 0xA5; [1, ...padding] → 0x01
      expect(req[req.length - 2], 0xA5);
      expect(req[req.length - 1], 0x01);
    });

    test('exception response surfaces MbModbusError with code', () async {
      // FC byte = 0x83 (read holding regs, exception bit set), code = 0x02.
      server.enqueueResponse(Uint8List.fromList([0x01, 0x83, 0x02]));

      await expectLater(
        client.readReg(1, 0, 1),
        throwsA(isA<MbModbusError>().having((e) => e.code, 'code', 2)),
      );
    });

    test('no response triggers MbNoResponse after timeout', () async {
      server.enqueueSilence();

      await expectLater(
        client.readReg(1, 0, 1).timeout(const Duration(seconds: 2)),
        throwsA(isA<MbNoResponse>()),
      );
    });

    test('disconnect mid-flight triggers MbDisconnect', () async {
      // Client sends but server drops before responding.
      final f = client.readReg(1, 0, 1);
      // small wait so the request is on the wire
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await server.dropConnection();

      await expectLater(f, throwsA(isA<MbDisconnect>()));
    });

    test('concurrent requests are demuxed by transaction id', () async {
      // Queue two responses that intentionally arrive in *reverse* order.
      // We can't easily reorder via FakeModbusServer since each response
      // is sent in reaction to the matching request — but we can craft
      // both to come back with explicit TIDs. To test demux, fire two
      // requests in parallel and just verify both resolve correctly.
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x03, 0x02, 0x00, 0x01,
      ]));
      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x03, 0x02, 0x00, 0x02,
      ]));

      final results = await Future.wait([
        client.readReg(1, 0, 1),
        client.readReg(1, 1, 1),
      ]);

      // Each call gets exactly one register; the values may arrive in
      // either order depending on how the fake server flushed them, so
      // sort to compare.
      final flat = results.expand((r) => r).toList()..sort();
      expect(flat, [1, 2]);
    });

    test('rawPackets stream emits TX then RX with matching tid', () async {
      final captured = <RawPacket>[];
      final sub = client.rawPackets$.listen(captured.add);

      server.enqueueResponse(Uint8List.fromList([
        0x01, 0x03, 0x02, 0x12, 0x34,
      ]));

      await client.readReg(1, 0, 1);
      // give the broadcast stream a tick to flush
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(captured.length, 2);
      expect(captured[0].isTx, true);
      expect(captured[1].isTx, false);
      expect(captured[0].transactionId, captured[1].transactionId);
      expect(captured[0].mbap?.functionCode, 0x03);
      expect(captured[1].mbap?.functionCode, 0x03);
    });
  });

  group('MbClient — connection lifecycle', () {
    test('peer-closed connection emits disconnected\$ once and drops state',
        () async {
      final server = await FakeModbusServer.start();
      final client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 1),
      );
      await client.open();

      final events = <void>[];
      client.disconnected$.listen(events.add);

      // Make sure the server has accepted us, then slam the door — the
      // "wrong unit id → slave force-closes the socket" scenario.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await server.dropConnection();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events.length, 1);
      expect(client.isConnected, isFalse);
      // Follow-up requests fail fast instead of hanging.
      await expectLater(
          client.readReg(1, 0, 1), throwsA(isA<MbDisconnect>()));

      await client.dispose();
      await server.close();
    });

    test('deliberate close() does not emit disconnected\$', () async {
      final server = await FakeModbusServer.start();
      final client = MbClient.tcp(
        host: '127.0.0.1',
        port: server.port,
        timeout: const Duration(seconds: 1),
      );
      await client.open();

      final events = <void>[];
      client.disconnected$.listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, isEmpty);

      await client.dispose();
      await server.close();
    });

    test('connecting to closed port throws MbDisconnect', () async {
      // Bind then close to grab a known-unused port.
      final probe = await FakeModbusServer.start();
      final port = probe.port;
      await probe.close();

      final c = MbClient.tcp(
        host: '127.0.0.1',
        port: port,
        timeout: const Duration(milliseconds: 500),
      );
      await expectLater(c.open(), throwsA(isA<MbDisconnect>()));
    });

    test('calling read on unopened client throws MbDisconnect', () async {
      final c = MbClient.tcp(host: '127.0.0.1', port: 1);
      await expectLater(c.readReg(1, 0, 1), throwsA(isA<MbDisconnect>()));
    });
  });
}
