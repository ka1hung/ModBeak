import 'package:flutter_test/flutter_test.dart';
import 'package:modbeak/data/models/device_config.dart';

void main() {
  group('DeviceConfig — JSON back-compat', () {
    test('legacy config without transport field defaults to TCP', () {
      // This is the JSON shape produced by the app before R4 added the
      // transport / RTU fields. It must still load with sensible defaults.
      final legacy = <String, dynamic>{
        'id': 'd1',
        'name': 'Legacy PLC',
        'host': '192.168.1.10',
        'port': 502,
        'timeoutMs': 1500,
        'retries': 1,
        'serializeRequests': true,
        'autoReconnect': true,
        'minRequestGapMs': 50,
      };
      final cfg = DeviceConfig.fromJson(legacy);
      expect(cfg.transport, ModbusTransport.tcp);
      expect(cfg.host, '192.168.1.10');
      expect(cfg.port, 502);
      expect(cfg.serialPort, ''); // default
      expect(cfg.baudRate, 9600); // default
      expect(cfg.parity, SerialParity.none); // default
    });

    test('round-trips RTU config', () {
      final cfg = DeviceConfig(
        id: 'rtu1',
        name: 'RTU sensor',
        transport: ModbusTransport.rtu,
        serialPort: 'COM3',
        baudRate: 19200,
        dataBits: 8,
        stopBits: 1,
        parity: SerialParity.even,
        timeoutMs: 3000,
      );
      final json = cfg.toJson();
      final restored = DeviceConfig.fromJson(json);
      expect(restored, cfg);
    });

    test('round-trips TCP config', () {
      final cfg = DeviceConfig(
        id: 'tcp1',
        name: 'PLC',
        host: '10.0.0.5',
        port: 1502,
      );
      final json = cfg.toJson();
      final restored = DeviceConfig.fromJson(json);
      expect(restored.transport, ModbusTransport.tcp);
      expect(restored, cfg);
    });
  });

  group('DeviceConfig — display helpers', () {
    test('TCP addressLine shows host:port', () {
      final cfg = DeviceConfig(
          id: 'd', name: 'd', host: '192.168.1.10', port: 502);
      expect(cfg.addressLine, '192.168.1.10:502');
      expect(cfg.transportTag, 'TCP');
    });

    test('RTU addressLine shows port @ baud N81', () {
      final cfg = DeviceConfig(
        id: 'd',
        name: 'd',
        transport: ModbusTransport.rtu,
        serialPort: 'COM3',
        baudRate: 9600,
        dataBits: 8,
        stopBits: 1,
        parity: SerialParity.none,
      );
      expect(cfg.addressLine, 'COM3 @ 9600 8N1');
      expect(cfg.transportTag, 'RTU');
    });

    test('RTU addressLine reflects parity char (E / O / N)', () {
      DeviceConfig mk(SerialParity p) => DeviceConfig(
            id: 'd',
            name: 'd',
            transport: ModbusTransport.rtu,
            serialPort: '/dev/ttyUSB0',
            baudRate: 19200,
            dataBits: 8,
            stopBits: 2,
            parity: p,
          );
      expect(mk(SerialParity.even).addressLine,
          '/dev/ttyUSB0 @ 19200 8E2');
      expect(mk(SerialParity.odd).addressLine,
          '/dev/ttyUSB0 @ 19200 8O2');
    });

    test('RTU addressLine handles missing port', () {
      final cfg = DeviceConfig(
        id: 'd',
        name: 'd',
        transport: ModbusTransport.rtu,
      );
      expect(cfg.addressLine, '(no port) @ 9600 8N1');
    });
  });
}
