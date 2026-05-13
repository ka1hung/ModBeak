import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/watch_spec.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'watch_pane.dart';

/// MDI-style workspace that hosts every [WatchSpec] of the current device as
/// an independently draggable / resizable sub-window — modelled after
/// Modbus Poll's child windows.
class MdiWorkspace extends ConsumerStatefulWidget {
  final List<WatchSpec> watches;

  /// When the user clicks a watch in the sidebar we bring that MDI window
  /// to the front. Pass the watchId to focus; null = no change.
  final String? focusedWatchId;

  const MdiWorkspace({
    super.key,
    required this.watches,
    this.focusedWatchId,
  });

  @override
  ConsumerState<MdiWorkspace> createState() => MdiWorkspaceState();
}

class MdiWorkspaceState extends ConsumerState<MdiWorkspace> {
  static const double _defaultW = 420;
  static const double _defaultH = 280;
  static const double _cascadeStep = 28;
  static const double _minW = 280;
  static const double _minH = 140;
  static const double _titleBarHeight = 26;
  static const double _minimizedStripHeight = 30;

  Size? _lastBounds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedLayout();
      if (widget.focusedWatchId != null) _onSidebarFocus(widget.focusedWatchId!);
    });
  }

  @override
  void didUpdateWidget(covariant MdiWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedLayout();
      if (widget.focusedWatchId != null &&
          widget.focusedWatchId != oldWidget.focusedWatchId) {
        _onSidebarFocus(widget.focusedWatchId!);
      }
    });
  }

  /// Ensure every visible watch has a slot + z-order entry. Newly added
  /// watches get a cascading offset position.
  void _seedLayout() {
    if (!mounted) return;
    final layout = ref.read(mdiLayoutProvider);
    final z = ref.read(mdiZOrderProvider);
    final newLayout = Map<String, MdiWindowSlot>.from(layout);
    final newZ = List<String>.from(z);
    var changed = false;
    var seeded = newLayout.length;
    for (final w in widget.watches) {
      if (!newLayout.containsKey(w.id)) {
        final col = seeded % 8;
        final row = (seeded / 8).floor();
        newLayout[w.id] = MdiWindowSlot(
          rect: MdiRect(
            16 + col * _cascadeStep,
            16 + col * _cascadeStep + row * 40,
            _defaultW,
            _defaultH,
          ),
        );
        seeded++;
        changed = true;
      }
      if (!newZ.contains(w.id)) {
        newZ.add(w.id);
        changed = true;
      }
    }
    if (changed) {
      ref.read(mdiLayoutProvider.notifier).replace(newLayout);
      ref.read(mdiZOrderProvider.notifier).replace(newZ);
    }
  }

  /// Sidebar click: if hidden/minimized, restore; always bring to front.
  void _onSidebarFocus(String id) {
    final slot = ref.read(mdiLayoutProvider)[id];
    if (slot == null) return;
    if (slot.mode == MdiWindowMode.hidden ||
        slot.mode == MdiWindowMode.minimized) {
      ref.read(mdiLayoutProvider.notifier).restore(id);
    }
    ref.read(mdiZOrderProvider.notifier).bringToFront(id);
  }

  void _bringToFront(String id) =>
      ref.read(mdiZOrderProvider.notifier).bringToFront(id);

  /// Apply a drag delta against the latest rect from the provider, not the
  /// rect that was current at the time _MdiWindow was last built. Fast drags
  /// can emit several deltas per frame; without re-reading state, every
  /// update past the first would compute against a stale base rect.
  void _applyDragDelta(String id, Offset delta, Size bounds) {
    final r = ref.read(mdiLayoutProvider)[id]?.rect;
    if (r == null) return;
    final maxX = (bounds.width - 60).clamp(0.0, double.infinity);
    final maxY = (bounds.height - _titleBarHeight).clamp(0.0, double.infinity);
    final nx = (r.x + delta.dx).clamp(0.0, maxX);
    final ny = (r.y + delta.dy).clamp(0.0, maxY);
    ref.read(mdiLayoutProvider.notifier).setRect(id, r.copyWith(x: nx, y: ny));
  }

  void _applyResizeDelta(String id, Offset delta, Size bounds) {
    final r = ref.read(mdiLayoutProvider)[id]?.rect;
    if (r == null) return;
    final nw = (r.w + delta.dx).clamp(_minW, bounds.width - r.x);
    final nh = (r.h + delta.dy).clamp(_minH, bounds.height - r.y);
    ref.read(mdiLayoutProvider.notifier).setRect(id, r.copyWith(w: nw, h: nh));
  }

  void _close(String id) => ref.read(mdiLayoutProvider.notifier).hide(id);

  void _minimize(String id) =>
      ref.read(mdiLayoutProvider.notifier).minimize(id);

  void _toggleMaximize(String id) {
    final slot = ref.read(mdiLayoutProvider)[id];
    if (slot == null) return;
    final bounds = _lastBounds;
    if (slot.mode == MdiWindowMode.maximized) {
      ref.read(mdiLayoutProvider.notifier).restore(id);
    } else if (bounds != null) {
      ref
          .read(mdiLayoutProvider.notifier)
          .maximize(id, MdiRect(0, 0, bounds.width, bounds.height));
      _bringToFront(id);
    }
  }

  /// Apply a quick-layout to all currently-visible (non-hidden) watches and
  /// reset their mode to normal.
  void applyLayout(MdiLayoutMode mode) {
    final bounds = _lastBounds;
    if (bounds == null) return;
    final layout = ref.read(mdiLayoutProvider);
    final visibleIds = [
      for (final w in widget.watches)
        if ((layout[w.id]?.mode ?? MdiWindowMode.normal) !=
            MdiWindowMode.hidden)
          w.id,
    ];
    if (visibleIds.isEmpty) return;
    final rects = MdiLayoutComputer.compute(
      mode: mode,
      ids: visibleIds,
      bounds: bounds,
    );
    ref.read(mdiLayoutProvider.notifier).applyLayout(rects);
  }

  /// Restore every hidden window (for the toolbar "Show all" action).
  void restoreAll() {
    final layout = ref.read(mdiLayoutProvider);
    for (final w in widget.watches) {
      final slot = layout[w.id];
      if (slot == null) continue;
      if (slot.mode == MdiWindowMode.hidden ||
          slot.mode == MdiWindowMode.minimized) {
        ref.read(mdiLayoutProvider.notifier).restore(w.id);
      }
    }
  }

  /// Hide every currently-visible window of this device.
  void closeAll() {
    final layout = ref.read(mdiLayoutProvider);
    for (final w in widget.watches) {
      final mode = layout[w.id]?.mode ?? MdiWindowMode.normal;
      if (mode != MdiWindowMode.hidden) {
        ref.read(mdiLayoutProvider.notifier).hide(w.id);
      }
    }
  }

  /// Zero out OK / ERR / Avg counters for every watch on this device,
  /// then bump the stats tick so footers re-render immediately.
  void resetCounters(String deviceId) {
    ref.read(deviceHubProvider).resetStatsForDevice(deviceId);
    ref.read(statsTickProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(mdiLayoutProvider);
    final z = ref.watch(mdiZOrderProvider);

    if (widget.watches.isEmpty) {
      return Container(
        color: AppColors.bg,
        alignment: Alignment.center,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No watches on this device yet.\nClick "+ New watch" to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }

    final byId = {for (final w in widget.watches) w.id: w};
    final minimizedIds = [
      for (final id in z)
        if (byId[id] != null &&
            (layout[id]?.mode == MdiWindowMode.minimized))
          id,
    ];

    return LayoutBuilder(builder: (ctx, constraints) {
      final stripHeight =
          minimizedIds.isEmpty ? 0.0 : _minimizedStripHeight;
      final stackHeight = constraints.maxHeight - stripHeight;
      final stackBounds = Size(constraints.maxWidth, stackHeight);
      _lastBounds = stackBounds;

      return Container(
        color: AppColors.bg,
        child: Column(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              height: stackHeight,
              child: Stack(
                children: [
                  for (final id in z)
                    if (byId[id] != null &&
                        layout[id] != null &&
                        layout[id]!.mode != MdiWindowMode.hidden &&
                        layout[id]!.mode != MdiWindowMode.minimized)
                      _MdiWindow(
                        key: ValueKey(id),
                        spec: byId[id]!,
                        slot: layout[id]!,
                        bounds: stackBounds,
                        minW: _minW,
                        minH: _minH,
                        titleBarHeight: _titleBarHeight,
                        onFocus: () => _bringToFront(id),
                        // Drag / resize callbacks emit RAW DELTAS rather than
                        // an absolute rect — `onPanUpdate` can fire several
                        // times per frame on fast drags, so the rect captured
                        // at build time goes stale between updates. Reading
                        // fresh state from the provider on each call keeps
                        // the math correct regardless of rebuild cadence.
                        onDragDelta: (delta) =>
                            _applyDragDelta(id, delta, stackBounds),
                        onResizeDelta: (delta) =>
                            _applyResizeDelta(id, delta, stackBounds),
                        onMinimize: () => _minimize(id),
                        onToggleMaximize: () => _toggleMaximize(id),
                        onClose: () => _close(id),
                      ),
                ],
              ),
            ),
            if (minimizedIds.isNotEmpty)
              _MinimizedStrip(
                height: _minimizedStripHeight,
                watches: [for (final id in minimizedIds) byId[id]!],
                onRestore: (id) {
                  ref.read(mdiLayoutProvider.notifier).restore(id);
                  _bringToFront(id);
                },
                onClose: _close,
              ),
          ],
        ),
      );
    });
  }
}

