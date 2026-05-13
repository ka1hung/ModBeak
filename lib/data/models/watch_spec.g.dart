// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_spec.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WatchSpec _$WatchSpecFromJson(Map<String, dynamic> json) => _WatchSpec(
  id: json['id'] as String,
  deviceId: json['deviceId'] as String,
  unitId: (json['unitId'] as num).toInt(),
  functionCode: (json['functionCode'] as num).toInt(),
  startAddress: (json['startAddress'] as num).toInt(),
  quantity: (json['quantity'] as num).toInt(),
  format:
      $enumDecodeNullable(_$RegisterFormatEnumMap, json['format']) ??
      RegisterFormat.u16,
  asciiCharsPerRow: (json['asciiCharsPerRow'] as num?)?.toInt() ?? 8,
  manualOnly: json['manualOnly'] as bool? ?? false,
);

Map<String, dynamic> _$WatchSpecToJson(_WatchSpec instance) =>
    <String, dynamic>{
      'id': instance.id,
      'deviceId': instance.deviceId,
      'unitId': instance.unitId,
      'functionCode': instance.functionCode,
      'startAddress': instance.startAddress,
      'quantity': instance.quantity,
      'format': _$RegisterFormatEnumMap[instance.format]!,
      'asciiCharsPerRow': instance.asciiCharsPerRow,
      'manualOnly': instance.manualOnly,
    };

const _$RegisterFormatEnumMap = {
  RegisterFormat.u16: 'u16',
  RegisterFormat.i16: 'i16',
  RegisterFormat.hex: 'hex',
  RegisterFormat.bin: 'bin',
  RegisterFormat.u32be: 'u32be',
  RegisterFormat.u32le: 'u32le',
  RegisterFormat.i32be: 'i32be',
  RegisterFormat.i32le: 'i32le',
  RegisterFormat.f32be: 'f32be',
  RegisterFormat.f32le: 'f32le',
  RegisterFormat.ascii: 'ascii',
  RegisterFormat.bool_: 'bool_',
};
