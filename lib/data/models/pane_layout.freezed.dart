// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pane_layout.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
PaneLayout _$PaneLayoutFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'leaf':
          return LeafPane.fromJson(
            json
          );
                case 'split':
          return SplitPane.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'PaneLayout',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$PaneLayout {



  /// Serializes this PaneLayout to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaneLayout);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'PaneLayout()';
}


}

/// @nodoc
class $PaneLayoutCopyWith<$Res>  {
$PaneLayoutCopyWith(PaneLayout _, $Res Function(PaneLayout) __);
}


/// Adds pattern-matching-related methods to [PaneLayout].
extension PaneLayoutPatterns on PaneLayout {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LeafPane value)?  leaf,TResult Function( SplitPane value)?  split,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LeafPane() when leaf != null:
return leaf(_that);case SplitPane() when split != null:
return split(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LeafPane value)  leaf,required TResult Function( SplitPane value)  split,}){
final _that = this;
switch (_that) {
case LeafPane():
return leaf(_that);case SplitPane():
return split(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LeafPane value)?  leaf,TResult? Function( SplitPane value)?  split,}){
final _that = this;
switch (_that) {
case LeafPane() when leaf != null:
return leaf(_that);case SplitPane() when split != null:
return split(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String paneId,  WatchSpec watch)?  leaf,TResult Function( SplitDirection direction,  List<PaneLayout> children,  List<double> ratios)?  split,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LeafPane() when leaf != null:
return leaf(_that.paneId,_that.watch);case SplitPane() when split != null:
return split(_that.direction,_that.children,_that.ratios);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String paneId,  WatchSpec watch)  leaf,required TResult Function( SplitDirection direction,  List<PaneLayout> children,  List<double> ratios)  split,}) {final _that = this;
switch (_that) {
case LeafPane():
return leaf(_that.paneId,_that.watch);case SplitPane():
return split(_that.direction,_that.children,_that.ratios);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String paneId,  WatchSpec watch)?  leaf,TResult? Function( SplitDirection direction,  List<PaneLayout> children,  List<double> ratios)?  split,}) {final _that = this;
switch (_that) {
case LeafPane() when leaf != null:
return leaf(_that.paneId,_that.watch);case SplitPane() when split != null:
return split(_that.direction,_that.children,_that.ratios);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class LeafPane implements PaneLayout {
  const LeafPane({required this.paneId, required this.watch, final  String? $type}): $type = $type ?? 'leaf';
  factory LeafPane.fromJson(Map<String, dynamic> json) => _$LeafPaneFromJson(json);

 final  String paneId;
 final  WatchSpec watch;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PaneLayout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeafPaneCopyWith<LeafPane> get copyWith => _$LeafPaneCopyWithImpl<LeafPane>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeafPaneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeafPane&&(identical(other.paneId, paneId) || other.paneId == paneId)&&(identical(other.watch, watch) || other.watch == watch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,paneId,watch);

@override
String toString() {
  return 'PaneLayout.leaf(paneId: $paneId, watch: $watch)';
}


}

/// @nodoc
abstract mixin class $LeafPaneCopyWith<$Res> implements $PaneLayoutCopyWith<$Res> {
  factory $LeafPaneCopyWith(LeafPane value, $Res Function(LeafPane) _then) = _$LeafPaneCopyWithImpl;
@useResult
$Res call({
 String paneId, WatchSpec watch
});


$WatchSpecCopyWith<$Res> get watch;

}
/// @nodoc
class _$LeafPaneCopyWithImpl<$Res>
    implements $LeafPaneCopyWith<$Res> {
  _$LeafPaneCopyWithImpl(this._self, this._then);

  final LeafPane _self;
  final $Res Function(LeafPane) _then;

/// Create a copy of PaneLayout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? paneId = null,Object? watch = null,}) {
  return _then(LeafPane(
paneId: null == paneId ? _self.paneId : paneId // ignore: cast_nullable_to_non_nullable
as String,watch: null == watch ? _self.watch : watch // ignore: cast_nullable_to_non_nullable
as WatchSpec,
  ));
}

/// Create a copy of PaneLayout
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WatchSpecCopyWith<$Res> get watch {
  
  return $WatchSpecCopyWith<$Res>(_self.watch, (value) {
    return _then(_self.copyWith(watch: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class SplitPane implements PaneLayout {
  const SplitPane({required this.direction, required final  List<PaneLayout> children, required final  List<double> ratios, final  String? $type}): _children = children,_ratios = ratios,$type = $type ?? 'split';
  factory SplitPane.fromJson(Map<String, dynamic> json) => _$SplitPaneFromJson(json);

 final  SplitDirection direction;
 final  List<PaneLayout> _children;
 List<PaneLayout> get children {
  if (_children is EqualUnmodifiableListView) return _children;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_children);
}

 final  List<double> _ratios;
 List<double> get ratios {
  if (_ratios is EqualUnmodifiableListView) return _ratios;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ratios);
}


@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of PaneLayout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SplitPaneCopyWith<SplitPane> get copyWith => _$SplitPaneCopyWithImpl<SplitPane>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SplitPaneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SplitPane&&(identical(other.direction, direction) || other.direction == direction)&&const DeepCollectionEquality().equals(other._children, _children)&&const DeepCollectionEquality().equals(other._ratios, _ratios));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,direction,const DeepCollectionEquality().hash(_children),const DeepCollectionEquality().hash(_ratios));

@override
String toString() {
  return 'PaneLayout.split(direction: $direction, children: $children, ratios: $ratios)';
}


}

/// @nodoc
abstract mixin class $SplitPaneCopyWith<$Res> implements $PaneLayoutCopyWith<$Res> {
  factory $SplitPaneCopyWith(SplitPane value, $Res Function(SplitPane) _then) = _$SplitPaneCopyWithImpl;
@useResult
$Res call({
 SplitDirection direction, List<PaneLayout> children, List<double> ratios
});




}
/// @nodoc
class _$SplitPaneCopyWithImpl<$Res>
    implements $SplitPaneCopyWith<$Res> {
  _$SplitPaneCopyWithImpl(this._self, this._then);

  final SplitPane _self;
  final $Res Function(SplitPane) _then;

/// Create a copy of PaneLayout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? direction = null,Object? children = null,Object? ratios = null,}) {
  return _then(SplitPane(
direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as SplitDirection,children: null == children ? _self._children : children // ignore: cast_nullable_to_non_nullable
as List<PaneLayout>,ratios: null == ratios ? _self._ratios : ratios // ignore: cast_nullable_to_non_nullable
as List<double>,
  ));
}


}

// dart format on
