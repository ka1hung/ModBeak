// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watch_window.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WatchWindow {

 String get id; String get name; PaneLayout get layout; double get x; double get y; double get width; double get height;
/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchWindowCopyWith<WatchWindow> get copyWith => _$WatchWindowCopyWithImpl<WatchWindow>(this as WatchWindow, _$identity);

  /// Serializes this WatchWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatchWindow&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,layout,x,y,width,height);

@override
String toString() {
  return 'WatchWindow(id: $id, name: $name, layout: $layout, x: $x, y: $y, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $WatchWindowCopyWith<$Res>  {
  factory $WatchWindowCopyWith(WatchWindow value, $Res Function(WatchWindow) _then) = _$WatchWindowCopyWithImpl;
@useResult
$Res call({
 String id, String name, PaneLayout layout, double x, double y, double width, double height
});


$PaneLayoutCopyWith<$Res> get layout;

}
/// @nodoc
class _$WatchWindowCopyWithImpl<$Res>
    implements $WatchWindowCopyWith<$Res> {
  _$WatchWindowCopyWithImpl(this._self, this._then);

  final WatchWindow _self;
  final $Res Function(WatchWindow) _then;

/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? layout = null,Object? x = null,Object? y = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as PaneLayout,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaneLayoutCopyWith<$Res> get layout {
  
  return $PaneLayoutCopyWith<$Res>(_self.layout, (value) {
    return _then(_self.copyWith(layout: value));
  });
}
}


/// Adds pattern-matching-related methods to [WatchWindow].
extension WatchWindowPatterns on WatchWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatchWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatchWindow() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatchWindow value)  $default,){
final _that = this;
switch (_that) {
case _WatchWindow():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatchWindow value)?  $default,){
final _that = this;
switch (_that) {
case _WatchWindow() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  PaneLayout layout,  double x,  double y,  double width,  double height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatchWindow() when $default != null:
return $default(_that.id,_that.name,_that.layout,_that.x,_that.y,_that.width,_that.height);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  PaneLayout layout,  double x,  double y,  double width,  double height)  $default,) {final _that = this;
switch (_that) {
case _WatchWindow():
return $default(_that.id,_that.name,_that.layout,_that.x,_that.y,_that.width,_that.height);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  PaneLayout layout,  double x,  double y,  double width,  double height)?  $default,) {final _that = this;
switch (_that) {
case _WatchWindow() when $default != null:
return $default(_that.id,_that.name,_that.layout,_that.x,_that.y,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WatchWindow implements WatchWindow {
  const _WatchWindow({required this.id, required this.name, required this.layout, this.x = 0, this.y = 0, this.width = 900, this.height = 600});
  factory _WatchWindow.fromJson(Map<String, dynamic> json) => _$WatchWindowFromJson(json);

@override final  String id;
@override final  String name;
@override final  PaneLayout layout;
@override@JsonKey() final  double x;
@override@JsonKey() final  double y;
@override@JsonKey() final  double width;
@override@JsonKey() final  double height;

/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchWindowCopyWith<_WatchWindow> get copyWith => __$WatchWindowCopyWithImpl<_WatchWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WatchWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatchWindow&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,layout,x,y,width,height);

@override
String toString() {
  return 'WatchWindow(id: $id, name: $name, layout: $layout, x: $x, y: $y, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$WatchWindowCopyWith<$Res> implements $WatchWindowCopyWith<$Res> {
  factory _$WatchWindowCopyWith(_WatchWindow value, $Res Function(_WatchWindow) _then) = __$WatchWindowCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, PaneLayout layout, double x, double y, double width, double height
});


@override $PaneLayoutCopyWith<$Res> get layout;

}
/// @nodoc
class __$WatchWindowCopyWithImpl<$Res>
    implements _$WatchWindowCopyWith<$Res> {
  __$WatchWindowCopyWithImpl(this._self, this._then);

  final _WatchWindow _self;
  final $Res Function(_WatchWindow) _then;

/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? layout = null,Object? x = null,Object? y = null,Object? width = null,Object? height = null,}) {
  return _then(_WatchWindow(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as PaneLayout,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as double,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of WatchWindow
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaneLayoutCopyWith<$Res> get layout {
  
  return $PaneLayoutCopyWith<$Res>(_self.layout, (value) {
    return _then(_self.copyWith(layout: value));
  });
}
}

// dart format on
