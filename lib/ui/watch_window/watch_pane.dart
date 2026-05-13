import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/codec/format_codec.dart';
import '../../core/modbus/raw_packet.dart';
import '../../core/runtime/device_hub.dart';
import '../../core/runtime/poll_result.dart';
import '../../data/models/device_config.dart';
import '../../data/models/register_format.dart';
import '../../data/models/watch_spec.dart';
import '../../state/app_state.dart';
import '../main_window/dialogs/add_watch_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/conn_indicator.dart';

enum PaneView { table, comm, errors }

/// Watch Pane — see GUI.md §S2a.
///
/// One pane shows ONE poll target. The user toggles between:
///   * **Table** — smart multi-column grid of address/value pairs.
///   * **Comm**  — TX/RX packet log filtered to this pane's device.
///
/// All addresses shown to the user are **1-based** (ModScan convention).
/// The wire address is computed by subtracting 1 in the runtime layer.
class WatchPane extends ConsumerStatefulWidget {
  final WatchSpec spec;
  final VoidCallback? onClose;
  final VoidCallback? onSplit;

  const WatchPane({
    super.key,
    required this.spec,
    this.onClose,
    this.onSplit,
  });

  @override
  ConsumerState<WatchPane> createState() => _WatchPaneState();
}

class _WatchPaneState extends ConsumerState<WatchPane> {
  late RegisterFormat _format;
  late int _asciiChars;
  PaneView _view = PaneView.table;

  @override
  void initState() {
    super.initState();
    _format = sanitizeFormat(widget.spec.format, widget.spec.functionCode);
    _asciiChars = widget.spec.asciiCharsPerRow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(liveWatchProvider.notifier)
          .ensureDevicePolling(widget.spec.deviceId);
    });
  }

  @override
  void didUpdateWidget(covariant WatchPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec != widget.spec) {
      // FC may have changed — re-sanitize the format.
      _format = sanitizeFormat(widget.spec.format, widget.spec.functionCode);
      // No loop restart needed — the device loop reads the watch list
      // fresh on every cycle.
    }
  }

  bool get _isBitMode =>
      widget.spec.functionCode == 1 || widget.spec.functionCode == 2;

  /// Quick-edit shortcut on the pane header — same dialog as the sidebar's
  /// PopupMenu Edit entry, just one click closer when you've already got
  /// the pane open.
  Future<void> _openEditWatch() async {
    await showDialog<WatchSpec>(
      context: context,
      builder: (_) => AddWatchDialog(edit: widget.spec),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-arm polling whenever the device comes online — covers both the
    // first-connect case (the postFrame call in initState ran while the
    // device was still disconnected) and reconnect after a manual
    // disconnect (the prior PollLoop is stopped and bound to a dead client).
    ref.listen<DeviceConnState>(connStateProvider(widget.spec.deviceId),
        (prev, next) {
      if (next == DeviceConnState.connected &&
          prev != DeviceConnState.connected) {
        ref
            .read(liveWatchProvider.notifier)
            .ensureDevicePolling(widget.spec.deviceId);
      }
    });
    final result = ref.watch(watchResultProvider(widget.spec.id));
    final connState = ref.watch(connStateProvider(widget.spec.deviceId));
    final device = ref.watch(deviceListProvider).firstWhere(
          (d) => d.id == widget.spec.deviceId,
          orElse: () => const DeviceConfig(id: '', name: '?'),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PaneHeader(
            spec: widget.spec,
            device: device,
            connState: connState,
            view: _view,
            onViewChanged: (v) => setState(() => _view = v),
            onEdit: _openEditWatch,
            onClose: widget.onClose,
            onSplit: widget.onSplit,
          ),
          if (_view == PaneView.table)
            _FormatBar(
              format: _format,
              asciiChars: _asciiChars,
              isBitMode: _isBitMode,
              running: result is PollOk || result is PollErr,
              onChanged: (f) => setState(() => _format = f),
              onAsciiChange: (n) => setState(() => _asciiChars = n),
            ),
          const Divider(height: 1),
          Expanded(
            child: switch (_view) {
              PaneView.table => connState != DeviceConnState.connected
                  ? _NotConnectedHint(connState: connState)
                  : _TableView(
                      spec: widget.spec,
                      format: _isBitMode ? RegisterFormat.bool_ : _format,
                      asciiChars: _asciiChars,
                      result: result,
                    ),
              PaneView.comm => _CommView(deviceId: widget.spec.deviceId),
              PaneView.errors => _ErrorView(deviceId: widget.spec.deviceId),
            },
          ),
          const Divider(height: 1),
          _PaneFooter(spec: widget.spec, result: result),
        ],
      ),
    );
  }
}

