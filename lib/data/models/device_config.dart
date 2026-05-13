import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/modbus/modbus_transport.dart';
import '../../core/modbus/serial_parity.dart';

export '../../core/modbus/modbus_transport.dart' show ModbusTransport;
export '../../core/modbus/serial_parity.dart' show SerialParity;

part 'device_config.freezed.dart';
part 'device_config.g.dart';

@freezed
abstract class DeviceConfig with _$DeviceConfig {
  const factory DeviceConfig({
    required String id,
    required String name,
    @Default(ModbusTransport.tcp) ModbusTransport transport,

    // ── TCP ──
    @Default('') String host,
    @Default(502) int port,

    // ── RTU ──
    /// Platform-native serial port path. e.g. `COM3` (Windows),
    /// `/dev/cu.usbserial-110` (macOS), `/dev/ttyUSB0` (Linux).
    @Default('') String serialPort,
    @Default(9600) int baudRate,
    @Default(8) int dataBits,
    @Default(1) int stopBits,
    @Default(SerialParity.none) SerialParity parity,

    // ── shared ──
    @Default(2000) int timeoutMs,
    @Default(2) int retries,

    /// Device-level polling cycle. Each cycle queries every watch on this
    /// device in sequence; back-to-back requests within a cycle are still
    /// gated by [minRequestGapMs]. If a cycle takes longer than this, the
    /// next cycle starts immediately with no extra wait.
    @Default(1000) int pollIntervalMs,

    /// One in-flight request at a time. Default ON because most MCU-class
    /// slaves (ESP32, Arduino, RS-485 gateway-fronted PLCs) can't handle
    /// concurrent transactions. Disable for capable PLCs to allow parallel
    /// requests demuxed by transaction id. RTU is always serialized
    /// regardless of this flag (half-duplex bus).
    @Default(true) bool serializeRequests,
    @Default(true) bool autoReconnect,

    /// Minimum gap (ms) between successive requests on this device's
    /// connection. 0 = no throttling. Default 100 to give slow slaves
    /// breathing room.
    @Default(100) int minRequestGapMs,
  }) = _DeviceConfig;

  factory DeviceConfig.fromJson(Map<String, dynamic> json) =>
      _$DeviceConfigFromJson(json);
}

extension DeviceConfigDisplay on DeviceConfig {
  /// One-line endpoint summary for sidebar / header. Format depends on
  /// transport:
  ///   * TCP — `192.168.1.10:502`
  ///   * RTU — `COM3 @ 9600 8N1`  (port @ baud + dataBits + parityChar + stopBits)
  String get addressLine {
    switch (transport) {
      case ModbusTransport.tcp:
        return '$host:$port';
      case ModbusTransport.rtu:
        final p = serialPort.isEmpty ? '(no port)' : serialPort;
        return '$p @ $baudRate $dataBits${_parityChar(parity)}$stopBits';
    }
  }

  /// Short tag for the transport chip — `TCP` or `RTU`.
  String get transportTag {
    switch (transport) {
      case ModbusTransport.tcp:
        return 'TCP';
      case ModbusTransport.rtu:
        return 'RTU';
    }
  }
}

String _parityChar(SerialParity p) => switch (p) {
      SerialParity.none => 'N',
      SerialParity.even => 'E',
      SerialParity.odd => 'O',
    };
