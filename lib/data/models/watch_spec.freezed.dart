// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'watch_spec.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WatchSpec {

 String get id; String get deviceId; int get unitId; int get functionCode;// 1, 2, 3 or 4
 int get startAddress; int get quantity; RegisterFormat get format; int get asciiCharsPerRow;/// If true, this watch is skipped in the device's polling cycle. Manual
/// refresh (via `refreshOnce`) still works.
 bool get manualOnly;
/// Create a copy of WatchSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WatchSpecCopyWith<WatchSpec> get copyWith => _$WatchSpecCopyWithImpl<WatchSpec>(this as WatchSpec, _$identity);

  /// Serializes this WatchSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WatchSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.unitId, unitId) || other.unitId == unitId)&&(identical(other.functionCode, functionCode) || other.functionCode == functionCode)&&(identical(other.startAddress, startAddress) || other.startAddress == startAddress)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.format, format) || other.format == format)&&(identical(other.asciiCharsPerRow, asciiCharsPerRow) || other.asciiCharsPerRow == asciiCharsPerRow)&&(identical(other.manualOnly, manualOnly) || other.manualOnly == manualOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,unitId,functionCode,startAddress,quantity,format,asciiCharsPerRow,manualOnly);

@override
String toString() {
  return 'WatchSpec(id: $id, deviceId: $deviceId, unitId: $unitId, functionCode: $functionCode, startAddress: $startAddress, quantity: $quantity, format: $format, asciiCharsPerRow: $asciiCharsPerRow, manualOnly: $manualOnly)';
}


}

