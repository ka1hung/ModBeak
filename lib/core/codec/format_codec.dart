import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/register_format.dart';

/// Two-way conversion between raw 16-bit registers and a display string.
///
/// The pane keeps the raw `List<int>` from the poll loop and asks the codec
/// to format each row on render — switching format never re-fetches.
abstract class FormatCodec {
  /// 1 register / row, -1 = ASCII (caller-controlled), 0 = bit (coil).
  int get registersPerValue;

  /// Decode `regs[offset .. offset + registersPerValue - 1]` to a string.
  String decode(List<int> regs, int offset);

  /// Parse a user-typed string back to register words. Throws
  /// [FormatException] if input does not match this format.
  List<int> encode(String input);
}

class _U16Codec implements FormatCodec {
  @override
  int get registersPerValue => 1;
  @override
  String decode(List<int> r, int i) => (r[i] & 0xFFFF).toString();
  @override
  List<int> encode(String s) {
    final v = int.parse(s.trim());
    if (v < 0 || v > 0xFFFF) throw FormatException('UInt16 out of range');
    return [v];
  }
}

class _I16Codec implements FormatCodec {
  @override
  int get registersPerValue => 1;
  @override
  String decode(List<int> r, int i) {
    final v = r[i] & 0xFFFF;
    return ((v & 0x8000) != 0 ? v - 0x10000 : v).toString();
  }

  @override
  List<int> encode(String s) {
    final v = int.parse(s.trim());
    if (v < -0x8000 || v > 0x7FFF) throw FormatException('Int16 out of range');
    return [v & 0xFFFF];
  }
}

class _HexCodec implements FormatCodec {
  @override
  int get registersPerValue => 1;
  @override
  String decode(List<int> r, int i) =>
      '0x${(r[i] & 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase()}';
  @override
  List<int> encode(String s) {
    var clean = s.trim().toLowerCase();
    if (clean.startsWith('0x')) clean = clean.substring(2);
    final v = int.parse(clean, radix: 16);
    if (v < 0 || v > 0xFFFF) throw FormatException('Hex out of u16 range');
    return [v];
  }
}

class _BinCodec implements FormatCodec {
  @override
  int get registersPerValue => 1;
  @override
  String decode(List<int> r, int i) {
    // Group bits in nibbles for readability:  0010 1111 0101 0001
    final b = (r[i] & 0xFFFF).toRadixString(2).padLeft(16, '0');
    return '${b.substring(0, 4)} ${b.substring(4, 8)} '
        '${b.substring(8, 12)} ${b.substring(12, 16)}';
  }

  @override
  List<int> encode(String s) {
    final clean = s.trim().replaceAll(' ', '').replaceAll('_', '');
    if (clean.isEmpty || clean.length > 16) {
      throw FormatException('Binary must be 1..16 digits');
    }
    final v = int.parse(clean, radix: 2);
    return [v & 0xFFFF];
  }
}

class _U32Codec implements FormatCodec {
  final Endian endian;
  const _U32Codec(this.endian);
  @override
  int get registersPerValue => 2;
  @override
  String decode(List<int> r, int i) {
    final hi = r[endian == Endian.big ? i : i + 1] & 0xFFFF;
    final lo = r[endian == Endian.big ? i + 1 : i] & 0xFFFF;
    return ((hi << 16) | lo).toUnsigned(32).toString();
  }

  @override
  List<int> encode(String s) {
    final v = int.parse(s.trim());
    if (v < 0 || v > 0xFFFFFFFF) throw FormatException('UInt32 out of range');
    final hi = (v >> 16) & 0xFFFF;
    final lo = v & 0xFFFF;
    return endian == Endian.big ? [hi, lo] : [lo, hi];
  }
}

class _I32Codec implements FormatCodec {
  final Endian endian;
  const _I32Codec(this.endian);
  @override
  int get registersPerValue => 2;
  @override
  String decode(List<int> r, int i) {
    final hi = r[endian == Endian.big ? i : i + 1] & 0xFFFF;
    final lo = r[endian == Endian.big ? i + 1 : i] & 0xFFFF;
    final raw = (hi << 16) | lo;
    return raw.toSigned(32).toString();
  }

