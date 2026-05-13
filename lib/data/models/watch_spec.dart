import 'package:freezed_annotation/freezed_annotation.dart';

import 'register_format.dart';

part 'watch_spec.freezed.dart';
part 'watch_spec.g.dart';

/// One Watch Pane's full configuration.
///
/// `format` is the *initial* format; the Pane UI lets the user change it
/// at runtime without affecting the underlying poll loop.
@freezed
abstract class WatchSpec with _$WatchSpec {
  const factory WatchSpec({
    required String id,
    required String deviceId,
    required int unitId,
    required int functionCode, // 1, 2, 3 or 4
    required int startAddress,
    required int quantity,
    @Default(RegisterFormat.u16) RegisterFormat format,
    @Default(8) int asciiCharsPerRow,

    /// If true, this watch is skipped in the device's polling cycle. Manual
    /// refresh (via `refreshOnce`) still works.
    @Default(false) bool manualOnly,
  }) = _WatchSpec;

  factory WatchSpec.fromJson(Map<String, dynamic> json) =>
      _$WatchSpecFromJson(json);
}
