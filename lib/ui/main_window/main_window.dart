import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/device_hub.dart';
import '../../data/models/device_config.dart';
import '../../data/models/register_format.dart';
import '../../data/models/watch_spec.dart';
import '../../data/persistence/config_io.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import '../watch_window/mdi_workspace.dart';
import '../widgets/conn_indicator.dart';
import 'dialogs/add_device_dialog.dart';
import 'dialogs/add_watch_dialog.dart';

/// Main console — see GUI.md §S1.
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
  // Devices whose watch list is currently expanded.
  final Set<String> _expanded = {};
  final GlobalKey<MdiWorkspaceState> _mdiKey =
      GlobalKey<MdiWorkspaceState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final saved = await ConfigStore.load();
      if (!mounted) return;
      await applyConfig(ref, saved);
      ref.read(autoSaveProvider);
      // Auto-expand devices that already have watches.
      final watches = ref.read(watchListProvider);
      setState(() {
        _expanded.addAll(watches.map((w) => w.deviceId));
      });
    });
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

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);
    // Clear stale selection.
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
      drawer: isCompact ? Drawer(child: SafeArea(child: sidebar)) : null,
      body: SafeArea(
        child: Column(
          children: [
            _Toolbar(
              onAddDevice: _onAddDevice,
              onAddWatch: _onAddWatch,
              showMenu: isCompact,
            ),
            const Divider(height: 1),
            Expanded(
              child: isCompact
                  ? _RightPane(
                      selection: _selection,
                      onSelectWatch: _selectWatch,
                      mdiKey: _mdiKey,
                    )
                  : Row(
                      children: [
                        sidebar,
                        const VerticalDivider(width: 1),
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
    await showDialog(
      context: context,
      builder: (_) => const AddDeviceDialog(),
    );
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

class _Toolbar extends StatelessWidget {
  final VoidCallback onAddDevice;
  final VoidCallback onAddWatch;
  final bool showMenu;
  const _Toolbar({
    required this.onAddDevice,
    required this.onAddWatch,
    this.showMenu = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.bgRaised,
      child: Row(
        children: [
          if (showMenu) ...[
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, size: 20, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Devices',
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (!showMenu) const SizedBox(width: 4),
          _ToolBtn(label: '+ Device', onTap: onAddDevice),
          const SizedBox(width: 8),
          _ToolBtn(label: '+ Watch', onTap: onAddWatch),
          if (!showMenu) ...[
            const SizedBox(width: 8),
            Consumer(builder: (context, ref, _) {
              return _ToolBtn(
                label: 'Import',
                onTap: () => _import(context, ref),
              );
            }),
            const SizedBox(width: 8),
            Consumer(builder: (context, ref, _) {
              return _ToolBtn(
                label: 'Export',
                onTap: () => _export(context, ref),
              );
            }),
          ],
          const Spacer(),
          if (showMenu)
            Consumer(builder: (context, ref, _) {
              return PopupMenuButton<String>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert,
                    size: 20, color: AppColors.text),
                color: AppColors.panel,
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
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _ToolBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
              color: enabled ? AppColors.text : AppColors.textMuted,
              fontSize: 12,
            )),
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

    return Container(
      width: 260,
      color: AppColors.bgRaised,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text('DEVICES',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1.2)),
          ),
          if (devices.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'No devices.\nClick + Device to add one.',
                style:
                    TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            for (final d in devices)
              _DeviceNode(
                device: d,
                connState:
                    connStates[d.id] ?? DeviceConnState.disconnected,
                watches: watches.where((w) => w.deviceId == d.id).toList(),
                isExpanded: expanded.contains(d.id),
                isSelectedDevice:
                    selection.deviceId == d.id && selection.watchId == null,
                selectedWatchId: selection.watchId,
                onTapDevice: () => onSelectDevice(d.id),
                onTapWatch: (id) => onSelectWatch(d.id, id),
                onToggleExpand: () => onToggleExpand(d.id),
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
          ...watches.map((w) => _WatchTreeRow(
                spec: w,
                selected: w.id == selectedWatchId,
                onTap: () => onTapWatch(w.id),
              )),
        if (isExpanded)
          Padding(
            padding:
                const EdgeInsets.only(left: 32, top: 2, bottom: 6, right: 12),
            child: InkWell(
              onTap: () async {
                final spec = await showDialog<WatchSpec>(
                  context: context,
                  builder: (_) =>
                      AddWatchDialog(initialDeviceId: device.id),
                );
                if (spec != null) onTapWatch(spec.id);
              },
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text('+ New watch',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
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
        decoration: BoxDecoration(
          color: selected ? AppColors.bg : Colors.transparent,
          border: selected
              ? const Border(
                  left: BorderSide(color: AppColors.brand, width: 2))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 22, minHeight: 22),
              onPressed: watchCount > 0 ? onToggleExpand : null,
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: watchCount > 0
                    ? AppColors.text
                    : AppColors.textMuted.withValues(alpha: 0.4),
              ),
            ),
            ConnIndicator(state: connState, dotSize: 8),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.text)),
                  Row(
                    children: [
                      _TransportChip(tag: device.transportTag),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          device.addressLine,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert,
                  size: 14, color: AppColors.textMuted),
              color: AppColors.panel,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'connect', child: Text('Connect')),
                const PopupMenuItem(
                    value: 'disconnect', child: Text('Disconnect')),
                const PopupMenuItem(value: 'edit', child: Text('Edit…')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
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

  String get _fcLabel {
    switch (spec.functionCode) {
      case 1:
        return 'FC01';
      case 2:
        return 'FC02';
      case 3:
        return 'FC03';
      case 4:
        return 'FC04';
      default:
        return 'FC${spec.functionCode}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.12)
              : Colors.transparent,
          border: selected
              ? const Border(
                  left:
                      BorderSide(color: AppColors.brand, width: 2))
              : const Border(
                  left: BorderSide(color: Colors.transparent, width: 2)),
        ),
        padding:
            const EdgeInsets.fromLTRB(34, 4, 6, 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_fcLabel · ${spec.startAddress}–${spec.startAddress + spec.quantity - 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          selected ? AppColors.text : AppColors.text,
                    ),
                  ),
                  Text(
                    spec.format.label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz,
                  size: 14, color: AppColors.textMuted),
              color: AppColors.panel,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit…')),
                const PopupMenuItem(value: 'remove', child: Text('Remove')),
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

// ─── Right pane: device header + watch pane (or hint) ──────────────────────

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
    if (selection.deviceId == null) return const _EmptyHint();
    final detail = ref.watch(deviceDetailProvider(selection.deviceId!));
    if (detail == null) return const _EmptyHint();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          _DeviceHeader(detail: detail),
          const Divider(height: 1),
          _WatchesToolbar(
            detail: detail,
            onSelectWatch: (id) => onSelectWatch(detail.config.id, id),
            onLayout: (mode) => mdiKey.currentState?.applyLayout(mode),
            onRestoreAll: () => mdiKey.currentState?.restoreAll(),
            onCloseAll: () => mdiKey.currentState?.closeAll(),
            onResetCounters: () =>
                mdiKey.currentState?.resetCounters(detail.config.id),
          ),
          const Divider(height: 1),
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

/// Slim toolbar between device header and MDI workspace.
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.bgRaised,
      child: Row(
        children: [
          Text(
            'WATCHES (${detail.watches.length})',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasWatches) ...[
            const SizedBox(width: 16),
            _LayoutBtn(
              icon: Icons.dashboard_customize_outlined,
              tooltip: 'Cascade',
              onTap: () => onLayout(MdiLayoutMode.cascade),
            ),
            _LayoutBtn(
              icon: Icons.view_agenda_outlined,
              tooltip: 'Tile horizontal (rows)',
              onTap: () => onLayout(MdiLayoutMode.tileHorizontal),
            ),
            _LayoutBtn(
              icon: Icons.view_column_outlined,
              tooltip: 'Tile vertical (columns)',
              onTap: () => onLayout(MdiLayoutMode.tileVertical),
            ),
            _LayoutBtn(
              icon: Icons.grid_view_outlined,
              tooltip: 'Grid',
              onTap: () => onLayout(MdiLayoutMode.grid),
            ),
            const SizedBox(width: 4),
            _LayoutBtn(
              icon: Icons.unfold_more,
              tooltip: 'Show all (restore hidden / minimized)',
              onTap: onRestoreAll,
            ),
            _LayoutBtn(
              icon: Icons.close_fullscreen,
              tooltip: 'Close all sub-windows',
              onTap: onCloseAll,
            ),
            _LayoutBtn(
              icon: Icons.restart_alt,
              tooltip: 'Reset OK / ERR counters',
              onTap: onResetCounters,
            ),
          ],
          const Spacer(),
          Consumer(builder: (context, ref, _) {
            return TextButton.icon(
              style:
                  TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () async {
                final spec = await showDialog<WatchSpec>(
                  context: context,
                  builder: (_) =>
                      AddWatchDialog(initialDeviceId: detail.config.id),
                );
                if (spec != null) onSelectWatch(spec.id);
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New watch', style: TextStyle(fontSize: 12)),
            );
          }),
        ],
      ),
    );
  }
}

class _LayoutBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _LayoutBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 26,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cable, size: 48, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text('Select or add a device to start',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cfg.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(width: 12),
                    ConnIndicator(
                        state: detail.conn,
                        showLabel: true,
                        dotSize: 10),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TransportChip(tag: cfg.transportTag),
                    const SizedBox(width: 6),
                    Text(cfg.addressLine,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
                if (detail.conn == DeviceConnState.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ref
                              .read(deviceHubProvider)
                              .device(cfg.id)
                              ?.lastError ??
                          'Connection failed',
                      style: const TextStyle(
                          color: AppColors.connError, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: detail.conn == DeviceConnState.connected
                ? () => ref
                    .read(deviceConnProvider.notifier)
                    .disconnect(cfg.id)
                : detail.conn == DeviceConnState.connecting
                    ? null
                    : () => ref
                        .read(deviceConnProvider.notifier)
                        .connect(cfg.id),
            child: Text(
              detail.conn == DeviceConnState.connected
                  ? 'Disconnect'
                  : 'Connect',
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportChip extends StatelessWidget {
  final String tag;
  const _TransportChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
