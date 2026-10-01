import 'dart:async';

import 'raw_packet.dart';
import 'rtu_mb_client.dart';
import 'tcp_mb_client.dart';

/// Public Modbus client API. Concrete subclasses pick the transport:
///   * [TcpMbClient] — Modbus TCP via dart:io [Socket]
///   * [RtuMbClient] — Modbus RTU via flutter_libserialport
///
/// Use the factory constructors:
/// ```dart
/// final tcp = MbClient.tcp(host: '192.168.1.10', port: 502);
/// final rtu = MbClient.rtu(serialPortName: 'COM3', baudRate: 9600);
/// ```
abstract class MbClient {
  /// Emits every TX/RX frame, in order, for the raw packet panel.
  Stream<RawPacket> get rawPackets$;

  /// Fires once when the transport drops unexpectedly — the peer closed the
  /// socket, the network failed, or the serial reader died. A deliberate
  /// [close] / [dispose] never emits. Listeners (the DeviceHub) use this to
  /// stop polling and surface the disconnected state instead of letting
  /// every subsequent request fail with [MbDisconnect].
  Stream<void> get disconnected$;

  bool get isConnected;

  Future<void> open();
  Future<void> close();

  /// Closes the broadcast stream — call this when the client is being
  /// permanently disposed (e.g. device removed).
  Future<void> dispose();

  /// FC 01 — Read Coils.
  Future<List<bool>> readCoil(int unitId, int addr, int qty);

  /// FC 02 — Read Discrete Inputs.
  Future<List<bool>> readCoilIn(int unitId, int addr, int qty);

  /// FC 03 — Read Holding Registers.
  Future<List<int>> readReg(int unitId, int addr, int qty);

  /// FC 04 — Read Input Registers.
  Future<List<int>> readRegIn(int unitId, int addr, int qty);

  /// FC 05 — Write Single Coil.
  Future<void> writeCoil(int unitId, int addr, bool value);

  /// FC 06 — Write Single Register.
  Future<void> writeReg(int unitId, int addr, int value);

  /// FC 15 — Write Multiple Coils.
  Future<void> writeCoils(int unitId, int addr, List<bool> values);

  /// FC 16 — Write Multiple Registers.
  Future<void> writeRegs(int unitId, int addr, List<int> values);

  /// Modbus TCP transport.
  factory MbClient.tcp({
    required String host,
    required int port,
    Duration timeout,
    bool serializeRequests,
    int minRequestGapMs,
  }) = TcpMbClient;

  /// Modbus RTU transport (serial port). Half-duplex — requests are always
  /// serialized internally regardless of any caller-side flag.
  factory MbClient.rtu({
    required String serialPortName,
    int baudRate,
    int dataBits,
    int stopBits,
    SerialParity parity,
    Duration timeout,
    int minRequestGapMs,
  }) = RtuMbClient;
}
