// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'device_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeviceConfig {

 String get id; String get name; ModbusTransport get transport;// ── TCP ──
 String get host; int get port;// ── RTU ──
/// Platform-native serial port path. e.g. `COM3` (Windows),
/// `/dev/cu.usbserial-110` (macOS), `/dev/ttyUSB0` (Linux).
 String get serialPort; int get baudRate; int get dataBits; int get stopBits; SerialParity get parity;// ── shared ──
 int get timeoutMs; int get retries;/// Device-level polling cycle. Each cycle queries every watch on this
/// device in sequence; back-to-back requests within a cycle are still
/// gated by [minRequestGapMs]. If a cycle takes longer than this, the
/// next cycle starts immediately with no extra wait.
 int get pollIntervalMs;/// One in-flight request at a time. Default ON because most MCU-class
/// slaves (ESP32, Arduino, RS-485 gateway-fronted PLCs) can't handle
/// concurrent transactions. Disable for capable PLCs to allow parallel
/// requests demuxed by transaction id. RTU is always serialized
/// regardless of this flag (half-duplex bus).
 bool get serializeRequests; bool get autoReconnect;/// Minimum gap (ms) between successive requests on this device's
/// connection. 0 = no throttling. Default 100 to give slow slaves
/// breathing room.
 int get minRequestGapMs;
/// Create a copy of DeviceConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeviceConfigCopyWith<DeviceConfig> get copyWith => _$DeviceConfigCopyWithImpl<DeviceConfig>(this as DeviceConfig, _$identity);

  /// Serializes this DeviceConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeviceConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.serialPort, serialPort) || other.serialPort == serialPort)&&(identical(other.baudRate, baudRate) || other.baudRate == baudRate)&&(identical(other.dataBits, dataBits) || other.dataBits == dataBits)&&(identical(other.stopBits, stopBits) || other.stopBits == stopBits)&&(identical(other.parity, parity) || other.parity == parity)&&(identical(other.timeoutMs, timeoutMs) || other.timeoutMs == timeoutMs)&&(identical(other.retries, retries) || other.retries == retries)&&(identical(other.pollIntervalMs, pollIntervalMs) || other.pollIntervalMs == pollIntervalMs)&&(identical(other.serializeRequests, serializeRequests) || other.serializeRequests == serializeRequests)&&(identical(other.autoReconnect, autoReconnect) || other.autoReconnect == autoReconnect)&&(identical(other.minRequestGapMs, minRequestGapMs) || other.minRequestGapMs == minRequestGapMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,transport,host,port,serialPort,baudRate,dataBits,stopBits,parity,timeoutMs,retries,pollIntervalMs,serializeRequests,autoReconnect,minRequestGapMs);

@override
String toString() {
  return 'DeviceConfig(id: $id, name: $name, transport: $transport, host: $host, port: $port, serialPort: $serialPort, baudRate: $baudRate, dataBits: $dataBits, stopBits: $stopBits, parity: $parity, timeoutMs: $timeoutMs, retries: $retries, pollIntervalMs: $pollIntervalMs, serializeRequests: $serializeRequests, autoReconnect: $autoReconnect, minRequestGapMs: $minRequestGapMs)';
}


}