class _MdiWindow extends StatelessWidget {
  final WatchSpec spec;
  final MdiWindowSlot slot;
  final Size bounds;
  final double minW, minH, titleBarHeight;
  final VoidCallback onFocus;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<Offset> onResizeDelta;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  const _MdiWindow({
    super.key,
    required this.spec,
    required this.slot,
    required this.bounds,
    required this.minW,
    required this.minH,
    required this.titleBarHeight,
    required this.onFocus,
    required this.onDragDelta,
    required this.onResizeDelta,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  String get _fcLabel {
    switch (spec.functionCode) {
      case 1:
        return 'FC01 Coils';
      case 2:
        return 'FC02 DI';
      case 3:
        return 'FC03 HR';
      case 4:
        return 'FC04 IR';
      default:
        return 'FC${spec.functionCode}';
    }
  }

  String get _title =>
      '$_fcLabel · ${spec.startAddress}–${spec.startAddress + spec.quantity - 1}';

  @override
  Widget build(BuildContext context) {
    final isMax = slot.mode == MdiWindowMode.maximized;
    final rect = slot.rect;
    final maxX = (bounds.width - 60).clamp(0.0, double.infinity);
    final maxY = (bounds.height - titleBarHeight).clamp(0.0, double.infinity);
    final clampedX = isMax ? 0.0 : rect.x.clamp(0.0, maxX);
    final clampedY = isMax ? 0.0 : rect.y.clamp(0.0, maxY);
    final maxW = (bounds.width - clampedX).clamp(minW, double.infinity);
    final maxH = (bounds.height - clampedY).clamp(minH, double.infinity);
    final clampedW = isMax ? bounds.width : rect.w.clamp(minW, maxW);
    final clampedH = isMax ? bounds.height : rect.h.clamp(minH, maxH);

    return Positioned(
      left: clampedX,
      top: clampedY,
      width: clampedW,
      height: clampedH,
      child: Listener(
        onPointerDown: (_) => onFocus(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius:
                isMax ? BorderRadius.zero : BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
            boxShadow: isMax
                ? const []
                : const [
                    BoxShadow(
                      blurRadius: 8,
                      color: Color(0x55000000),
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            children: [
              _TitleBar(
                title: _title,
                height: titleBarHeight,
                isMaximized: isMax,
                onDoubleTap: onToggleMaximize,
                onDrag: isMax ? null : onDragDelta,
                onMinimize: onMinimize,
                onToggleMaximize: onToggleMaximize,
                onClose: onClose,
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: isMax
                            ? BorderRadius.zero
                            : const BorderRadius.only(
                                bottomLeft: Radius.circular(3),
                                bottomRight: Radius.circular(3),
                              ),
                        child: WatchPane(spec: spec),
                      ),
                    ),
                    if (!isMax)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _ResizeHandle(onDrag: onResizeDelta),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String title;
  final double height;
  final bool isMaximized;
  final ValueChanged<Offset>? onDrag;
  final VoidCallback onDoubleTap;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;
  final VoidCallback onClose;

  const _TitleBar({
    required this.title,
    required this.height,
    required this.isMaximized,
    required this.onDrag,
    required this.onDoubleTap,
    required this.onMinimize,
    required this.onToggleMaximize,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(3),
          topRight: Radius.circular(3),
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Drag handle area — title text. Window controls stay
          // outside the GestureDetector so taps reach them.
          Expanded(
            child: MouseRegion(
              cursor: onDrag == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate:
                    onDrag == null ? null : (d) => onDrag!(d.delta),
                onDoubleTap: onDoubleTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _WinBtn(
            icon: Icons.minimize,
            tooltip: 'Minimize',
            onTap: onMinimize,
          ),
          _WinBtn(
            icon: isMaximized
                ? Icons.filter_none_outlined
                : Icons.crop_square,
            tooltip: isMaximized ? 'Restore' : 'Maximize',
            onTap: onToggleMaximize,
          ),
          _WinBtn(
            icon: Icons.close,
            tooltip: 'Close',
            onTap: onClose,
            hoverColor: AppColors.danger,
          ),
        ],
      ),
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;
  const _WinBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hi = widget.hoverColor ?? AppColors.brand;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: 28,
            height: double.infinity,
            color: _hover ? hi.withValues(alpha: 0.16) : null,
            child: Icon(
              widget.icon,
              size: 12,
              color: _hover ? hi : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final ValueChanged<Offset> onDrag;
  const _ResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => onDrag(d.delta),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: Padding(
            padding: EdgeInsets.only(right: 2, bottom: 2),
            child: Icon(Icons.south_east,
                size: 12, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _MinimizedStrip extends StatelessWidget {
  final double height;
  final List<WatchSpec> watches;
  final ValueChanged<String> onRestore;
  final ValueChanged<String> onClose;
  const _MinimizedStrip({
    required this.height,
    required this.watches,
    required this.onRestore,
    required this.onClose,
  });

  String _label(WatchSpec s) {
    final fc = switch (s.functionCode) {
      1 => 'FC01',
      2 => 'FC02',
      3 => 'FC03',
      4 => 'FC04',
      _ => 'FC${s.functionCode}',
    };
    return '$fc ${s.startAddress}–${s.startAddress + s.quantity - 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.bgRaised,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        itemCount: watches.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final w = watches[i];
          return InkWell(
            onTap: () => onRestore(w.id),
            borderRadius: BorderRadius.circular(3),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                children: [
                  const Icon(Icons.web_asset,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    _label(w),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onClose(w.id),
                    child: const Icon(Icons.close,
                        size: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
