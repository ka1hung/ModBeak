import 'package:freezed_annotation/freezed_annotation.dart';

import 'pane_layout.dart';

part 'watch_window.freezed.dart';
part 'watch_window.g.dart';

/// A Watch Window is a container that holds one or more panes via a
/// tree-shaped [PaneLayout]. It is also the unit of saved layouts.
@freezed
abstract class WatchWindow with _$WatchWindow {
  const factory WatchWindow({
    required String id,
    required String name,
    required PaneLayout layout,
    @Default(0) double x,
    @Default(0) double y,
    @Default(900) double width,
    @Default(600) double height,
  }) = _WatchWindow;

  factory WatchWindow.fromJson(Map<String, dynamic> json) =>
      _$WatchWindowFromJson(json);
}
