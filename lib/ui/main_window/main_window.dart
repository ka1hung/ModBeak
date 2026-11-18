import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/runtime/device_hub.dart';
import '../../core/runtime/poll_result.dart';
import '../../data/models/device_config.dart';
import '../../data/models/register_format.dart';
import '../../data/models/watch_spec.dart';
import '../../data/persistence/config_io.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../watch_window/mdi_workspace.dart';
import '../widgets/brand.dart';
import '../widgets/conn_indicator.dart';
import 'dialogs/about_dialog.dart';
import 'dialogs/add_device_dialog.dart';
import 'dialogs/add_watch_dialog.dart';

/// Main console — top toolbar, sidebar (devices + watches), and the right
/// pane that hosts the device header and the MDI watch workspace.
class MainWindow extends ConsumerStatefulWidget {
  const MainWindow({super.key});

  @override
  ConsumerState<MainWindow> createState() => _MainWindowState();
}

/// Sidebar selection identity. The right pane reacts to whichever of these
/// two is non-null:
///   * deviceId only  → show device header + welcome
///   * deviceId + watchId → show device header + watch pane
class _Selection {
  final String? deviceId;
  final String? watchId;
  const _Selection({this.deviceId, this.watchId});
}

class _MainWindowState extends ConsumerState<MainWindow> {
  _Selection _selection = const _Selection();
  final Set<String> _expanded = {};
  final GlobalKey<MdiWorkspaceState> _mdiKey =
      GlobalKey<MdiWorkspaceState>();

  // ── Sidebar sizing ──
  // Width is user-draggable between min/max; dragging well below min snaps
  // the sidebar closed (VS Code-style). Both width and collapsed state are
  // persisted via SharedPreferences.
  static const double _kSidebarMin = 180;
  static const double _kSidebarMax = 480;
  static const double _kSidebarDefault = 260;
  static const double _kSidebarSnapClose = 120;
  static const String _kPrefSidebarWidth = 'ui.sidebarWidth';
  static const String _kPrefSidebarCollapsed = 'ui.sidebarCollapsed';

