// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watch_window.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WatchWindow _$WatchWindowFromJson(Map<String, dynamic> json) => _WatchWindow(
  id: json['id'] as String,
  name: json['name'] as String,
  layout: PaneLayout.fromJson(json['layout'] as Map<String, dynamic>),
  x: (json['x'] as num?)?.toDouble() ?? 0,
  y: (json['y'] as num?)?.toDouble() ?? 0,
  width: (json['width'] as num?)?.toDouble() ?? 900,
  height: (json['height'] as num?)?.toDouble() ?? 600,
);

Map<String, dynamic> _$WatchWindowToJson(_WatchWindow instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'layout': instance.layout,
      'x': instance.x,
      'y': instance.y,
      'width': instance.width,
      'height': instance.height,
    };