// ─── Header (with Table/Comm toggle) ───────────────────────────────────────

class _PaneHeader extends StatelessWidget {
  final WatchSpec spec;
  final DeviceConfig device;
  final DeviceConnState connState;
  final PaneView view;
  final ValueChanged<PaneView> onViewChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback? onSplit;

  const _PaneHeader({
    required this.spec,
    required this.device,
    required this.connState,
    required this.view,
    required this.onViewChanged,
    this.onEdit,
    this.onClose,
    this.onSplit,
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

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (connState) {
      DeviceConnState.connected => AppColors.brand,
      DeviceConnState.connecting => AppColors.warn,
      DeviceConnState.error => AppColors.danger,
      DeviceConnState.disconnected => AppColors.textMuted,
    };
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.bgRaised,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${device.name} · $_fcLabel · '
              '${spec.startAddress}–${spec.startAddress + spec.quantity - 1} · ${device.pollIntervalMs}ms',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _ViewToggle(
              deviceId: spec.deviceId,
              value: view,
              onChanged: onViewChanged),
          if (onEdit != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Edit watch',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.edit, size: 14),
              onPressed: onEdit,
            ),
          ],
          if (onSplit != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Split',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.splitscreen, size: 14),
              onPressed: onSplit,
            ),
          ],
          if (onClose != null)
            IconButton(
              tooltip: 'Close pane',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 14),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  final String deviceId;
  final PaneView value;
  final ValueChanged<PaneView> onChanged;
  const _ViewToggle({
    required this.deviceId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorCount = ref
        .watch(errorLogProvider)
        .where((e) => e.deviceId == deviceId)
        .length;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Table', PaneView.table),
          _toggleButton('Comm', PaneView.comm),
          _toggleButton(
            'Error',
            PaneView.errors,
            badge: errorCount,
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, PaneView v, {int badge = 0}) {
    final active = v == value;
    final activeColor =
        v == PaneView.errors && badge > 0 ? AppColors.danger : AppColors.brand;
    return InkWell(
      onTap: () => onChanged(v),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        color: active
            ? activeColor.withValues(alpha: 0.18)
            : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: active
                    ? activeColor
                    : (badge > 0 && v == PaneView.errors
                        ? AppColors.danger
                        : AppColors.textMuted),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Format selector ────────────────────────────────────────────────────────

class _FormatBar extends StatelessWidget {
  final RegisterFormat format;
  final int asciiChars;
  final bool isBitMode;
  final bool running;
  final ValueChanged<RegisterFormat> onChanged;
  final ValueChanged<int> onAsciiChange;
  const _FormatBar({
    required this.format,
    required this.asciiChars,
    required this.isBitMode,
    required this.running,
    required this.onChanged,
    required this.onAsciiChange,
  });

  static const _options = [
    RegisterFormat.u16,
    RegisterFormat.i16,
    RegisterFormat.hex,
    RegisterFormat.bin,
    RegisterFormat.u32be,
    RegisterFormat.u32le,
    RegisterFormat.i32be,
    RegisterFormat.i32le,
    RegisterFormat.f32be,
    RegisterFormat.f32le,
    RegisterFormat.ascii,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Text('Format',
              style:
                  TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          if (isBitMode)
            const Text('Bool',
                style: TextStyle(fontSize: 12, color: AppColors.text))
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RegisterFormat>(
                  value: format,
                  isDense: true,
                  dropdownColor: AppColors.panel,
                  items: [
                    for (final f in _options)
                      DropdownMenuItem(
                          value: f,
                          child: Text(f.label,
                              style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (f) {
                    if (f != null) onChanged(f);
                  },
                ),
              ),
            ),
          if (format == RegisterFormat.ascii && !isBitMode) ...[
            const SizedBox(width: 8),
            const Text('chars/row',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(width: 4),
            SizedBox(
              width: 48,
              height: 24,
              child: TextField(
                controller: TextEditingController(text: '$asciiChars'),
                style: const TextStyle(fontSize: 12),
                textAlignVertical: TextAlignVertical.center,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6),
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.border)),
                ),
                onSubmitted: (v) =>
                    onAsciiChange(int.tryParse(v) ?? asciiChars),
              ),
            ),
          ],
          const Spacer(),
          if (running)
            Row(children: const [
              Icon(Icons.circle, size: 6, color: AppColors.brand),
              SizedBox(width: 4),
              Text('Polling',
                  style: TextStyle(fontSize: 11, color: AppColors.brand)),
            ]),
        ],
      ),
    );
  }
}

// ─── Footer ─────────────────────────────────────────────────────────────────

class _PaneFooter extends ConsumerWidget {
  final WatchSpec spec;
  final PollResult? result;
  const _PaneFooter({required this.spec, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe so that a "Reset counters" action causes an instant rebuild
    // (otherwise the footer waits for the next poll cycle).
    ref.watch(statsTickProvider);
    final loop = ref.read(deviceHubProvider).devicePoll(spec.deviceId);
    if (loop == null) return const SizedBox(height: 24);
    final s = loop.statsFor(spec.id);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(
            'OK ${s.success}  ERR ${s.errors}  Avg ${s.avgLatency.inMilliseconds}ms',
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted),
          ),
          const Spacer(),
          if (result is PollErr)
            Flexible(
              child: Text(
                (result as PollErr).error.toString(),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.danger),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dense multi-column table — every cell shows its absolute address ──────

class _TableView extends ConsumerStatefulWidget {
  final WatchSpec spec;
  final RegisterFormat format;
  final int asciiChars;
  final PollResult? result;
  const _TableView({
    required this.spec,
    required this.format,
    required this.asciiChars,
    required this.result,
  });

  @override
  ConsumerState<_TableView> createState() => _TableViewState();
}

class _TableViewState extends ConsumerState<_TableView> {
  /// Optimistic bool overrides keyed by cell index. While a write is in
  /// flight we display the user's desired value so the toggle feels
  /// instant; on completion the entry is dropped and the next poll result
  /// takes over (or, on failure, the error snackbar replaces it).
  final Map<int, bool> _pendingBool = {};

  bool get _isBitMode =>
      widget.spec.functionCode == 1 || widget.spec.functionCode == 2;

  /// FC03 / FC04 in `bin` format — the register is displayed as 16 bits, and
  /// the edit popup is a checkbox grid (one per bit) rather than a freeform
  /// text input. Much harder to fat-finger an HOA / interlock bit this way.
  bool get _isBinFormat =>
      !_isBitMode && widget.format == RegisterFormat.bin;

  /// Registers per value cell (0 for bit mode).
  int get _regsPerCell {
    if (_isBitMode) return 0;
    final c = codecFor(widget.format, asciiCharsPerRow: widget.asciiChars);
    return c.registersPerValue == -1
        ? (widget.asciiChars + 1) ~/ 2
        : c.registersPerValue;
  }

  /// Cell width in pixels — sized so the value never truncates for the
  /// chosen format. On touch platforms the cell text is bigger so widths
  /// scale up roughly 1.15× plus a fixed bump for the larger address column.
  double _cellWidth() {
    final t = isTouchPlatform;
    switch (widget.format) {
      case RegisterFormat.u16:
      case RegisterFormat.i16:
        return t ? 130 : 110;
      case RegisterFormat.hex:
        return t ? 138 : 116;
      case RegisterFormat.bin:
        return t ? 250 : 220;
      case RegisterFormat.u32be:
      case RegisterFormat.u32le:
      case RegisterFormat.i32be:
      case RegisterFormat.i32le:
        return t ? 178 : 152;
      case RegisterFormat.f32be:
      case RegisterFormat.f32le:
        return t ? 180 : 154;
      case RegisterFormat.ascii:
        return (t ? 78.0 : 64.0) + widget.asciiChars * (t ? 9 : 8);
      case RegisterFormat.bool_:
        return t ? 150 : 130;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    if (result == null) {
      return const Center(
        child: Text('Waiting for first poll…',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
    }
    if (result is PollErr) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Read error: ${result.error}',
              style:
                  const TextStyle(color: AppColors.connError, fontSize: 12)),
        ),
      );
    }
    final ok = result as PollOk;
    final regs = ok.values;
    final spec = widget.spec;
    final codec =
        codecFor(widget.format, asciiCharsPerRow: widget.asciiChars);

    final cellCount = _isBitMode
        ? regs.length
        : (regs.length / _regsPerCell).floor();
    final cellW = _cellWidth();

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 4.0;
        final cellH = isTouchPlatform ? 36.0 : 22.0;
        final availableH = c.maxHeight - 8;

        // Lay out cells column-major: top to bottom, then wrap right.
        var perCol = ((availableH + gap) / (cellH + gap)).floor();
        if (perCol < 1) perCol = 1;
        final colCount = (cellCount / perCol).ceil();

        final cells = List<Widget>.generate(cellCount, (i) {
          final address = _isBitMode
              ? spec.startAddress + i
              : spec.startAddress + i * _regsPerCell;
          final boolDisplay = _isBitMode
              ? (_pendingBool[i] ?? (regs[i] != 0))
              : false;
          final display = _isBitMode
              ? (boolDisplay ? 'TRUE' : 'FALSE')
              : codec.decode(regs, i * _regsPerCell);
          return _DenseCell(
            // Stable key per cell — without it List.generate produces fresh
            // widget identities on every poll rebuild, which forced the
            // editor's State to recreate. (Old inline editor lost focus
            // mid-typing; the popup model doesn't care, but the key still
            // keeps RepaintBoundary scope and avoids needless work.)
            key: ValueKey('${spec.id}:$i'),
            address: address,
            value: display,
            width: cellW,
            isBitMode: _isBitMode,
            pendingWrite: _isBitMode && _pendingBool.containsKey(i),
            onTapEdit: _isBitMode
                ? null
                : (_isBinFormat
                    ? () => _openBitsEditDialog(i, regs)
                    : () => _openEditDialog(i, display)),
            onToggle: _isBitMode ? () => _toggleBool(i) : null,
          );
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(4),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var col = 0; col < colCount; col++) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var row = 0;
                        row < perCol &&
                            (col * perCol + row) < cellCount;
                        row++) ...[
                      cells[col * perCol + row],
                      if (row + 1 < perCol &&
                          (col * perCol + row + 1) < cellCount)
                        const SizedBox(height: gap),
                    ],
                  ],
                ),
                if (col + 1 < colCount) const SizedBox(width: gap),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Open the modal write-value dialog for cell [cellIdx] and, on submit,
  /// write the new value via the device hub.
  Future<void> _openEditDialog(int cellIdx, String currentValue) async {
    final spec = widget.spec;
    final address = spec.startAddress + cellIdx * _regsPerCell;
    final formatLabel = widget.format.label;
    final hint = _formatHint(widget.format, widget.asciiChars);
    final encoder = codecFor(widget.format, asciiCharsPerRow: widget.asciiChars);

    final newText = await showDialog<String>(
      context: context,
      builder: (_) => _EditValueDialog(
        title: 'Write to register $address',
        subtitle: '$formatLabel · $hint',
        initialValue: currentValue,
        validate: (text) {
          try {
            encoder.encode(text);
            return null;
          } catch (e) {
            return e.toString();
          }
        },
      ),
    );
    if (newText == null || !mounted) return;

    final hub = ref.read(deviceHubProvider);
    try {
      final regs = encoder.encode(newText);
      await hub.writeRegisters(spec.deviceId, spec.unitId, address, regs);
      await ref.read(liveWatchProvider.notifier).refreshOnce(spec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Write failed: $e',
                style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Bool toggle with optimistic UI: flip the displayed value immediately,
  /// fire the write, and only clear the override once we have a fresh poll
  /// result (or on error). Makes the tap feel instant even on slow buses.
  Future<void> _toggleBool(int cellIdx) async {
    final spec = widget.spec;
    final result = widget.result;
    if (result is! PollOk) return;
    final currentValue = result.values[cellIdx] != 0;
    final desired = !(_pendingBool[cellIdx] ?? currentValue);

    setState(() => _pendingBool[cellIdx] = desired);

    final hub = ref.read(deviceHubProvider);
    final address = spec.startAddress + cellIdx;
    try {
      await hub.writeCoil(spec.deviceId, spec.unitId, address, desired);
      await ref.read(liveWatchProvider.notifier).refreshOnce(spec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Toggle failed: $e',
                style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingBool.remove(cellIdx));
    }
  }

  /// Bin-format write popup: 16 checkboxes (one per bit) for the register
  /// at [cellIdx]. The dialog returns the new 16-bit value (or null on
  /// cancel) and the write goes out via FC06.
  Future<void> _openBitsEditDialog(int cellIdx, List<int> allRegs) async {
    final spec = widget.spec;
    final address = spec.startAddress + cellIdx * _regsPerCell;
    final current = allRegs[cellIdx * _regsPerCell] & 0xFFFF;

    final newValue = await showDialog<int>(
      context: context,
      builder: (_) => _EditBitsDialog(
        title: 'Write to register $address',
        initialValue: current,
      ),
    );
    if (newValue == null || !mounted) return;
    if (newValue == current) return; // user confirmed same value — skip

    final hub = ref.read(deviceHubProvider);
    try {
      await hub.writeRegisters(spec.deviceId, spec.unitId, address, [newValue]);
      await ref.read(liveWatchProvider.notifier).refreshOnce(spec);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Write failed: $e',
                style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Human-readable input hint per format. Mirrors what `FormatCodec.encode`
/// will actually accept.
String _formatHint(RegisterFormat f, int asciiChars) {
  switch (f) {
    case RegisterFormat.u16:
      return '0..65535';
    case RegisterFormat.i16:
      return '−32768..32767';
    case RegisterFormat.hex:
      return '0x0000..0xFFFF (hex digits)';
    case RegisterFormat.bin:
      return '16-bit binary (1s and 0s)';
    case RegisterFormat.u32be:
    case RegisterFormat.u32le:
      return '0..4294967295';
    case RegisterFormat.i32be:
    case RegisterFormat.i32le:
      return '−2147483648..2147483647';
    case RegisterFormat.f32be:
    case RegisterFormat.f32le:
      return 'IEEE-754 float (e.g. 3.14, -1.5e3)';
    case RegisterFormat.ascii:
      return 'up to $asciiChars ASCII chars';
    case RegisterFormat.bool_:
      return 'TRUE / FALSE / 1 / 0';
  }
}

/// One compact `addr value` cell. Bool mode is a click-to-toggle pill;
/// other formats open the [_EditValueDialog] popup on double-tap / long-press.
///
/// Wrapped in [RepaintBoundary] so an unchanged cell doesn't repaint just
/// because a sibling's value moved.
class _DenseCell extends StatelessWidget {
  final int address;
  final String value;
  final double width;
  final bool isBitMode;

  /// True while an in-flight coil write is awaiting confirmation. The cell
  /// renders with a subtle indicator so the user knows the optimistic flip
  /// hasn't been committed to the slave yet.
  final bool pendingWrite;

  /// Tapped to open the edit popup. Null in bit mode (the bool pill handles
  /// taps directly).
  final VoidCallback? onTapEdit;

  /// Tapped to toggle the bool. Null in non-bit mode.
  final VoidCallback? onToggle;

  const _DenseCell({
    super.key,
    required this.address,
    required this.value,
    required this.width,
    required this.isBitMode,
    required this.pendingWrite,
    required this.onTapEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = isTouchPlatform;
    final cellH = t ? 36.0 : 22.0;
    final addrW = t ? 60.0 : 52.0;
    final addrFontSize = t ? 12.0 : 11.0;
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: cellH,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgRaised,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: addrW,
                child: Text(
                  '$address',
                  style: TextStyle(
                    fontSize: addrFontSize,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(child: _valueWidget()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueWidget() {
    final t = isTouchPlatform;
    final valueFontSize = t ? 13.0 : 11.0;
    if (isBitMode) {
      return _BoolPill(
        value: value == 'TRUE',
        pending: pendingWrite,
        onTap: onToggle,
      );
    }
    return GestureDetector(
      // Touch platforms use long-press (double-tap clashes with system
      // text-selection gestures); desktop keeps double-tap.
      onDoubleTap: t ? null : onTapEdit,
      onLongPress: t ? onTapEdit : null,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontFamily: 'monospace',
            color: AppColors.text,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Compact bool toggle for use inside dense cells.
///
/// [pending] = an in-flight write whose echo we're waiting on. Renders with
/// reduced opacity so the user knows the displayed value is optimistic.
class _BoolPill extends StatelessWidget {
  final bool value;
  final bool pending;
  final VoidCallback? onTap;
  const _BoolPill({required this.value, this.pending = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        value ? AppColors.connConnected : AppColors.connDisconnected;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: pending ? 0.55 : 1.0,
          child: Container(
            width: 56,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              border: Border.all(color: color, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              value ? 'TRUE' : 'FALSE',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Not-connected hint ────────────────────────────────────────────────────

class _NotConnectedHint extends StatelessWidget {
  final DeviceConnState connState;
  const _NotConnectedHint({required this.connState});

  @override
  Widget build(BuildContext context) {
    final color = ConnIndicator.colorFor(connState);
    final label = ConnIndicator.labelFor(connState);
    final icon = connState == DeviceConnState.error
        ? Icons.error_outline
        : connState == DeviceConnState.connecting
            ? Icons.sync
            : Icons.power_off_outlined;

    // LayoutBuilder picks one of three densities based on the pane size, so
    // the hint stays readable from full-screen down to a 280×140 sub-window
    // without overflowing.
    return LayoutBuilder(
      builder: (context, c) {
        final isTiny = c.maxHeight < 80 || c.maxWidth < 200;
        final isCompact = !isTiny && (c.maxHeight < 140 || c.maxWidth < 260);

        if (isTiny) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: isCompact ? 22 : 30, color: color),
                  SizedBox(height: isCompact ? 4 : 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: isCompact ? 2 : 4),
                  const Text(
                    '請先連線此設備',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Comm view (per-device packet log) ─────────────────────────────────────

class _CommView extends ConsumerWidget {
  final String deviceId;
  const _CommView({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(rawLogProvider);
    final mine = all.where((p) => p.deviceId == deviceId).toList();
    if (mine.isEmpty) {
      return const Center(
        child: Text('No packets yet — connect and start polling.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
    }
    return ListView.builder(
      reverse: true,
      itemCount: mine.length,
      itemBuilder: (_, i) {
        final p = mine[mine.length - 1 - i];
        final ts = '${p.time.hour.toString().padLeft(2, '0')}:'
            '${p.time.minute.toString().padLeft(2, '0')}:'
            '${p.time.second.toString().padLeft(2, '0')}.'
            '${p.time.millisecond.toString().padLeft(3, '0')}';
        final hex = p.bytes
            .map((b) =>
                b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');
        final summary = _frameSummary(p);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: const BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(ts,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textMuted,
                    )),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  p.directionLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: p.isTx ? AppColors.brand : AppColors.warn,
                  ),
                ),
              ),
              if (summary != null)
                SizedBox(
                  width: 130,
                  child: Text(
                    summary.text,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: summary.isException
                          ? AppColors.danger
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  hex,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FrameSummary {
  final String text;
  final bool isException;
  const _FrameSummary(this.text, {required this.isException});
}

/// Build the short FC summary shown in the Comm view, transport-aware.
/// Returns null if the frame is too short to parse.
_FrameSummary? _frameSummary(RawPacket p) {
  final mbap = p.mbap;
  if (mbap != null) {
    return _FrameSummary(
      'unit=${mbap.unitId.toRadixString(16).padLeft(2, '0').toUpperCase()} '
      'FC=${(mbap.functionCode & 0x7F).toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${mbap.isException ? "*" : ""}',
      isException: mbap.isException,
    );
  }
  final rtu = p.rtu;
  if (rtu != null) {
    return _FrameSummary(
      'slv=${rtu.slaveId.toRadixString(16).padLeft(2, '0').toUpperCase()} '
      'FC=${(rtu.functionCode & 0x7F).toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${rtu.isException ? "*" : ""}',
      isException: rtu.isException,
    );
  }
  return null;
}

// ─── Error view (per-device error log) ─────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  final String deviceId;
  const _ErrorView({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(errorLogProvider);
    final mine = all.where((e) => e.deviceId == deviceId).toList();

    return Column(
      children: [
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: AppColors.bgRaised,
          child: Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${mine.length} error${mine.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (mine.isNotEmpty)
                InkWell(
                  onTap: () => ref
                      .read(errorLogProvider.notifier)
                      .clearDevice(deviceId),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: mine.isEmpty
              ? const Center(
                  child: Text('No errors logged for this device.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: mine.length,
                  itemBuilder: (_, i) {
                    final e = mine[mine.length - 1 - i];
                    final ts = '${e.time.hour.toString().padLeft(2, '0')}:'
                        '${e.time.minute.toString().padLeft(2, '0')}:'
                        '${e.time.second.toString().padLeft(2, '0')}.'
                        '${e.time.millisecond.toString().padLeft(3, '0')}';
                    final srcLabel = switch (e.source) {
                      ErrorSource.connect => 'CONN',
                      ErrorSource.poll => 'POLL',
                    };
                    final srcColor = switch (e.source) {
                      ErrorSource.connect => AppColors.warn,
                      ErrorSource.poll => AppColors.danger,
                    };
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: AppColors.border, width: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(ts,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.textMuted,
                                )),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              srcLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: srcColor,
                              ),
                            ),
                          ),
                          if (e.watchLabel != null)
                            SizedBox(
                              width: 140,
                              child: Text(
                                e.watchLabel!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Expanded(
                            child: SelectableText(
                              e.message,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.text,
                              ),
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Modal dialog for entering a new register value.
///
/// Returns the entered text on submit, null on cancel. Validates locally on
/// submit (the codec's encoder is the source of truth) so the user gets
/// immediate feedback for things like out-of-range values without waiting
/// for the slave to bounce the write back.
class _EditValueDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String initialValue;

  /// Returns null if the input is valid, otherwise an error message that
  /// will be shown inline. Run synchronously on submit.
  final String? Function(String) validate;

  const _EditValueDialog({
    required this.title,
    required this.subtitle,
    required this.initialValue,
    required this.validate,
  });

  @override
  State<_EditValueDialog> createState() => _EditValueDialogState();
}

class _EditValueDialogState extends State<_EditValueDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text;
    final err = widget.validate(text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: AppColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg,
                  errorText: _error,
                  errorStyle: const TextStyle(
                      fontSize: 11, color: AppColors.connError),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                ),
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Write'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal dialog for writing a 16-bit register one bit at a time.
///
/// 16 checkboxes laid out MSB-on-the-left (bit 15 → bit 0), grouped into
/// nibbles for readability and to match the binary display in the table.
/// The live preview at the bottom shows hex / decimal so you can sanity-
/// check the final value before clicking Write.
///
/// Returns the new 16-bit value (or null on Cancel). The caller is
/// responsible for the actual FC06 write.
class _EditBitsDialog extends StatefulWidget {
  final String title;
  final int initialValue; // 0..0xFFFF

  const _EditBitsDialog({
    required this.title,
    required this.initialValue,
  });

  @override
  State<_EditBitsDialog> createState() => _EditBitsDialogState();
}

class _EditBitsDialogState extends State<_EditBitsDialog> {
  late int _value = widget.initialValue & 0xFFFF;

  bool _bit(int i) => (_value & (1 << i)) != 0;

  void _setBit(int i, bool v) {
    setState(() {
      _value = v ? (_value | (1 << i)) : (_value & ~(1 << i));
      _value &= 0xFFFF;
    });
  }

  String get _binStr {
    final b = _value.toRadixString(2).padLeft(16, '0');
    return '${b.substring(0, 4)} ${b.substring(4, 8)} '
        '${b.substring(8, 12)} ${b.substring(12, 16)}';
  }

  String get _hexStr =>
      '0x${_value.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Holding register · 16 bits (MSB ← bit 15 … bit 0 → LSB)',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              // Two rows of 8 cells. The high byte (bits 15..8) is on top so
              // the visual order matches a binary literal.
              Column(
                children: [
                  _BitRow(
                    bits: const [15, 14, 13, 12, 11, 10, 9, 8],
                    get: _bit,
                    set: _setBit,
                  ),
                  const SizedBox(height: 4),
                  _BitRow(
                    bits: const [7, 6, 5, 4, 3, 2, 1, 0],
                    get: _bit,
                    set: _setBit,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _binStr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_hexStr  ·  dec $_value',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _value = 0),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Clear all'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _value = 0xFFFF),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Set all'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _value = (~_value) & 0xFFFF),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 28),
                    ),
                    child: const Text('Invert'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_value),
                    child: const Text('Write'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One half-register row: 8 bit checkboxes with the bit number above each.
class _BitRow extends StatelessWidget {
  final List<int> bits;
  final bool Function(int) get;
  final void Function(int, bool) set;

  const _BitRow({required this.bits, required this.get, required this.set});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final b in bits) ...[
          Expanded(child: _BitCheckbox(bit: b, value: get(b), onChanged: (v) => set(b, v))),
          // Subtle gap between nibbles (after bit 12 and bit 4).
          if (b == 12 || b == 4) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _BitCheckbox extends StatelessWidget {
  final int bit;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BitCheckbox({
    required this.bit,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$bit',
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.brand,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
