import 'dart:typed_data';

import 'modbus_transport.dart';

/// One direction of a Modbus frame on the wire, captured for the UI's
/// raw packet panel (Wireshark-style).
class RawPacket {
  final DateTime time;
  final bool isTx;
  final Uint8List bytes;

  /// Which transport produced this frame — controls how [mbap] / [rtu]
  /// decode the byte stream.
  final ModbusTransport transport;

  /// TCP only — the matching transaction id (auto-incremented per request).
  /// Always null for RTU frames.
  final int? transactionId;

  const RawPacket({
    required this.time,
    required this.isTx,
    required this.bytes,
    this.transport = ModbusTransport.tcp,
    this.transactionId,
  });

  /// Parsed MBAP header. Returns null for RTU frames or when the buffer is
  /// too short to parse.
  MbapHeader? get mbap => transport == ModbusTransport.tcp
      ? MbapHeader.tryParse(bytes)
      : null;

  /// Parsed RTU frame summary. Returns null for TCP frames or when the
  /// buffer is too short to parse.
  RtuFrameInfo? get rtu => transport == ModbusTransport.rtu
      ? RtuFrameInfo.tryParse(bytes)
      : null;

  String get directionLabel => isTx ? 'TX' : 'RX';
}

/// Parsed MBAP (Modbus Application Protocol) header — the 7 byte prefix
/// before the PDU on Modbus TCP.
class MbapHeader {
  final int transactionId;
  final int protocolId;
  final int length;
  final int unitId;
  final int functionCode;

  const MbapHeader({
    required this.transactionId,
    required this.protocolId,
    required this.length,
    required this.unitId,
    required this.functionCode,
  });

  static MbapHeader? tryParse(Uint8List b) {
    if (b.length < 8) return null;
    return MbapHeader(
      transactionId: (b[0] << 8) | b[1],
      protocolId: (b[2] << 8) | b[3],
      length: (b[4] << 8) | b[5],
      unitId: b[6],
      functionCode: b[7],
    );
  }

  bool get isException => (functionCode & 0x80) != 0;
}

/// Parsed RTU frame summary — `[slaveId][functionCode][...payload...][crc_lo][crc_hi]`.
/// Lenient: the CRC field is only populated when the frame is at least 4
/// bytes long; the payload is everything between FC and the trailing 2-byte
/// CRC.
class RtuFrameInfo {
  final int slaveId;
  final int functionCode;

  /// CRC value as written on the wire (low byte first, high byte second),
  /// reassembled into the 16-bit integer `(hi << 8) | lo`.
  final int? crc;

  const RtuFrameInfo({
    required this.slaveId,
    required this.functionCode,
    this.crc,
  });

  static RtuFrameInfo? tryParse(Uint8List b) {
    if (b.length < 2) return null;
    int? crc;
    if (b.length >= 4) {
      final lo = b[b.length - 2];
      final hi = b[b.length - 1];
      crc = (hi << 8) | lo;
    }
    return RtuFrameInfo(
      slaveId: b[0],
      functionCode: b[1],
      crc: crc,
    );
  }

  bool get isException => (functionCode & 0x80) != 0;
}
