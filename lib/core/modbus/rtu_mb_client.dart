import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

import 'crc16.dart';
import 'exceptions.dart';
import 'mb_client.dart';
import 'modbus_transport.dart';
import 'raw_packet.dart';
import 'serial_parity.dart';

export 'serial_parity.dart' show SerialParity;

/// Modbus RTU transport over a serial port (RS-232 / RS-485 via USB adapter).
///
/// Unlike TCP, RTU is **strictly half-duplex** — only one request may be
/// in-flight on the bus at a time. This class enforces that internally with
/// a write mutex, so the `serializeRequests` flag from [MbClient.tcp] is
/// implicit and has no equivalent constructor parameter here.
///
/// Frame format on the wire:
/// `[slaveId][functionCode][payload...][crc_lo][crc_hi]`
///
/// Expected response length is computed from the function code so we don't
/// need to wait for a silence gap before declaring a frame complete; an
/// exception response (FC byte high bit set) is a fixed 5 bytes total.
class RtuMbClient implements MbClient {
  final String serialPortName;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final SerialParity parity;
  final Duration timeout;

  /// Minimum gap (milliseconds) between successive requests on this port.
  /// 0 = no extra throttling. RTU itself is already serialized; this exists
  /// purely to protect MCU-class slaves that need a per-request quiet time.
  final int minRequestGapMs;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSub;

  Future<void> _writeLock = Future.value();
  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Single in-flight request state. RTU is half-duplex so we never
  // need a tid-keyed map like TCP.
  Completer<Uint8List>? _pending;
  int _expectedLen = 0;
  BytesBuilder _rxBuf = BytesBuilder(copy: false);

  final StreamController<RawPacket> _rawCtrl =
      StreamController<RawPacket>.broadcast();

  @override
  Stream<RawPacket> get rawPackets$ => _rawCtrl.stream;

  RtuMbClient({
    required this.serialPortName,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = SerialParity.none,
    this.timeout = const Duration(seconds: 2),
    this.minRequestGapMs = 0,
  });

  @override
  bool get isConnected => _port?.isOpen ?? false;

  @override
  Future<void> open() async {
    if (isConnected) return;
    final p = SerialPort(serialPortName);
    if (!p.openReadWrite()) {
      final err = SerialPort.lastError;
      p.dispose();
      throw MbDisconnect(
          'Open $serialPortName failed: ${err?.message ?? 'unknown error'}');
    }

    final cfg = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = dataBits
      ..stopBits = stopBits
      ..parity = _parityCode(parity)
      ..xonXoff = SerialPortXonXoff.disabled
      ..rts = SerialPortRts.off
      ..cts = SerialPortCts.ignore
      ..dtr = SerialPortDtr.off
      ..dsr = SerialPortDsr.ignore;
    try {
      p.config = cfg;
    } catch (e) {
      // libserialport throws if the driver rejects the config.
      p.close();
      p.dispose();
      throw MbDisconnect('Configure $serialPortName failed: $e');
    }

    _port = p;
    _reader = SerialPortReader(p);
    _readerSub = _reader!.stream.listen(
      _onData,
      onError: (Object _, [StackTrace? stack]) => _shutdown(),
      onDone: _shutdown,
      cancelOnError: true,
    );
  }

  @override
  Future<void> close() async {
    final r = _reader;
    final p = _port;
    _reader = null;
    _port = null;
    await _readerSub?.cancel();
    _readerSub = null;
    r?.close();
    if (p != null && p.isOpen) {
      p.close();
    }
    p?.dispose();
    _shutdown();
  }

  @override
  Future<void> dispose() async {
    await close();
    await _rawCtrl.close();
  }

