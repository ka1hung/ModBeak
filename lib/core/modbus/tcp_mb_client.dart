import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'exceptions.dart';
import 'mb_client.dart';
import 'modbus_transport.dart';
import 'raw_packet.dart';

/// Modbus TCP transport. Dart port of `ka1hung/mbclient` (Go) with two upgrades:
///   1. Auto-incrementing transaction ID, so a single connection can serve
///      concurrent requests (Go original always uses TID = 0).
///   2. Raw packet stream for the UI's Wireshark-style packet panel.
///
/// One [TcpMbClient] owns one TCP socket. Multiple UI panes that target the
/// same device should share an instance and let the request/response pump
/// fan out by transaction ID.
class TcpMbClient implements MbClient {
  final String host;
  final int port;
  final Duration timeout;

  /// If true, requests are forced through a mutex so only one is in-flight at
  /// any time. Use this for legacy slaves that drop concurrent transactions.
  final bool serializeRequests;

  /// Minimum gap (milliseconds) between successive requests on this socket.
  /// 0 = no throttling. Setting this > 0 implies serialization (each request
  /// waits its turn). Use this to protect MCU-class slaves that can't keep
  /// up with high request rates from multiple watches.
  final int minRequestGapMs;

  Socket? _socket;
  int _txCounter = 0;
  final Map<int, Completer<Uint8List>> _pending = {};
  Uint8List _rxBuffer = Uint8List(0);
  Future<void> _writeLock = Future.value();
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  final StreamController<RawPacket> _rawCtrl =
      StreamController<RawPacket>.broadcast();

  @override
  Stream<RawPacket> get rawPackets$ => _rawCtrl.stream;

  TcpMbClient({
    required this.host,
    required this.port,
    this.timeout = const Duration(seconds: 2),
    this.serializeRequests = false,
    this.minRequestGapMs = 0,
  });

  /// True when requests must be sent one at a time.
  bool get _mustSerialize => serializeRequests || minRequestGapMs > 0;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> open() async {
    if (_socket != null) return;
    try {
      final s = await Socket.connect(host, port, timeout: timeout);
      s.listen(
        _onData,
        onError: (Object _, [StackTrace? stack]) => _shutdown(),
        onDone: _shutdown,
        cancelOnError: true,
      );
      _socket = s;
    } on SocketException catch (e) {
      throw MbDisconnect('SocketException: ${e.message}');
    } on TimeoutException {
      throw const MbDisconnect('Connect timeout');
    }
  }

  @override
  Future<void> close() async {
    final s = _socket;
    _socket = null;
    if (s != null) {
      await s.close();
    }
    _shutdown();
  }

  /// Closes the broadcast stream — call this when the client is being
  /// permanently disposed (e.g. device removed).
  @override
  Future<void> dispose() async {
    await close();
    await _rawCtrl.close();
  }

