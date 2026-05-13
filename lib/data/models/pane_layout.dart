import 'package:freezed_annotation/freezed_annotation.dart';

import 'watch_spec.dart';

part 'pane_layout.freezed.dart';
part 'pane_layout.g.dart';

enum SplitDirection { horizontal, vertical }

/// Tree of panes inside a [WatchWindow].
///
/// Either:
///   * [LeafPane] — terminal node containing a [WatchSpec].
///   * [SplitPane] — internal node with N children + ratios summing to 1.0.
@freezed
sealed class PaneLayout with _$PaneLayout {
  const factory PaneLayout.leaf({
    required String paneId,
    required WatchSpec watch,
  }) = LeafPane;

  const factory PaneLayout.split({
    required SplitDirection direction,
    required List<PaneLayout> children,
    required List<double> ratios,
  }) = SplitPane;

  factory PaneLayout.fromJson(Map<String, dynamic> json) =>
      _$PaneLayoutFromJson(json);
}
