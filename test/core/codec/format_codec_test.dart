import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/core/codec/format_codec.dart';
import 'package:modbeak/data/models/register_format.dart';

void main() {
  group('FormatCodec — u16/i16/hex/bin', () {
    test('u16 round trip', () {
      final c = codecFor(RegisterFormat.u16);
      expect(c.decode([0x1234], 0), '4660');
      expect(c.encode('65535'), [0xFFFF]);
      expect(() => c.encode('-1'), throwsFormatException);
    });

    test('i16 handles negative', () {
      final c = codecFor(RegisterFormat.i16);
      expect(c.decode([0xFFFF], 0), '-1');
      expect(c.decode([0x8000], 0), '-32768');
      expect(c.decode([0x7FFF], 0), '32767');
      expect(c.encode('-1'), [0xFFFF]);
      expect(c.encode('-32768'), [0x8000]);
    });

    test('hex round trip', () {
      final c = codecFor(RegisterFormat.hex);
      expect(c.decode([0xCAFE], 0), '0xCAFE');
      expect(c.encode('0xBEEF'), [0xBEEF]);
      expect(c.encode('beef'), [0xBEEF]);
    });

    test('bin round trip with nibble grouping', () {
      final c = codecFor(RegisterFormat.bin);
      expect(c.decode([0x00FF], 0), '0000 0000 1111 1111');
      // encode tolerates spaces/underscores
      expect(c.encode('0000 0000 1111 1111'), [0x00FF]);
      expect(c.encode('1010'), [0xA]);
    });
  });

  group('FormatCodec — u32 / i32 endian variations', () {
    test('u32be', () {
      final c = codecFor(RegisterFormat.u32be);
      // 0xCAFEBEEF = 3405692655
      expect(c.decode([0xCAFE, 0xBEEF], 0), '3405692655');
      expect(c.encode('3405692655'), [0xCAFE, 0xBEEF]);
    });

    test('u32le swaps register order', () {
      final c = codecFor(RegisterFormat.u32le);
      // LE: regs = [lo, hi], decoded value is still 0xCAFEBEEF.
      expect(c.decode([0xBEEF, 0xCAFE], 0), '3405692655');
      expect(c.encode('3405692655'), [0xBEEF, 0xCAFE]);
    });

    test('i32be sign extends', () {
      final c = codecFor(RegisterFormat.i32be);
      expect(c.decode([0xFFFF, 0xFFFF], 0), '-1');
      expect(c.encode('-1'), [0xFFFF, 0xFFFF]);
    });
  });

  group('FormatCodec — f32', () {
    test('f32be IEEE 754 round trip', () {
      final c = codecFor(RegisterFormat.f32be);
      // 56.78 ≈ 0x4263 1EB8
      final encoded = c.encode('56.78');
      expect(encoded.length, 2);
      final decoded = c.decode(encoded, 0);
      expect(double.parse(decoded), closeTo(56.78, 0.001));
    });

    test('f32le mirrors f32be with swapped registers', () {
      final be = codecFor(RegisterFormat.f32be);
      final le = codecFor(RegisterFormat.f32le);
      final beRegs = be.encode('-3.14');
      // LE = [lo, hi]
      final leRegs = [beRegs[1], beRegs[0]];
      expect(double.parse(le.decode(leRegs, 0)), closeTo(-3.14, 0.001));
    });
  });

  group('FormatCodec — ascii', () {
    test('ascii decode strips non-printable', () {
      // "Hi" packed BE: 0x4869 = 'H','i'
      final c = codecFor(RegisterFormat.ascii, asciiCharsPerRow: 2);
      expect(c.decode([0x4869], 0), 'Hi');
    });

    test('ascii encode pads to full register', () {
      final c = codecFor(RegisterFormat.ascii, asciiCharsPerRow: 4);
      final regs = c.encode('OK');
      expect(regs.length, 1);
      expect(regs[0], 0x4F4B);
    });
  });

  group('FormatCodec — bool', () {
    test('decodes TRUE/FALSE', () {
      final c = codecFor(RegisterFormat.bool_);
      expect(c.decode([0], 0), 'FALSE');
      expect(c.decode([1], 0), 'TRUE');
    });

    test('encodes flexible truthy strings', () {
      final c = codecFor(RegisterFormat.bool_);
      expect(c.encode('1'), [1]);
      expect(c.encode('true'), [1]);
      expect(c.encode('ON'), [1]);
      expect(c.encode('0'), [0]);
      expect(c.encode('false'), [0]);
      expect(() => c.encode('maybe'), throwsFormatException);
    });
  });
}