  void _shutdown() {
    final s = _socket;
    _socket = null;
    s?.destroy();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(const MbDisconnect());
    }
    _pending.clear();
    _rxBuffer = Uint8List(0);
  }

  // ─── Public API: same names as Go mbclient ──────────────────────────────

  /// FC 01 — Read Coils.
  @override
  Future<List<bool>> readCoil(int unitId, int addr, int qty) =>
      _readBitsInternal(unitId, addr, qty, 0x01);

  /// FC 02 — Read Discrete Inputs.
  @override
  Future<List<bool>> readCoilIn(int unitId, int addr, int qty) =>
      _readBitsInternal(unitId, addr, qty, 0x02);

  /// FC 03 — Read Holding Registers.
  @override
  Future<List<int>> readReg(int unitId, int addr, int qty) =>
      _readRegsInternal(unitId, addr, qty, 0x03);

  /// FC 04 — Read Input Registers.
  @override
  Future<List<int>> readRegIn(int unitId, int addr, int qty) =>
      _readRegsInternal(unitId, addr, qty, 0x04);

  /// FC 05 — Write Single Coil.
  @override
  Future<void> writeCoil(int unitId, int addr, bool value) async {
    final pdu = Uint8List.fromList([
      unitId,
      0x05,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      value ? 0xFF : 0x00,
      0x00,
    ]);
    await _query(pdu);
  }

  /// FC 06 — Write Single Register.
  @override
  Future<void> writeReg(int unitId, int addr, int value) async {
    final pdu = Uint8List.fromList([
      unitId,
      0x06,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
    await _query(pdu);
  }

  /// FC 15 — Write Multiple Coils.
  @override
  Future<void> writeCoils(int unitId, int addr, List<bool> values) async {
    if (values.isEmpty) {
      throw ArgumentError('writeCoils: values must not be empty');
    }
    final byteCount = (values.length + 7) ~/ 8;
    final coilBytes = Uint8List(byteCount);
    for (var i = 0; i < values.length; i++) {
      if (values[i]) coilBytes[i ~/ 8] |= (1 << (i % 8));
    }
    final pdu = Uint8List.fromList([
      unitId,
      0x0F,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (values.length >> 8) & 0xFF,
      values.length & 0xFF,
      byteCount,
      ...coilBytes,
    ]);
    await _query(pdu);
  }

  /// FC 16 — Write Multiple Registers.
  @override
  Future<void> writeRegs(int unitId, int addr, List<int> values) async {
    if (values.isEmpty) {
      throw ArgumentError('writeRegs: values must not be empty');
    }
    final byteCount = values.length * 2;
    final regBytes = Uint8List(byteCount);
    for (var i = 0; i < values.length; i++) {
      regBytes[i * 2] = (values[i] >> 8) & 0xFF;
      regBytes[i * 2 + 1] = values[i] & 0xFF;
    }
    final pdu = Uint8List.fromList([
      unitId,
      0x10,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (values.length >> 8) & 0xFF,
      values.length & 0xFF,
      byteCount,
      ...regBytes,
    ]);
    await _query(pdu);
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  Future<List<bool>> _readBitsInternal(
      int unitId, int addr, int qty, int fc) async {
    final pdu = Uint8List.fromList([
      unitId,
      fc,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (qty >> 8) & 0xFF,
      qty & 0xFF,
    ]);
    final res = await _query(pdu);
    // res = [unitId, fc, byteCount, ...data]
    final byteCount = res[2];
    final out = <bool>[];
    for (var i = 0; i < byteCount; i++) {
      for (var j = 0; j < 8 && out.length < qty; j++) {
        out.add((res[3 + i] & (1 << j)) != 0);
      }
    }
    return out;
  }

  Future<List<int>> _readRegsInternal(
      int unitId, int addr, int qty, int fc) async {
    final pdu = Uint8List.fromList([
      unitId,
      fc,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (qty >> 8) & 0xFF,
      qty & 0xFF,
    ]);
    final res = await _query(pdu);
    final out = List<int>.filled(qty, 0);
    for (var i = 0; i < qty; i++) {
      out[i] = (res[3 + i * 2] << 8) | res[4 + i * 2];
    }
    return out;
  }

  /// Build MBAP + PDU, send, await matching response by transaction id.
  /// Returns the bytes from unitId onwards (i.e. dropping the 6-byte MBAP
  /// prefix), to match the Go mbclient `Query` return shape.
  Future<Uint8List> _query(Uint8List pdu) async {
    if (_mustSerialize) {
      final prev = _writeLock;
      final myTurn = Completer<void>();
      _writeLock = myTurn.future;
      await prev;
      try {
        // Enforce minimum gap since last request — protects MCUs.
        if (minRequestGapMs > 0) {
          final since = DateTime.now()
              .difference(_lastRequestAt)
              .inMilliseconds;
          if (since < minRequestGapMs) {
            await Future<void>.delayed(
                Duration(milliseconds: minRequestGapMs - since));
          }
        }
        _lastRequestAt = DateTime.now();
        return await _queryRaw(pdu);
      } finally {
        myTurn.complete();
      }
    }
    return _queryRaw(pdu);
  }

  Future<Uint8List> _queryRaw(Uint8List pdu) async {
    final s = _socket;
    if (s == null) throw const MbDisconnect();

    _txCounter = (_txCounter + 1) & 0xFFFF;
    final tid = _txCounter == 0 ? 1 : _txCounter; // skip 0 to make TID truthy
    final frame = _buildAdu(tid, pdu);

    final completer = Completer<Uint8List>();
    _pending[tid] = completer;

    s.add(frame);
    _rawCtrl.add(RawPacket(
      time: DateTime.now(),
      isTx: true,
      bytes: frame,
      transport: ModbusTransport.tcp,
      transactionId: tid,
    ));

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(tid);
      throw const MbNoResponse();
    }
  }

  static Uint8List _buildAdu(int tid, Uint8List pdu) {
    final out = Uint8List(6 + pdu.length);
    out[0] = (tid >> 8) & 0xFF;
    out[1] = tid & 0xFF;
    out[2] = 0; // protocol id high
    out[3] = 0; // protocol id low
    out[4] = (pdu.length >> 8) & 0xFF;
    out[5] = pdu.length & 0xFF;
    out.setRange(6, 6 + pdu.length, pdu);
    return out;
  }

  void _onData(List<int> chunk) {
    // Append to running buffer.
    final merged = Uint8List(_rxBuffer.length + chunk.length)
      ..setRange(0, _rxBuffer.length, _rxBuffer)
      ..setRange(_rxBuffer.length, _rxBuffer.length + chunk.length, chunk);
    _rxBuffer = merged;

    // Drain as many complete frames as the buffer holds.
    while (_rxBuffer.length >= 8) {
      final length = (_rxBuffer[4] << 8) | _rxBuffer[5];
      final total = 6 + length;
      if (_rxBuffer.length < total) break;

      final frame = Uint8List.sublistView(_rxBuffer, 0, total);
      _rxBuffer = Uint8List.sublistView(_rxBuffer, total);

      final tid = (frame[0] << 8) | frame[1];
      _rawCtrl.add(RawPacket(
        time: DateTime.now(),
        isTx: false,
        bytes: Uint8List.fromList(frame),
        transport: ModbusTransport.tcp,
        transactionId: tid,
      ));

      final completer = _pending.remove(tid);
      if (completer == null || completer.isCompleted) continue;

      // Modbus exception: FC byte high bit set.
      final fc = frame[7];
      if ((fc & 0x80) != 0) {
        if (frame.length >= 9) {
          completer.completeError(MbModbusError.fromCode(frame[8]));
        } else {
          completer.completeError(
              const MbModbusError('exception frame too short'));
        }
        continue;
      }

      // Hand back from unitId onwards (Go mbclient semantics).
      completer.complete(Uint8List.fromList(frame.sublist(6)));
    }
  }
}
