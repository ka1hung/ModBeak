/// Which Modbus transport a device speaks. Lives in core/modbus so that
/// low-level types (e.g. [RawPacket]) can tag themselves without taking a
/// dependency on the higher-level [DeviceConfig] layer.
enum ModbusTransport { tcp, rtu }
