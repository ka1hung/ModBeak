import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/modbus/crc16.dart';

void main() {
  group('Crc16', () {
    // Pinned vectors — the algorithm is the standard Modbus CRC (poly 0xA001,
    // init 0xFFFF, LSB-first). These exact byte pairs are what the wire sees
    // (low byte first, high byte second) and were confirmed against an
    // independent Modbus CRC calculator.
    // Each tuple: input bytes (no CRC) → expected (lo, hi) appended on the wire.
    final cases = <(List<int>, int, int)>[
      // FC 03 — Read Holding Registers, unit 1, addr 0, qty 10
      ([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A], 0xC5, 0xCD),
      // FC 01 — Read Coils, unit 1, addr 0, qty 8
      ([0x01, 0x01, 0x00, 0x00, 0x00, 0x08], 0x3D, 0xCC),
      // FC 06 — Write Single Register, unit 1, addr 1, value 0x0003
      ([0x01, 0x06, 0x00, 0x01, 0x00, 0x03], 0x98, 0x0B),
      // FC 16 echo response, unit 1, addr 0, qty 2
      ([0x01, 0x10, 0x00, 0x00, 0x00, 0x02], 0x41, 0xC8),
      // FC 04 response: unit 1, byte_count 2, value FFFF — well-known vector
      ([0x01, 0x04, 0x02, 0xFF, 0xFF], 0xB8, 0x80),
    ];

    for (final (input, lo, hi) in cases) {
      test('compute / append matches reference: ${_hex(input)}', () {
        final data = Uint8List.fromList(input);
        final crc = Crc16.compute(data);
        expect(crc & 0xFF, lo, reason: 'low byte mismatch');
        expect((crc >> 8) & 0xFF, hi, reason: 'high byte mismatch');

        final framed = Crc16.append(data);
        expect(framed.length, input.length + 2);
        expect(framed[input.length], lo);
        expect(framed[input.length + 1], hi);
      });
    }

    test('check accepts a correctly-CRCed frame', () {
      final frame = Crc16.append(Uint8List.fromList([0x01, 0x03, 0x02, 0x12, 0x34]));
      expect(Crc16.check(frame), true);
    });

    test('check rejects a corrupted frame', () {
      final frame = Crc16.append(Uint8List.fromList([0x01, 0x03, 0x02, 0x12, 0x34]));
      // flip one bit in the payload
      frame[3] ^= 0x01;
      expect(Crc16.check(frame), false);
    });

    test('check returns false for buffers shorter than 3 bytes', () {
      expect(Crc16.check(Uint8List(0)), false);
      expect(Crc16.check(Uint8List.fromList([0x01, 0x02])), false);
    });
  });
}

String _hex(List<int> bs) =>
    bs.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
