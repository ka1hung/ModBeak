import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Minimal in-process Modbus TCP server for unit testing [MbClient].
///
/// The server is hand-crafted (not a real Modbus implementation) so that
/// tests can:
///   - inspect the bytes the client sent (via [lastRequest]),
///   - return whatever bytes they want (via [enqueueResponse]),
///   - simulate timeouts and disconnects.
class FakeModbusServer {
  late ServerSocket _server;
  Socket? _client;
  final List<Uint8List> _requestLog = [];
  final List<_QueuedResponse> _queue = [];

  /// Frames received from the client, in order.
  List<Uint8List> get requests => List.unmodifiable(_requestLog);

  /// Most recent frame the client sent.
  Uint8List get lastRequest => _requestLog.last;

  int get port => _server.port;

  static Future<FakeModbusServer> start() async {
    final s = FakeModbusServer();
    s._server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    s._server.listen((sock) {
      s._client = sock;
      sock.listen(s._onData,
          onError: (_, [stack]) {}, onDone: () => s._client = null);
    });
    return s;
  }

  Future<void> close() async {
    await _client?.close();
    await _server.close();
  }

  /// Forces the active connection to drop, simulating a slave crash.
  Future<void> dropConnection() async {
    final c = _client;
    _client = null;
    c?.destroy();
  }

  /// Queue a canned response. [respondToTid] picks the transaction id to
  /// echo back (defaults to mirroring whatever request matches it next).
  void enqueueResponse(Uint8List pduWithUnitId, {int? respondToTid}) {
    _queue.add(_QueuedResponse(pduWithUnitId, respondToTid));
  }

  /// Queue a raw frame (already-built MBAP + PDU). Useful for testing how
  /// the client handles malformed data.
  void enqueueRawFrame(Uint8List frame) {
    _queue.add(_QueuedResponse._raw(frame));
  }

  /// Don't respond at all — used to test timeouts.
  void enqueueSilence() {
    _queue.add(_QueuedResponse._silent());
  }

  Uint8List _rxBuffer = Uint8List(0);

  void _onData(Uint8List data) {
    // Append and drain — TCP may coalesce multiple frames into one read.
    final merged = Uint8List(_rxBuffer.length + data.length)
      ..setRange(0, _rxBuffer.length, _rxBuffer)
      ..setRange(_rxBuffer.length, _rxBuffer.length + data.length, data);
    _rxBuffer = merged;

    while (_rxBuffer.length >= 8) {
      final length = (_rxBuffer[4] << 8) | _rxBuffer[5];
      final total = 6 + length;
      if (_rxBuffer.length < total) break;

      final frame = Uint8List.fromList(
          Uint8List.sublistView(_rxBuffer, 0, total));
      _rxBuffer = Uint8List.fromList(Uint8List.sublistView(_rxBuffer, total));

      _requestLog.add(frame);
      _respond(frame);
    }
  }

  void _respond(Uint8List requestFrame) {
    if (_queue.isEmpty) return;
    final next = _queue.removeAt(0);

    if (next.silent) return;
    if (next.rawFrame != null) {
      _client?.add(next.rawFrame!);
      return;
    }

    final tid =
        next.respondToTid ?? ((requestFrame[0] << 8) | requestFrame[1]);
    final pdu = next.pduWithUnitId!;
    final out = Uint8List(6 + pdu.length);
    out[0] = (tid >> 8) & 0xFF;
    out[1] = tid & 0xFF;
    out[2] = 0;
    out[3] = 0;
    out[4] = (pdu.length >> 8) & 0xFF;
    out[5] = pdu.length & 0xFF;
    out.setRange(6, 6 + pdu.length, pdu);
    _client?.add(out);
  }
}

class _QueuedResponse {
  final Uint8List? pduWithUnitId;
  final int? respondToTid;
  final Uint8List? rawFrame;
  final bool silent;

  _QueuedResponse(this.pduWithUnitId, this.respondToTid)
      : rawFrame = null,
        silent = false;

  _QueuedResponse._raw(this.rawFrame)
      : pduWithUnitId = null,
        respondToTid = null,
        silent = false;

  _QueuedResponse._silent()
      : pduWithUnitId = null,
        respondToTid = null,
        rawFrame = null,
        silent = true;
}