  void _shutdown() {
    _expectedLen = 0;
    _rxBuf = BytesBuilder(copy: false);
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) {
      c.completeError(const MbDisconnect());
    }
  }

  static int _parityCode(SerialParity p) => switch (p) {
        SerialParity.none => SerialPortParity.none,
        SerialParity.even => SerialPortParity.even,
        SerialParity.odd => SerialPortParity.odd,
      };

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Expected response length on the wire (slaveId + PDU + CRC) for a
  /// successful response to function code [fc] with quantity [qty].
  /// Exception responses are always 5 bytes and detected separately
  /// from the FC byte's high bit in [_onData].
  ///
  /// Public so the algorithm can be unit-tested without driving a real port.
  static int expectedResponseLen(int fc, int qty) => _expectedRespLen(fc, qty);

  static int _expectedRespLen(int fc, int qty) {
    switch (fc) {
      case 0x01:
      case 0x02:
        // slaveId + fc + byteCount + ceil(qty/8) + CRC(2)
        return 5 + ((qty + 7) ~/ 8);
      case 0x03:
      case 0x04:
        // slaveId + fc + byteCount + qty*2 + CRC(2)
        return 5 + qty * 2;
      case 0x05:
      case 0x06:
      case 0x0F:
      case 0x10:
        // Echo: slaveId + fc + addr(2) + value(2) + CRC(2)
        return 8;
      default:
        throw ArgumentError('unsupported FC 0x${fc.toRadixString(16)}');
    }
  }

  @override
  Future<List<bool>> readCoil(int unitId, int addr, int qty) =>
      _readBitsInternal(unitId, addr, qty, 0x01);

  @override
  Future<List<bool>> readCoilIn(int unitId, int addr, int qty) =>
      _readBitsInternal(unitId, addr, qty, 0x02);

  @override
  Future<List<int>> readReg(int unitId, int addr, int qty) =>
      _readRegsInternal(unitId, addr, qty, 0x03);

  @override
  Future<List<int>> readRegIn(int unitId, int addr, int qty) =>
      _readRegsInternal(unitId, addr, qty, 0x04);

  @override
  Future<void> writeCoil(int unitId, int addr, bool value) async {
    final pdu = Uint8List.fromList([
      0x05,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      value ? 0xFF : 0x00,
      0x00,
    ]);
    await _query(unitId, pdu, _expectedRespLen(0x05, 0));
  }

  @override
  Future<void> writeReg(int unitId, int addr, int value) async {
    final pdu = Uint8List.fromList([
      0x06,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ]);
    await _query(unitId, pdu, _expectedRespLen(0x06, 0));
  }

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
      0x0F,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (values.length >> 8) & 0xFF,
      values.length & 0xFF,
      byteCount,
      ...coilBytes,
    ]);
    await _query(unitId, pdu, _expectedRespLen(0x0F, 0));
  }

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
      0x10,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (values.length >> 8) & 0xFF,
      values.length & 0xFF,
      byteCount,
      ...regBytes,
    ]);
    await _query(unitId, pdu, _expectedRespLen(0x10, 0));
  }

  Future<List<bool>> _readBitsInternal(
      int unitId, int addr, int qty, int fc) async {
    final pdu = Uint8List.fromList([
      fc,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (qty >> 8) & 0xFF,
      qty & 0xFF,
    ]);
    final res = await _query(unitId, pdu, _expectedRespLen(fc, qty));
    // res = [slaveId, fc, byteCount, ...data] — same shape as TCP.
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
      fc,
      (addr >> 8) & 0xFF,
      addr & 0xFF,
      (qty >> 8) & 0xFF,
      qty & 0xFF,
    ]);
    final res = await _query(unitId, pdu, _expectedRespLen(fc, qty));
    final out = List<int>.filled(qty, 0);
    for (var i = 0; i < qty; i++) {
      out[i] = (res[3 + i * 2] << 8) | res[4 + i * 2];
    }
    return out;
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  /// Run [body] under the write mutex, honouring [minRequestGapMs].
  Future<T> _serialized<T>(Future<T> Function() body) async {
    final prev = _writeLock;
    final myTurn = Completer<void>();
    _writeLock = myTurn.future;
    await prev;
    try {
      if (minRequestGapMs > 0) {
        final since =
            DateTime.now().difference(_lastRequestAt).inMilliseconds;
        if (since < minRequestGapMs) {
          await Future<void>.delayed(
              Duration(milliseconds: minRequestGapMs - since));
        }
      }
      _lastRequestAt = DateTime.now();
      return await body();
    } finally {
      myTurn.complete();
    }
  }

  /// Send a request, await the matching response. Returns the bytes
  /// `[slaveId, fc, ...payload]` (CRC stripped).
  ///
  /// [expectedLen] is the full on-wire response length **including** CRC for
  /// the normal (non-exception) case. An exception response is always 5 bytes.
  Future<Uint8List> _query(int slaveId, Uint8List pdu, int expectedLen) {
    return _serialized(() => _queryRaw(slaveId, pdu, expectedLen));
  }

  Future<Uint8List> _queryRaw(int slaveId, Uint8List pdu, int expectedLen) async {
    final p = _port;
    if (p == null || !p.isOpen) throw const MbDisconnect();

    // Build frame: [slaveId, ...pdu] + CRC.
    final body = Uint8List(1 + pdu.length);
    body[0] = slaveId;
    body.setRange(1, body.length, pdu);
    final frame = Crc16.append(body);

    // Reset rx state for the new request.
    _rxBuf = BytesBuilder(copy: false);
    _expectedLen = expectedLen;
    final completer = Completer<Uint8List>();
    _pending = completer;

    final written = p.write(frame, timeout: timeout.inMilliseconds);
    if (written != frame.length) {
      _pending = null;
      throw MbDisconnect('Short write: $written/${frame.length}');
    }
    _rawCtrl.add(RawPacket(
      time: DateTime.now(),
      isTx: true,
      bytes: frame,
      transport: ModbusTransport.rtu,
    ));

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      if (_pending == completer) _pending = null;
      throw const MbNoResponse();
    }
  }

  void _onData(Uint8List chunk) {
    _rxBuf.add(chunk);
    final bytes = _rxBuf.toBytes();

    // Exception responses are always 5 bytes: slaveId + (FC|0x80) + code + CRC(2).
    // As soon as we know the FC byte and it has the high bit set, shrink the
    // expected length so we don't sit waiting for a normal-shaped reply.
    if (bytes.length >= 2 && (bytes[1] & 0x80) != 0) {
      _expectedLen = 5;
    }

    if (_expectedLen == 0 || bytes.length < _expectedLen) return;

    final frame = Uint8List.fromList(bytes.sublist(0, _expectedLen));
    // Anything extra is garbage / stale; drop it. RTU has no framing markers
    // so we can't safely keep it for the next request anyway.
    _rxBuf = BytesBuilder(copy: false);
    _expectedLen = 0;

    _rawCtrl.add(RawPacket(
      time: DateTime.now(),
      isTx: false,
      bytes: frame,
      transport: ModbusTransport.rtu,
    ));

    final completer = _pending;
    _pending = null;
    if (completer == null || completer.isCompleted) return;

    if (!Crc16.check(frame)) {
      completer.completeError(
          const MbModbusError('CRC check failed'));
      return;
    }

    final fc = frame[1];
    if ((fc & 0x80) != 0) {
      completer.completeError(MbModbusError.fromCode(frame[2]));
      return;
    }

    // Drop the trailing 2 CRC bytes; keep [slaveId, fc, ...payload].
    completer.complete(Uint8List.sublistView(frame, 0, frame.length - 2));
  }
}