/// @nodoc
abstract mixin class $WatchSpecCopyWith<$Res>  {
  factory $WatchSpecCopyWith(WatchSpec value, $Res Function(WatchSpec) _then) = _$WatchSpecCopyWithImpl;
@useResult
$Res call({
 String id, String deviceId, int unitId, int functionCode, int startAddress, int quantity, RegisterFormat format, int asciiCharsPerRow, bool manualOnly
});




}
/// @nodoc
class _$WatchSpecCopyWithImpl<$Res>
    implements $WatchSpecCopyWith<$Res> {
  _$WatchSpecCopyWithImpl(this._self, this._then);

  final WatchSpec _self;
  final $Res Function(WatchSpec) _then;

/// Create a copy of WatchSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? deviceId = null,Object? unitId = null,Object? functionCode = null,Object? startAddress = null,Object? quantity = null,Object? format = null,Object? asciiCharsPerRow = null,Object? manualOnly = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,unitId: null == unitId ? _self.unitId : unitId // ignore: cast_nullable_to_non_nullable
as int,functionCode: null == functionCode ? _self.functionCode : functionCode // ignore: cast_nullable_to_non_nullable
as int,startAddress: null == startAddress ? _self.startAddress : startAddress // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as RegisterFormat,asciiCharsPerRow: null == asciiCharsPerRow ? _self.asciiCharsPerRow : asciiCharsPerRow // ignore: cast_nullable_to_non_nullable
as int,manualOnly: null == manualOnly ? _self.manualOnly : manualOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WatchSpec].
extension WatchSpecPatterns on WatchSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WatchSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WatchSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WatchSpec value)  $default,){
final _that = this;
switch (_that) {
case _WatchSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WatchSpec value)?  $default,){
final _that = this;
switch (_that) {
case _WatchSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String deviceId,  int unitId,  int functionCode,  int startAddress,  int quantity,  RegisterFormat format,  int asciiCharsPerRow,  bool manualOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WatchSpec() when $default != null:
return $default(_that.id,_that.deviceId,_that.unitId,_that.functionCode,_that.startAddress,_that.quantity,_that.format,_that.asciiCharsPerRow,_that.manualOnly);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String deviceId,  int unitId,  int functionCode,  int startAddress,  int quantity,  RegisterFormat format,  int asciiCharsPerRow,  bool manualOnly)  $default,) {final _that = this;
switch (_that) {
case _WatchSpec():
return $default(_that.id,_that.deviceId,_that.unitId,_that.functionCode,_that.startAddress,_that.quantity,_that.format,_that.asciiCharsPerRow,_that.manualOnly);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String deviceId,  int unitId,  int functionCode,  int startAddress,  int quantity,  RegisterFormat format,  int asciiCharsPerRow,  bool manualOnly)?  $default,) {final _that = this;
switch (_that) {
case _WatchSpec() when $default != null:
return $default(_that.id,_that.deviceId,_that.unitId,_that.functionCode,_that.startAddress,_that.quantity,_that.format,_that.asciiCharsPerRow,_that.manualOnly);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WatchSpec implements WatchSpec {
  const _WatchSpec({required this.id, required this.deviceId, required this.unitId, required this.functionCode, required this.startAddress, required this.quantity, this.format = RegisterFormat.u16, this.asciiCharsPerRow = 8, this.manualOnly = false});
  factory _WatchSpec.fromJson(Map<String, dynamic> json) => _$WatchSpecFromJson(json);

@override final  String id;
@override final  String deviceId;
@override final  int unitId;
@override final  int functionCode;
// 1, 2, 3 or 4
@override final  int startAddress;
@override final  int quantity;
@override@JsonKey() final  RegisterFormat format;
@override@JsonKey() final  int asciiCharsPerRow;
/// If true, this watch is skipped in the device's polling cycle. Manual
/// refresh (via `refreshOnce`) still works.
@override@JsonKey() final  bool manualOnly;

/// Create a copy of WatchSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WatchSpecCopyWith<_WatchSpec> get copyWith => __$WatchSpecCopyWithImpl<_WatchSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WatchSpecToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WatchSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.unitId, unitId) || other.unitId == unitId)&&(identical(other.functionCode, functionCode) || other.functionCode == functionCode)&&(identical(other.startAddress, startAddress) || other.startAddress == startAddress)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.format, format) || other.format == format)&&(identical(other.asciiCharsPerRow, asciiCharsPerRow) || other.asciiCharsPerRow == asciiCharsPerRow)&&(identical(other.manualOnly, manualOnly) || other.manualOnly == manualOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,deviceId,unitId,functionCode,startAddress,quantity,format,asciiCharsPerRow,manualOnly);

@override
String toString() {
  return 'WatchSpec(id: $id, deviceId: $deviceId, unitId: $unitId, functionCode: $functionCode, startAddress: $startAddress, quantity: $quantity, format: $format, asciiCharsPerRow: $asciiCharsPerRow, manualOnly: $manualOnly)';
}


}

/// @nodoc
abstract mixin class _$WatchSpecCopyWith<$Res> implements $WatchSpecCopyWith<$Res> {
  factory _$WatchSpecCopyWith(_WatchSpec value, $Res Function(_WatchSpec) _then) = __$WatchSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String deviceId, int unitId, int functionCode, int startAddress, int quantity, RegisterFormat format, int asciiCharsPerRow, bool manualOnly
});




}
/// @nodoc
class __$WatchSpecCopyWithImpl<$Res>
    implements _$WatchSpecCopyWith<$Res> {
  __$WatchSpecCopyWithImpl(this._self, this._then);

  final _WatchSpec _self;
  final $Res Function(_WatchSpec) _then;

/// Create a copy of WatchSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? deviceId = null,Object? unitId = null,Object? functionCode = null,Object? startAddress = null,Object? quantity = null,Object? format = null,Object? asciiCharsPerRow = null,Object? manualOnly = null,}) {
  return _then(_WatchSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,unitId: null == unitId ? _self.unitId : unitId // ignore: cast_nullable_to_non_nullable
as int,functionCode: null == functionCode ? _self.functionCode : functionCode // ignore: cast_nullable_to_non_nullable
as int,startAddress: null == startAddress ? _self.startAddress : startAddress // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as RegisterFormat,asciiCharsPerRow: null == asciiCharsPerRow ? _self.asciiCharsPerRow : asciiCharsPerRow // ignore: cast_nullable_to_non_nullable
as int,manualOnly: null == manualOnly ? _self.manualOnly : manualOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