  double _sidebarWidth = _kSidebarDefault;
  bool _sidebarCollapsed = false;
  // Unclamped width tracked during an active drag so the snap-close /
  // snap-open thresholds work even past the clamp bounds.
  double _dragWidth = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _sidebarWidth = (prefs.getDouble(_kPrefSidebarWidth) ??
                _kSidebarDefault)
            .clamp(_kSidebarMin, _kSidebarMax);
        _sidebarCollapsed =
            prefs.getBool(_kPrefSidebarCollapsed) ?? false;
      });
    });
    // Belt-and-braces: also rebuild from here when the theme flips. The
    // root MaterialApp already rebuilds on `themeModeNotifier`, but a
    // listener at this level guarantees `build` re-runs even if the parent
    // tree happens to short-circuit the diff (e.g. via const wrapping).
    themeModeNotifier.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await ConfigStore.load();
      if (!mounted) return;
      await applyConfig(ref, saved);
      ref.read(autoSaveProvider);
      final watches = ref.read(watchListProvider);
      setState(() {
        _expanded.addAll(watches.map((w) => w.deviceId));
      });
    });
  }

  @override
  void dispose() {
    themeModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _selectDevice(String id) {
    setState(() {
      _selection = _Selection(deviceId: id);
      _expanded.add(id);
    });
  }

  void _selectWatch(String deviceId, String watchId) {
    setState(() {
      _selection = _Selection(deviceId: deviceId, watchId: watchId);
      _expanded.add(deviceId);
    });
  }

  void _toggleExpand(String deviceId) {
    setState(() {
      if (_expanded.contains(deviceId)) {
        _expanded.remove(deviceId);
      } else {
        _expanded.add(deviceId);
      }
    });
  }

  void _saveSidebarPrefs() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_kPrefSidebarWidth, _sidebarWidth);
      prefs.setBool(_kPrefSidebarCollapsed, _sidebarCollapsed);
    });
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    _saveSidebarPrefs();
  }

  void _onSidebarDragStart() {
    _dragWidth = _sidebarCollapsed ? 0 : _sidebarWidth;
  }

  void _onSidebarDrag(double dx) {
    _dragWidth += dx;
    setState(() {
      if (_dragWidth < _kSidebarSnapClose) {
        _sidebarCollapsed = true;
      } else {
        _sidebarCollapsed = false;
        _sidebarWidth = _dragWidth.clamp(_kSidebarMin, _kSidebarMax);
      }
    });
  }

  void _onSidebarDragEnd() => _saveSidebarPrefs();

  void _resetSidebarWidth() {
    setState(() {
      _sidebarCollapsed = false;
      _sidebarWidth = _kSidebarDefault;
    });
    _saveSidebarPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);
    if (_selection.deviceId != null &&
        !devices.any((d) => d.id == _selection.deviceId)) {
      _selection = const _Selection();
    }

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < kCompactBreakpoint;

    void closeDrawerIfOpen() {
      if (isCompact) {
        final nav = Navigator.maybeOf(context);
        if (nav != null && nav.canPop()) nav.pop();
      }
    }

    final sidebar = _Sidebar(
      selection: _selection,
      expanded: _expanded,
      onSelectDevice: (id) {
        _selectDevice(id);
        closeDrawerIfOpen();
      },
      onSelectWatch: (devId, wId) {
        _selectWatch(devId, wId);
        closeDrawerIfOpen();
      },
      onToggleExpand: _toggleExpand,
    );

    return Scaffold(
      backgroundColor: AppColors.bg0,
      drawer:
          isCompact ? Drawer(child: SafeArea(child: sidebar)) : null,
      body: SafeArea(
        child: Column(
          children: [
            _TopToolbar(
              onAddDevice: _onAddDevice,
              onAddWatch: _onAddWatch,
              showMenu: isCompact,
              sidebarVisible: !_sidebarCollapsed,
              onToggleSidebar: isCompact ? null : _toggleSidebar,
            ),
            Container(height: 1, color: AppColors.border),
            Expanded(
              child: isCompact
                  ? _RightPane(
                      selection: _selection,
                      onSelectWatch: _selectWatch,
                      mdiKey: _mdiKey,
                    )
                  : Row(
                      children: [
                        if (!_sidebarCollapsed)
                          SizedBox(width: _sidebarWidth, child: sidebar),
                        // Handle stays mounted while collapsed so a drag
                        // from the left edge can pull the sidebar back out.
                        _SidebarResizeHandle(
                          onDragStart: _onSidebarDragStart,
                          onDrag: _onSidebarDrag,
                          onDragEnd: _onSidebarDragEnd,
                          onDoubleTap: _resetSidebarWidth,
                        ),
                        Expanded(
                          child: _RightPane(
                            selection: _selection,
                            onSelectWatch: _selectWatch,
                            mdiKey: _mdiKey,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddDevice() async {
    final cfg = await showDialog<DeviceConfig>(
      context: context,
      builder: (_) => const AddDeviceDialog(),
    );
    // Focus the freshly created device so the next "Add Watch" preselects it.
    if (cfg != null && mounted) _selectDevice(cfg.id);
  }

  Future<void> _onAddWatch() async {
    final devices = ref.read(deviceListProvider);
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a device first')),
      );
      return;
    }
    final preselect = _selection.deviceId ?? devices.first.id;
    final spec = await showDialog<WatchSpec>(
      context: context,
      builder: (_) => AddWatchDialog(initialDeviceId: preselect),
    );
    if (spec != null) {
      setState(() {
        _selection = _Selection(deviceId: spec.deviceId, watchId: spec.id);
        _expanded.add(spec.deviceId);
      });
    }
  }
}

// ─── Top toolbar ────────────────────────────────────────────────────────────

Future<void> _import(BuildContext context, WidgetRef ref) async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'JSON', extensions: ['json']),
    ],
  );
  if (file == null) return;
  try {
    final cfg = await ConfigStore.importFromFile(file.path);
    if (!context.mounted) return;
    await applyConfig(ref, cfg);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Imported ${cfg.devices.length} devices, ${cfg.watches.length} watches')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}

Future<void> _export(BuildContext context, WidgetRef ref) async {
  final loc = await getSaveLocation(
    suggestedName: 'modbeak_config.json',
    acceptedTypeGroups: [
      const XTypeGroup(label: 'JSON', extensions: ['json']),
    ],
  );
  if (loc == null) return;
  final cfg = AppConfig(
    devices: ref.read(deviceListProvider),
    watches: ref.read(watchListProvider),
    savedLayouts: ref.read(watchWindowProvider),
  );
  try {
    await ConfigStore.exportToFile(cfg, loc.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${loc.path}')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}

class _TopToolbar extends StatelessWidget {
  final VoidCallback onAddDevice;
  final VoidCallback onAddWatch;
  final bool showMenu;
  final bool sidebarVisible;
  final VoidCallback? onToggleSidebar;
  const _TopToolbar({
    required this.onAddDevice,
    required this.onAddWatch,
    this.showMenu = false,
    this.sidebarVisible = true,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: AppColors.bg3,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          if (showMenu) ...[
            Builder(
              builder: (ctx) => _IconChip(
                tooltip: 'Devices',
                onTap: () => Scaffold.of(ctx).openDrawer(),
                child: Icon(Icons.menu, size: 16, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (onToggleSidebar != null) ...[
            _IconChip(
              tooltip: sidebarVisible ? 'Hide sidebar' : 'Show sidebar',
              onTap: onToggleSidebar!,
              child: Icon(
                sidebarVisible
                    ? Icons.vertical_split
                    : Icons.vertical_split_outlined,
                size: 15,
                color:
                    sidebarVisible ? AppColors.textMuted : AppColors.accent,
              ),
            ),
            const SizedBox(width: 6),
          ],
          const BrandMark(),
          const SizedBox(width: 7),
          const _VersionBadge(),
          _Divider(),
          _MbtButton(
            kind: _ButtonKind.primary,
            icon: Icons.add,
            label: 'Device',
            onTap: onAddDevice,
          ),
          const SizedBox(width: 6),
          _MbtButton(
            kind: _ButtonKind.secondary,
            icon: Icons.add,
            label: 'Watch',
            onTap: onAddWatch,
          ),
          const Spacer(),
          if (!showMenu) ...[
            Consumer(builder: (context, ref, _) {
              return _MbtButton(
                kind: _ButtonKind.ghost,
                icon: Icons.file_download_outlined,
                label: 'Import',
                onTap: () => _import(context, ref),
              );
            }),
            const SizedBox(width: 4),
            Consumer(builder: (context, ref, _) {
              return _MbtButton(
                kind: _ButtonKind.ghost,
                icon: Icons.file_upload_outlined,
                label: 'Export',
                onTap: () => _export(context, ref),
              );
            }),
            _Divider(),
          ],
          _ThemeToggle(),
          if (showMenu) ...[
            const SizedBox(width: 4),
            Consumer(builder: (context, ref, _) {
              return PopupMenuButton<String>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, size: 16, color: AppColors.textMuted),
                color: AppColors.bg2,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'import', child: Text('Import…')),
                  PopupMenuItem(value: 'export', child: Text('Export…')),
                ],
                onSelected: (v) {
                  if (v == 'import') _import(context, ref);
                  if (v == 'export') _export(context, ref);
                },
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// `v1.0.0` chip beside the wordmark; opens the About box on tap.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final label = AppInfo.shortLabel;
    if (label.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: 'ModBeak ${AppInfo.fullLabel} — click for details',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => const AboutModBeakDialog(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Text(
            label,
            style: AppType.monoSm.copyWith(color: AppColors.textDim),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, _) {
        final isLight = mode == AppThemeMode.light;
        return _IconChip(
          tooltip: isLight ? 'Switch to dark theme' : 'Switch to light theme',
          onTap: () => setThemeMode(
            isLight ? AppThemeMode.dark : AppThemeMode.light,
          ),
          child: Icon(
            isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 14,
            color: AppColors.textMuted,
          ),
        );
      },
    );
  }
}

class _IconChip extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconChip({required this.child, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(2),
        ),
        child: child,
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

enum _ButtonKind { primary, secondary, ghost, outline, danger }

class _MbtButton extends StatefulWidget {
  final _ButtonKind kind;
  final IconData? icon;
  final String? label;
  final VoidCallback? onTap;
  final bool disabled;
  final bool active;

  const _MbtButton({
    required this.kind,
    this.icon,
    this.label,
    this.onTap,
    this.disabled = false,
    this.active = false,
  });

  @override
  State<_MbtButton> createState() => _MbtButtonState();
}

class _MbtButtonState extends State<_MbtButton> {
  bool _hover = false;

  Color _bg() {
    if (widget.active) return AppColors.accentBg;
    switch (widget.kind) {
      case _ButtonKind.primary:
        return _hover ? AppColors.accentDim : AppColors.accent;
      case _ButtonKind.secondary:
        return _hover ? AppColors.bg4 : AppColors.bg3;
      case _ButtonKind.ghost:
        return _hover ? AppColors.bg3 : Colors.transparent;
      case _ButtonKind.outline:
        return _hover ? AppColors.bg3 : Colors.transparent;
      case _ButtonKind.danger:
        return _hover ? AppColors.errorBg : Colors.transparent;
    }
  }

  Color _fg() {
    if (widget.active) return AppColors.accent;
    switch (widget.kind) {
      case _ButtonKind.primary:
        return AppColors.onAccent;
      case _ButtonKind.secondary:
        return AppColors.text;
      case _ButtonKind.ghost:
        return AppColors.textMuted;
      case _ButtonKind.outline:
        return AppColors.text;
      case _ButtonKind.danger:
        return AppColors.error;
    }
  }

  Color _border() {
    if (widget.active) return AppColors.accent;
    switch (widget.kind) {
      case _ButtonKind.primary:
        return AppColors.accent;
      case _ButtonKind.secondary:
        return AppColors.borderStrong;
      case _ButtonKind.ghost:
        return Colors.transparent;
      case _ButtonKind.outline:
        return AppColors.border;
      case _ButtonKind.danger:
        return AppColors.errorDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled || widget.onTap == null;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: MouseRegion(
        cursor: disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: disabled ? null : widget.onTap,
          child: Container(
            height: 22,
            padding: EdgeInsets.symmetric(
                horizontal: widget.label == null ? 6 : 8),
            decoration: BoxDecoration(
              color: _bg(),
              border: Border.all(color: _border()),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null)
                  Icon(widget.icon, size: 12, color: _fg()),
                if (widget.icon != null && widget.label != null)
                  const SizedBox(width: 4),
                if (widget.label != null)
                  Text(
                    widget.label!,
                    style: AppType.labelSm.copyWith(color: _fg()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar resize handle ─────────────────────────────────────────────────

/// Thin draggable divider between the sidebar and the right pane. Shows a
/// col-resize cursor, highlights on hover/drag, and resets the width on
/// double-tap. Kept mounted even when the sidebar is collapsed so dragging
/// rightwards from the window edge re-opens it.
class _SidebarResizeHandle extends StatefulWidget {
  final VoidCallback onDragStart;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  final VoidCallback onDoubleTap;
  const _SidebarResizeHandle({
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onDoubleTap,
  });

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final hi = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _dragging = true);
          widget.onDragStart();
        },
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd();
        },
        onHorizontalDragCancel: () {
          setState(() => _dragging = false);
          widget.onDragEnd();
        },
        onDoubleTap: widget.onDoubleTap,
        child: SizedBox(
          width: 5,
          child: Center(
            child: Container(
              width: hi ? 3 : 1,
              color: hi ? AppColors.accent : AppColors.border,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sidebar (tree: devices > watches) ─────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  final _Selection selection;
  final Set<String> expanded;
  final ValueChanged<String> onSelectDevice;
  final void Function(String, String) onSelectWatch;
  final ValueChanged<String> onToggleExpand;

  const _Sidebar({
    required this.selection,
    required this.expanded,
    required this.onSelectDevice,
    required this.onSelectWatch,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final connStates = ref.watch(deviceConnProvider);
    final watches = ref.watch(watchListProvider);

    // Width is imposed by the parent (resizable SizedBox on desktop,
    // Drawer on compact) — no intrinsic width here.
    return Container(
      color: AppColors.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text(
              'DEVICES',
              style: AppType.labelSm.copyWith(color: AppColors.textDim),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              children: [
                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Text(
                      'No devices.\nClick + Device to add one.',
                      style: AppType.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  )
                else
                  for (final d in devices)
                    _DeviceNode(
                      device: d,
                      connState: connStates[d.id] ??
                          DeviceConnState.disconnected,
                      watches:
                          watches.where((w) => w.deviceId == d.id).toList(),
                      isExpanded: expanded.contains(d.id),
                      isSelectedDevice: selection.deviceId == d.id &&
                          selection.watchId == null,
                      selectedWatchId: selection.watchId,
                      onTapDevice: () => onSelectDevice(d.id),
                      onTapWatch: (id) => onSelectWatch(d.id, id),
                      onToggleExpand: () => onToggleExpand(d.id),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceNode extends ConsumerWidget {
  final DeviceConfig device;
  final DeviceConnState connState;
  final List<WatchSpec> watches;
  final bool isExpanded;
  final bool isSelectedDevice;
  final String? selectedWatchId;
  final VoidCallback onTapDevice;
  final ValueChanged<String> onTapWatch;
  final VoidCallback onToggleExpand;

  const _DeviceNode({
    required this.device,
    required this.connState,
    required this.watches,
    required this.isExpanded,
    required this.isSelectedDevice,
    required this.selectedWatchId,
    required this.onTapDevice,
    required this.onTapWatch,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DeviceRow(
          device: device,
          connState: connState,
          selected: isSelectedDevice,
          watchCount: watches.length,
          isExpanded: isExpanded,
          onTap: onTapDevice,
          onToggleExpand: onToggleExpand,
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.borderFaint),
                ),
              ),
              padding: const EdgeInsets.only(left: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...watches.map((w) => _WatchTreeRow(
                        spec: w,
                        selected: w.id == selectedWatchId,
                        onTap: () => onTapWatch(w.id),
                      )),
                  InkWell(
                    onTap: () async {
                      final spec = await showDialog<WatchSpec>(
                        context: context,
                        builder: (_) => AddWatchDialog(
                            initialDeviceId: device.id),
                      );
                      if (spec != null) onTapWatch(spec.id);
                    },
                    borderRadius: BorderRadius.circular(2),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 11, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('New watch',
                              style: AppType.caption
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  final DeviceConfig device;
  final DeviceConnState connState;
  final bool selected;
  final int watchCount;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;

  const _DeviceRow({
    required this.device,
    required this.connState,
    required this.selected,
    required this.watchCount,
    required this.isExpanded,
    required this.onTap,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
        decoration: BoxDecoration(
          color: selected ? AppColors.bgSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                left: 0,
                top: 4,
                bottom: 4,
                child: Container(width: 2, color: AppColors.accent),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: watchCount > 0 ? onToggleExpand : null,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 16,
                      height: 22,
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 14,
                        color: watchCount > 0
                            ? AppColors.textMuted
                            : AppColors.textFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  StatusDot(
                    status: ConnIndicator.dotFor(connState),
                    size: 8,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: AppType.body.copyWith(
                            color: AppColors.text,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            _TransportChip(tag: device.transportTag),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                device.addressLine,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.monoSm.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _MoreMenu(
                    items: const [
                      ('connect', 'Connect'),
                      ('disconnect', 'Disconnect'),
                      ('edit', 'Edit…'),
                      ('remove', 'Remove'),
                    ],
                    onSelected: (v) async {
                      final notifier = ref.read(deviceConnProvider.notifier);
                      switch (v) {
                        case 'connect':
                          await notifier.connect(device.id);
                        case 'disconnect':
                          await notifier.disconnect(device.id);
                        case 'edit':
                          await showDialog(
                            context: context,
                            builder: (_) => AddDeviceDialog(edit: device),
                          );
                        case 'remove':
                          await ref
                              .read(deviceListProvider.notifier)
                              .remove(device.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchTreeRow extends ConsumerWidget {
  final WatchSpec spec;
  final bool selected;
  final VoidCallback onTap;
  const _WatchTreeRow({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  String get _fcLabel => switch (spec.functionCode) {
        1 => 'FC01',
        2 => 'FC02',
        3 => 'FC03',
        4 => 'FC04',
        _ => 'FC${spec.functionCode}',
      };

  /// Tri-state poll status colour for the FC chip dot. Drives the chip dot
  /// only — we used to tint it by FC, but red/coral FC01/02 dots read as
  /// "error" at a glance. Now the colour ALWAYS reflects what's happening:
  ///   * green — last poll succeeded
  ///   * red   — last poll failed (or device is in error state)
  ///   * gray  — device disconnected / no poll yet (paused)
  Color _statusColor(DeviceConnState conn, PollResult? result) {
    if (conn == DeviceConnState.error) return AppColors.error;
    if (conn != DeviceConnState.connected) return AppColors.offline;
    if (result is PollErr) return AppColors.error;
    if (result is PollOk) return AppColors.online;
    return AppColors.offline;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connStateProvider(spec.deviceId));
    final result = ref.watch(watchResultProvider(spec.id));
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 26,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.bg4 : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            _FCChip(label: _fcLabel, tint: _statusColor(conn, result)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${spec.startAddress}–${spec.startAddress + spec.quantity - 1}',
                style: AppType.monoSm
                    .copyWith(fontSize: 10, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              spec.format.label,
              style: AppType.labelSm.copyWith(
                fontSize: 9,
                color: AppColors.textDim,
              ),
            ),
            _MoreMenu(
              dense: true,
              items: const [
                ('edit', 'Edit…'),
                ('remove', 'Remove'),
              ],
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    await showDialog(
                      context: context,
                      builder: (_) => AddWatchDialog(edit: spec),
                    );
                  case 'remove':
                    ref.read(watchListProvider.notifier).remove(spec.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FCChip extends StatelessWidget {
  final String label;
  final Color tint;
  const _FCChip({required this.label, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tri-state poll-status LED — round to read as a status light
          // rather than a "type" swatch.
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: tint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(label,
              style: AppType.labelSm.copyWith(
                fontSize: 9,
                color: AppColors.text,
              )),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;
  final bool dense;
  const _MoreMenu({
    required this.items,
    required this.onSelected,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      padding: EdgeInsets.zero,
      iconSize: dense ? 16 : 18,
      icon: Icon(Icons.more_vert,
          size: dense ? 14 : 16, color: AppColors.textMuted),
      color: AppColors.bg2,
      itemBuilder: (_) => [
        for (final (v, label) in items)
          PopupMenuItem(value: v, child: Text(label)),
      ],
      onSelected: onSelected,
    );
  }
}

// ─── Right pane: device header + watches toolbar + MDI ─────────────────────

class _RightPane extends ConsumerWidget {
  final _Selection selection;
  final void Function(String deviceId, String watchId) onSelectWatch;
  final GlobalKey<MdiWorkspaceState> mdiKey;
  const _RightPane({
    required this.selection,
    required this.onSelectWatch,
    required this.mdiKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // NOTE: `_EmptyHint()` is intentionally NOT const — its build reads
    // `AppColors.*` getters, and a const-canonical instance would let
    // Flutter short-circuit the element diff on every theme flip, leaving
    // the empty pane painted with the old palette.
    if (selection.deviceId == null) return _EmptyHint();
    final detail = ref.watch(deviceDetailProvider(selection.deviceId!));
    if (detail == null) return _EmptyHint();

    return Container(
      color: AppColors.bg1,
      child: Column(
        children: [
          _DeviceHeader(detail: detail),
          Container(height: 1, color: AppColors.border),
          _WatchesToolbar(
            detail: detail,
            onSelectWatch: (id) => onSelectWatch(detail.config.id, id),
            onLayout: (mode) => mdiKey.currentState?.applyLayout(mode),
            onRestoreAll: () => mdiKey.currentState?.restoreAll(),
            onCloseAll: () => mdiKey.currentState?.closeAll(),
            onResetCounters: () =>
                mdiKey.currentState?.resetCounters(detail.config.id),
          ),
          Container(height: 1, color: AppColors.border),
          Expanded(
            child: MdiWorkspace(
              key: mdiKey,
              watches: detail.watches,
              focusedWatchId: selection.watchId,
            ),
          ),
        ],
      ),
    );
  }
}

class _WatchesToolbar extends StatelessWidget {
  final DeviceDetail detail;
  final ValueChanged<String> onSelectWatch;
  final ValueChanged<MdiLayoutMode> onLayout;
  final VoidCallback onRestoreAll;
  final VoidCallback onCloseAll;
  final VoidCallback onResetCounters;
  const _WatchesToolbar({
    required this.detail,
    required this.onSelectWatch,
    required this.onLayout,
    required this.onRestoreAll,
    required this.onCloseAll,
    required this.onResetCounters,
  });

  @override
  Widget build(BuildContext context) {
    final hasWatches = detail.watches.isNotEmpty;
    return Container(
      height: 36,
      color: AppColors.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('WATCHES',
              style:
                  AppType.label.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Text('${detail.watches.length}',
              style: AppType.mono.copyWith(color: AppColors.text)),
          if (hasWatches) ...[
            const SizedBox(width: 8),
            Container(width: 1, height: 16, color: AppColors.border),
            const SizedBox(width: 8),
            _LayoutBtn(
              icon: Icons.dashboard_customize_outlined,
              tooltip: 'Cascade',
              active: true,
              onTap: () => onLayout(MdiLayoutMode.cascade),
            ),
            _LayoutBtn(
              icon: Icons.view_agenda_outlined,
              tooltip: 'Tile rows',
              onTap: () => onLayout(MdiLayoutMode.tileHorizontal),
            ),
            _LayoutBtn(
              icon: Icons.view_column_outlined,
              tooltip: 'Tile cols',
              onTap: () => onLayout(MdiLayoutMode.tileVertical),
            ),
            _LayoutBtn(
              icon: Icons.grid_view_outlined,
              tooltip: 'Grid',
              onTap: () => onLayout(MdiLayoutMode.grid),
            ),
            const SizedBox(width: 4),
            Container(width: 1, height: 16, color: AppColors.border),
            const SizedBox(width: 4),
            _LayoutBtn(
              icon: Icons.unfold_more,
              tooltip: 'Show all',
              onTap: onRestoreAll,
            ),
            _LayoutBtn(
              icon: Icons.close_fullscreen,
              tooltip: 'Close all',
              onTap: onCloseAll,
            ),
            _LayoutBtn(
              icon: Icons.restart_alt,
              tooltip: 'Reset counters',
              onTap: onResetCounters,
            ),
          ],
          const Spacer(),
          Consumer(builder: (context, ref, _) {
            return _MbtButton(
              kind: _ButtonKind.secondary,
              icon: Icons.add,
              label: 'New watch',
              onTap: () async {
                final spec = await showDialog<WatchSpec>(
                  context: context,
                  builder: (_) =>
                      AddWatchDialog(initialDeviceId: detail.config.id),
                );
                if (spec != null) onSelectWatch(spec.id);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _LayoutBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  const _LayoutBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_LayoutBtn> createState() => _LayoutBtnState();
}

class _LayoutBtnState extends State<_LayoutBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final hi = widget.active || _hover;
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
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  widget.active ? AppColors.accentBg : Colors.transparent,
              border: Border.all(
                color: widget.active
                    ? AppColors.accent
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(
              widget.icon,
              size: 13,
              color: hi ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  // Constructor is intentionally non-const — see the note at the
  // `_EmptyHint()` use sites. Allowing const construction would let
  // Flutter short-circuit theme-flip rebuilds for this subtree because
  // canonical const instances are `identical()` and the element diff
  // skips them.
  // ignore: prefer_const_constructors_in_immutables
  _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg1,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cable, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Select or add a device to start',
                style: AppType.bodySm
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ─── Device header ─────────────────────────────────────────────────────────

class _DeviceHeader extends ConsumerWidget {
  final DeviceDetail detail;
  const _DeviceHeader({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = detail.config;
    final conn = detail.conn;
    final lastError = conn == DeviceConnState.error
        ? ref.read(deviceHubProvider).device(cfg.id)?.lastError
        : null;
    return Container(
      color: AppColors.bg2,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cfg.name,
                        style: AppType.display
                            .copyWith(color: AppColors.text)),
                    const SizedBox(width: 10),
                    ConnIndicator(state: conn, showLabel: true, dotSize: 9),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransportChip(
                      tag: cfg.transportTag,
                      withAddress: true,
                      address: cfg.addressLine,
                    ),
                    if (lastError != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 11, color: AppColors.error),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(lastError,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppType.caption
                                      .copyWith(color: AppColors.error)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ConnectButton(detail: detail),
        ],
      ),
    );
  }
}

class _ConnectButton extends ConsumerWidget {
  final DeviceDetail detail;
  const _ConnectButton({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = detail.conn;
    final id = detail.config.id;
    final notifier = ref.read(deviceConnProvider.notifier);
    switch (conn) {
      case DeviceConnState.connected:
        return _MbtButton(
          kind: _ButtonKind.outline,
          icon: Icons.link_off,
          label: 'Disconnect',
          onTap: () => notifier.disconnect(id),
        );
      case DeviceConnState.connecting:
        return _MbtButton(
          kind: _ButtonKind.secondary,
          label: 'Connecting…',
          disabled: true,
        );
      case DeviceConnState.disconnected:
      case DeviceConnState.error:
        return _MbtButton(
          kind: _ButtonKind.primary,
          icon: Icons.power_settings_new,
          label: 'Connect',
          onTap: () => notifier.connect(id),
        );
    }
  }
}

/// Transport chip with optional mono-formatted address suffix.
class _TransportChip extends StatelessWidget {
  final String tag;
  final bool withAddress;
  final String? address;
  const _TransportChip({
    required this.tag,
    this.withAddress = false,
    this.address,
  });

  IconData get _icon =>
      tag == 'TCP' ? Icons.lan_outlined : Icons.usb;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: withAddress ? 20 : 16,
      padding: EdgeInsets.symmetric(
          horizontal: withAddress ? 6 : 4, vertical: 0),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            tag,
            style: AppType.labelSm.copyWith(
              fontSize: withAddress ? 10 : 9,
              color: AppColors.text,
            ),
          ),
          if (withAddress && address != null) ...[
            const SizedBox(width: 6),
            Text(
              address!,
              style: AppType.monoSm.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
