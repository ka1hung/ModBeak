import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/modbus/modbus_transport.dart';
import 'package:modbeak/core/modbus/raw_packet.dart';
import 'package:modbeak/core/modbus/rtu_mb_client.dart';

void main() {
  group('RtuMbClient.expectedResponseLen', () {
    test('FC 03 / 04 — read regs: 5 + qty*2', () {
      expect(RtuMbClient.expectedResponseLen(0x03, 1), 7);
      expect(RtuMbClient.expectedResponseLen(0x03, 10), 25);
      expect(RtuMbClient.expectedResponseLen(0x04, 5), 15);
    });

    test('FC 01 / 02 — read bits: 5 + ceil(qty/8)', () {
      expect(RtuMbClient.expectedResponseLen(0x01, 1), 6);
      expect(RtuMbClient.expectedResponseLen(0x01, 8), 6);
      expect(RtuMbClient.expectedResponseLen(0x01, 9), 7);
      expect(RtuMbClient.expectedResponseLen(0x02, 16), 7);
      expect(RtuMbClient.expectedResponseLen(0x02, 17), 8);
    });

    test('FC 05 / 06 / 0F / 10 — echo: always 8 bytes', () {
      for (final fc in [0x05, 0x06, 0x0F, 0x10]) {
        expect(RtuMbClient.expectedResponseLen(fc, 0), 8,
            reason: 'FC 0x${fc.toRadixString(16)}');
      }
    });

    test('unsupported FC throws', () {
      expect(() => RtuMbClient.expectedResponseLen(0x99, 0),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('RtuFrameInfo.tryParse', () {
    test('returns null for buffers shorter than 2 bytes', () {
      expect(RtuFrameInfo.tryParse(Uint8List(0)), isNull);
      expect(RtuFrameInfo.tryParse(Uint8List.fromList([0x01])), isNull);
    });

    test('parses minimal slave + fc with no CRC field', () {
      final info = RtuFrameInfo.tryParse(Uint8List.fromList([0x01, 0x03, 0x02]));
      expect(info, isNotNull);
      expect(info!.slaveId, 1);
      expect(info.functionCode, 0x03);
      expect(info.isException, false);
      // 3 bytes is too short for CRC (need >= 4)
      expect(info.crc, isNull);
    });

    test('parses CRC from trailing two bytes (lo, hi)', () {
      // Frame: slave=01 fc=03 byteCount=02 hi=12 lo=34 crc_lo=AA crc_hi=BB
      final bytes = Uint8List.fromList([0x01, 0x03, 0x02, 0x12, 0x34, 0xAA, 0xBB]);
      final info = RtuFrameInfo.tryParse(bytes)!;
      expect(info.slaveId, 1);
      expect(info.functionCode, 0x03);
      expect(info.crc, 0xBBAA);
    });

    test('flags exception responses (FC high bit)', () {
      final bytes = Uint8List.fromList([0x01, 0x83, 0x02, 0xC0, 0xF1]);
      final info = RtuFrameInfo.tryParse(bytes)!;
      expect(info.isException, true);
      expect(info.functionCode, 0x83);
    });
  });

  group('RawPacket — transport-aware accessors', () {
    test('TCP packet: mbap parses, rtu is null', () {
      // 8-byte minimum MBAP frame: tid=0001 proto=0000 len=0006 unit=01 fc=03
      final bytes = Uint8List.fromList(
          [0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x01, 0x03]);
      final p = RawPacket(
        time: DateTime.now(),
        isTx: true,
        bytes: bytes,
        transport: ModbusTransport.tcp,
        transactionId: 1,
      );
      expect(p.mbap, isNotNull);
      expect(p.mbap!.functionCode, 0x03);
      expect(p.rtu, isNull);
    });

    test('RTU packet: rtu parses, mbap is null', () {
      final bytes = Uint8List.fromList(
          [0x01, 0x03, 0x02, 0x12, 0x34, 0xAA, 0xBB]);
      final p = RawPacket(
        time: DateTime.now(),
        isTx: false,
        bytes: bytes,
        transport: ModbusTransport.rtu,
      );
      expect(p.rtu, isNotNull);
      expect(p.rtu!.slaveId, 1);
      expect(p.mbap, isNull);
    });
  });
}
