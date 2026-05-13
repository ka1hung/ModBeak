// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pane_layout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeafPane _$LeafPaneFromJson(Map<String, dynamic> json) => LeafPane(
  paneId: json['paneId'] as String,
  watch: WatchSpec.fromJson(json['watch'] as Map<String, dynamic>),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$LeafPaneToJson(LeafPane instance) => <String, dynamic>{
  'paneId': instance.paneId,
  'watch': instance.watch,
  'runtimeType': instance.$type,
};

SplitPane _$SplitPaneFromJson(Map<String, dynamic> json) => SplitPane(
  direction: $enumDecode(_$SplitDirectionEnumMap, json['direction']),
  children: (json['children'] as List<dynamic>)
      .map((e) => PaneLayout.fromJson(e as Map<String, dynamic>))
      .toList(),
  ratios: (json['ratios'] as List<dynamic>)
      .map((e) => (e as num).toDouble())
      .toList(),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$SplitPaneToJson(SplitPane instance) => <String, dynamic>{
  'direction': _$SplitDirectionEnumMap[instance.direction]!,
  'children': instance.children,
  'ratios': instance.ratios,
  'runtimeType': instance.$type,
};

const _$SplitDirectionEnumMap = {
  SplitDirection.horizontal: 'horizontal',
  SplitDirection.vertical: 'vertical',
};
