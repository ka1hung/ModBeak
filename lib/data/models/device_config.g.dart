// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeviceConfig _$DeviceConfigFromJson(Map<String, dynamic> json) =>
    _DeviceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      transport:
          $enumDecodeNullable(_$ModbusTransportEnumMap, json['transport']) ??
          ModbusTransport.tcp,
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 502,
      serialPort: json['serialPort'] as String? ?? '',
      baudRate: (json['baudRate'] as num?)?.toInt() ?? 9600,
      dataBits: (json['dataBits'] as num?)?.toInt() ?? 8,
      stopBits: (json['stopBits'] as num?)?.toInt() ?? 1,
      parity:
          $enumDecodeNullable(_$SerialParityEnumMap, json['parity']) ??
          SerialParity.none,
      timeoutMs: (json['timeoutMs'] as num?)?.toInt() ?? 2000,
      retries: (json['retries'] as num?)?.toInt() ?? 2,
      pollIntervalMs: (json['pollIntervalMs'] as num?)?.toInt() ?? 1000,
      serializeRequests: json['serializeRequests'] as bool? ?? true,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      minRequestGapMs: (json['minRequestGapMs'] as num?)?.toInt() ?? 100,
    );

Map<String, dynamic> _$DeviceConfigToJson(_DeviceConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'transport': _$ModbusTransportEnumMap[instance.transport]!,
      'host': instance.host,
      'port': instance.port,
      'serialPort': instance.serialPort,
      'baudRate': instance.baudRate,
      'dataBits': instance.dataBits,
      'stopBits': instance.stopBits,
      'parity': _$SerialParityEnumMap[instance.parity]!,
      'timeoutMs': instance.timeoutMs,
      'retries': instance.retries,
      'pollIntervalMs': instance.pollIntervalMs,
      'serializeRequests': instance.serializeRequests,
      'autoReconnect': instance.autoReconnect,
      'minRequestGapMs': instance.minRequestGapMs,
    };

const _$ModbusTransportEnumMap = {
  ModbusTransport.tcp: 'tcp',
  ModbusTransport.rtu: 'rtu',
};

const _$SerialParityEnumMap = {
  SerialParity.none: 'none',
  SerialParity.even: 'even',
  SerialParity.odd: 'odd',
};