  @override
  List<int> encode(String s) {
    final v = int.parse(s.trim());
    if (v < -0x80000000 || v > 0x7FFFFFFF) {
      throw FormatException('Int32 out of range');
    }
    final raw = v & 0xFFFFFFFF;
    final hi = (raw >> 16) & 0xFFFF;
    final lo = raw & 0xFFFF;
    return endian == Endian.big ? [hi, lo] : [lo, hi];
  }
}

class _F32Codec implements FormatCodec {
  final Endian endian;
  const _F32Codec(this.endian);
  @override
  int get registersPerValue => 2;
  @override
  String decode(List<int> r, int i) {
    final hi = r[endian == Endian.big ? i : i + 1] & 0xFFFF;
    final lo = r[endian == Endian.big ? i + 1 : i] & 0xFFFF;
    final bd = ByteData(4)
      ..setUint16(0, hi, Endian.big)
      ..setUint16(2, lo, Endian.big);
    final v = bd.getFloat32(0, Endian.big);
    return v.toStringAsPrecision(7);
  }

  @override
  List<int> encode(String s) {
    final v = double.parse(s.trim());
    final bd = ByteData(4)..setFloat32(0, v, Endian.big);
    final hi = bd.getUint16(0, Endian.big);
    final lo = bd.getUint16(2, Endian.big);
    return endian == Endian.big ? [hi, lo] : [lo, hi];
  }
}

class _AsciiCodec implements FormatCodec {
  final int charsPerRow;
  const _AsciiCodec(this.charsPerRow);
  @override
  int get registersPerValue => (charsPerRow + 1) ~/ 2;
  @override
  String decode(List<int> r, int i) {
    final regsPerRow = registersPerValue;
    final bytes = <int>[];
    for (var k = 0; k < regsPerRow; k++) {
      final w = r[i + k] & 0xFFFF;
      bytes.add((w >> 8) & 0xFF);
      bytes.add(w & 0xFF);
    }
    final printable =
        bytes.take(charsPerRow).map((b) => (b >= 32 && b < 127) ? b : 0x2E);
    return String.fromCharCodes(printable);
  }

  @override
  List<int> encode(String s) {
    final bytes = ascii.encode(s);
    final regs = <int>[];
    for (var k = 0; k < bytes.length; k += 2) {
      final hi = bytes[k];
      final lo = (k + 1 < bytes.length) ? bytes[k + 1] : 0;
      regs.add((hi << 8) | lo);
    }
    return regs;
  }
}

class _BoolCodec implements FormatCodec {
  @override
  int get registersPerValue => 0;
  @override
  String decode(List<int> r, int i) => r[i] != 0 ? 'TRUE' : 'FALSE';
  @override
  List<int> encode(String s) {
    final t = s.trim().toLowerCase();
    if (t == '1' || t == 'true' || t == 'on') return [1];
    if (t == '0' || t == 'false' || t == 'off') return [0];
    throw FormatException('Expected TRUE / FALSE / 0 / 1');
  }
}

/// Factory — pick the codec for a format, with optional ASCII width.
FormatCodec codecFor(RegisterFormat fmt, {int asciiCharsPerRow = 8}) {
  switch (fmt) {
    case RegisterFormat.u16:
      return _U16Codec();
    case RegisterFormat.i16:
      return _I16Codec();
    case RegisterFormat.hex:
      return _HexCodec();
    case RegisterFormat.bin:
      return _BinCodec();
    case RegisterFormat.u32be:
      return const _U32Codec(Endian.big);
    case RegisterFormat.u32le:
      return const _U32Codec(Endian.little);
    case RegisterFormat.i32be:
      return const _I32Codec(Endian.big);
    case RegisterFormat.i32le:
      return const _I32Codec(Endian.little);
    case RegisterFormat.f32be:
      return const _F32Codec(Endian.big);
    case RegisterFormat.f32le:
      return const _F32Codec(Endian.little);
    case RegisterFormat.ascii:
      return _AsciiCodec(asciiCharsPerRow);
    case RegisterFormat.bool_:
      return _BoolCodec();
  }
}