/// @nodoc
abstract mixin class $DeviceConfigCopyWith<$Res>  {
  factory $DeviceConfigCopyWith(DeviceConfig value, $Res Function(DeviceConfig) _then) = _$DeviceConfigCopyWithImpl;
@useResult
$Res call({
 String id, String name, ModbusTransport transport, String host, int port, String serialPort, int baudRate, int dataBits, int stopBits, SerialParity parity, int timeoutMs, int retries, int pollIntervalMs, bool serializeRequests, bool autoReconnect, int minRequestGapMs
});




}
/// @nodoc
class _$DeviceConfigCopyWithImpl<$Res>
    implements $DeviceConfigCopyWith<$Res> {
  _$DeviceConfigCopyWithImpl(this._self, this._then);

  final DeviceConfig _self;
  final $Res Function(DeviceConfig) _then;

/// Create a copy of DeviceConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? transport = null,Object? host = null,Object? port = null,Object? serialPort = null,Object? baudRate = null,Object? dataBits = null,Object? stopBits = null,Object? parity = null,Object? timeoutMs = null,Object? retries = null,Object? pollIntervalMs = null,Object? serializeRequests = null,Object? autoReconnect = null,Object? minRequestGapMs = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as ModbusTransport,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,serialPort: null == serialPort ? _self.serialPort : serialPort // ignore: cast_nullable_to_non_nullable
as String,baudRate: null == baudRate ? _self.baudRate : baudRate // ignore: cast_nullable_to_non_nullable
as int,dataBits: null == dataBits ? _self.dataBits : dataBits // ignore: cast_nullable_to_non_nullable
as int,stopBits: null == stopBits ? _self.stopBits : stopBits // ignore: cast_nullable_to_non_nullable
as int,parity: null == parity ? _self.parity : parity // ignore: cast_nullable_to_non_nullable
as SerialParity,timeoutMs: null == timeoutMs ? _self.timeoutMs : timeoutMs // ignore: cast_nullable_to_non_nullable
as int,retries: null == retries ? _self.retries : retries // ignore: cast_nullable_to_non_nullable
as int,pollIntervalMs: null == pollIntervalMs ? _self.pollIntervalMs : pollIntervalMs // ignore: cast_nullable_to_non_nullable
as int,serializeRequests: null == serializeRequests ? _self.serializeRequests : serializeRequests // ignore: cast_nullable_to_non_nullable
as bool,autoReconnect: null == autoReconnect ? _self.autoReconnect : autoReconnect // ignore: cast_nullable_to_non_nullable
as bool,minRequestGapMs: null == minRequestGapMs ? _self.minRequestGapMs : minRequestGapMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DeviceConfig].
extension DeviceConfigPatterns on DeviceConfig {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeviceConfig value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeviceConfig() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeviceConfig value)  $default,){
final _that = this;
switch (_that) {
case _DeviceConfig():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeviceConfig value)?  $default,){
final _that = this;
switch (_that) {
case _DeviceConfig() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ModbusTransport transport,  String host,  int port,  String serialPort,  int baudRate,  int dataBits,  int stopBits,  SerialParity parity,  int timeoutMs,  int retries,  int pollIntervalMs,  bool serializeRequests,  bool autoReconnect,  int minRequestGapMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeviceConfig() when $default != null:
return $default(_that.id,_that.name,_that.transport,_that.host,_that.port,_that.serialPort,_that.baudRate,_that.dataBits,_that.stopBits,_that.parity,_that.timeoutMs,_that.retries,_that.pollIntervalMs,_that.serializeRequests,_that.autoReconnect,_that.minRequestGapMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ModbusTransport transport,  String host,  int port,  String serialPort,  int baudRate,  int dataBits,  int stopBits,  SerialParity parity,  int timeoutMs,  int retries,  int pollIntervalMs,  bool serializeRequests,  bool autoReconnect,  int minRequestGapMs)  $default,) {final _that = this;
switch (_that) {
case _DeviceConfig():
return $default(_that.id,_that.name,_that.transport,_that.host,_that.port,_that.serialPort,_that.baudRate,_that.dataBits,_that.stopBits,_that.parity,_that.timeoutMs,_that.retries,_that.pollIntervalMs,_that.serializeRequests,_that.autoReconnect,_that.minRequestGapMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ModbusTransport transport,  String host,  int port,  String serialPort,  int baudRate,  int dataBits,  int stopBits,  SerialParity parity,  int timeoutMs,  int retries,  int pollIntervalMs,  bool serializeRequests,  bool autoReconnect,  int minRequestGapMs)?  $default,) {final _that = this;
switch (_that) {
case _DeviceConfig() when $default != null:
return $default(_that.id,_that.name,_that.transport,_that.host,_that.port,_that.serialPort,_that.baudRate,_that.dataBits,_that.stopBits,_that.parity,_that.timeoutMs,_that.retries,_that.pollIntervalMs,_that.serializeRequests,_that.autoReconnect,_that.minRequestGapMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeviceConfig implements DeviceConfig {
  const _DeviceConfig({required this.id, required this.name, this.transport = ModbusTransport.tcp, this.host = '', this.port = 502, this.serialPort = '', this.baudRate = 9600, this.dataBits = 8, this.stopBits = 1, this.parity = SerialParity.none, this.timeoutMs = 2000, this.retries = 2, this.pollIntervalMs = 1000, this.serializeRequests = true, this.autoReconnect = true, this.minRequestGapMs = 100});
  factory _DeviceConfig.fromJson(Map<String, dynamic> json) => _$DeviceConfigFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey() final  ModbusTransport transport;
// ── TCP ──
@override@JsonKey() final  String host;
@override@JsonKey() final  int port;
// ── RTU ──
/// Platform-native serial port path. e.g. `COM3` (Windows),
/// `/dev/cu.usbserial-110` (macOS), `/dev/ttyUSB0` (Linux).
@override@JsonKey() final  String serialPort;
@override@JsonKey() final  int baudRate;
@override@JsonKey() final  int dataBits;
@override@JsonKey() final  int stopBits;
@override@JsonKey() final  SerialParity parity;
// ── shared ──
@override@JsonKey() final  int timeoutMs;
@override@JsonKey() final  int retries;
/// Device-level polling cycle. Each cycle queries every watch on this
/// device in sequence; back-to-back requests within a cycle are still
/// gated by [minRequestGapMs]. If a cycle takes longer than this, the
/// next cycle starts immediately with no extra wait.
@override@JsonKey() final  int pollIntervalMs;
/// One in-flight request at a time. Default ON because most MCU-class
/// slaves (ESP32, Arduino, RS-485 gateway-fronted PLCs) can't handle
/// concurrent transactions. Disable for capable PLCs to allow parallel
/// requests demuxed by transaction id. RTU is always serialized
/// regardless of this flag (half-duplex bus).
@override@JsonKey() final  bool serializeRequests;
@override@JsonKey() final  bool autoReconnect;
/// Minimum gap (ms) between successive requests on this device's
/// connection. 0 = no throttling. Default 100 to give slow slaves
/// breathing room.
@override@JsonKey() final  int minRequestGapMs;

/// Create a copy of DeviceConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeviceConfigCopyWith<_DeviceConfig> get copyWith => __$DeviceConfigCopyWithImpl<_DeviceConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeviceConfigToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeviceConfig&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.transport, transport) || other.transport == transport)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.serialPort, serialPort) || other.serialPort == serialPort)&&(identical(other.baudRate, baudRate) || other.baudRate == baudRate)&&(identical(other.dataBits, dataBits) || other.dataBits == dataBits)&&(identical(other.stopBits, stopBits) || other.stopBits == stopBits)&&(identical(other.parity, parity) || other.parity == parity)&&(identical(other.timeoutMs, timeoutMs) || other.timeoutMs == timeoutMs)&&(identical(other.retries, retries) || other.retries == retries)&&(identical(other.pollIntervalMs, pollIntervalMs) || other.pollIntervalMs == pollIntervalMs)&&(identical(other.serializeRequests, serializeRequests) || other.serializeRequests == serializeRequests)&&(identical(other.autoReconnect, autoReconnect) || other.autoReconnect == autoReconnect)&&(identical(other.minRequestGapMs, minRequestGapMs) || other.minRequestGapMs == minRequestGapMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,transport,host,port,serialPort,baudRate,dataBits,stopBits,parity,timeoutMs,retries,pollIntervalMs,serializeRequests,autoReconnect,minRequestGapMs);

@override
String toString() {
  return 'DeviceConfig(id: $id, name: $name, transport: $transport, host: $host, port: $port, serialPort: $serialPort, baudRate: $baudRate, dataBits: $dataBits, stopBits: $stopBits, parity: $parity, timeoutMs: $timeoutMs, retries: $retries, pollIntervalMs: $pollIntervalMs, serializeRequests: $serializeRequests, autoReconnect: $autoReconnect, minRequestGapMs: $minRequestGapMs)';
}


}

/// @nodoc
abstract mixin class _$DeviceConfigCopyWith<$Res> implements $DeviceConfigCopyWith<$Res> {
  factory _$DeviceConfigCopyWith(_DeviceConfig value, $Res Function(_DeviceConfig) _then) = __$DeviceConfigCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ModbusTransport transport, String host, int port, String serialPort, int baudRate, int dataBits, int stopBits, SerialParity parity, int timeoutMs, int retries, int pollIntervalMs, bool serializeRequests, bool autoReconnect, int minRequestGapMs
});




}
/// @nodoc
class __$DeviceConfigCopyWithImpl<$Res>
    implements _$DeviceConfigCopyWith<$Res> {
  __$DeviceConfigCopyWithImpl(this._self, this._then);

  final _DeviceConfig _self;
  final $Res Function(_DeviceConfig) _then;

/// Create a copy of DeviceConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? transport = null,Object? host = null,Object? port = null,Object? serialPort = null,Object? baudRate = null,Object? dataBits = null,Object? stopBits = null,Object? parity = null,Object? timeoutMs = null,Object? retries = null,Object? pollIntervalMs = null,Object? serializeRequests = null,Object? autoReconnect = null,Object? minRequestGapMs = null,}) {
  return _then(_DeviceConfig(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,transport: null == transport ? _self.transport : transport // ignore: cast_nullable_to_non_nullable
as ModbusTransport,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,serialPort: null == serialPort ? _self.serialPort : serialPort // ignore: cast_nullable_to_non_nullable
as String,baudRate: null == baudRate ? _self.baudRate : baudRate // ignore: cast_nullable_to_non_nullable
as int,dataBits: null == dataBits ? _self.dataBits : dataBits // ignore: cast_nullable_to_non_nullable
as int,stopBits: null == stopBits ? _self.stopBits : stopBits // ignore: cast_nullable_to_non_nullable
as int,parity: null == parity ? _self.parity : parity // ignore: cast_nullable_to_non_nullable
as SerialParity,timeoutMs: null == timeoutMs ? _self.timeoutMs : timeoutMs // ignore: cast_nullable_to_non_nullable
as int,retries: null == retries ? _self.retries : retries // ignore: cast_nullable_to_non_nullable
as int,pollIntervalMs: null == pollIntervalMs ? _self.pollIntervalMs : pollIntervalMs // ignore: cast_nullable_to_non_nullable
as int,serializeRequests: null == serializeRequests ? _self.serializeRequests : serializeRequests // ignore: cast_nullable_to_non_nullable
as bool,autoReconnect: null == autoReconnect ? _self.autoReconnect : autoReconnect // ignore: cast_nullable_to_non_nullable
as bool,minRequestGapMs: null == minRequestGapMs ? _self.minRequestGapMs : minRequestGapMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
