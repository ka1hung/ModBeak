import 'dart:typed_data';

/// CRC-16-IBM (a.k.a. CRC-16-ANSI / Modbus CRC) — polynomial 0xA001, init 0xFFFF.
///
/// Used by Modbus RTU. The CRC is appended to each ADU **little-endian**
/// (low byte first, high byte second), which is the opposite of the
/// "natural" big-endian Modbus convention.
class Crc16 {
  static final Uint16List _table = _buildTable();

  /// Compute the 16-bit CRC over [data].
  static int compute(Uint8List data) {
    var crc = 0xFFFF;
    for (final b in data) {
      crc = (crc >> 8) ^ _table[(crc ^ b) & 0xFF];
    }
    return crc & 0xFFFF;
  }

  /// Return a new buffer: `data || crc_lo || crc_hi`.
  static Uint8List append(Uint8List data) {
    final crc = compute(data);
    final out = Uint8List(data.length + 2);
    out.setRange(0, data.length, data);
    out[data.length] = crc & 0xFF;          // low byte first
    out[data.length + 1] = (crc >> 8) & 0xFF;
    return out;
  }

  /// Verify that the last two bytes of [frame] are the CRC of the preceding
  /// bytes. Returns false if the frame is shorter than 3 bytes.
  static bool check(Uint8List frame) {
    if (frame.length < 3) return false;
    final body = Uint8List.sublistView(frame, 0, frame.length - 2);
    final expected = compute(body);
    final lo = frame[frame.length - 2];
    final hi = frame[frame.length - 1];
    return ((hi << 8) | lo) == expected;
  }

  static Uint16List _buildTable() {
    final t = Uint16List(256);
    for (var i = 0; i < 256; i++) {
      var crc = i;
      for (var j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
      t[i] = crc & 0xFFFF;
    }
    return t;
  }
}
