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
import '../widgets/brand.dart';
import '../widgets/conn_indicator.dart';

enum PaneView { table, comm, errors }

/// Watch Pane — one MDI sub-window bound to a single [WatchSpec].
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
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;

  /// Drag delta emitted by the pane header's title area — the MDI workspace
  /// uses this to move the window. Null disables dragging (e.g. when the
  /// window is maximised).
  final ValueChanged<Offset>? onDragDelta;

  /// Whether the pane is currently the focused MDI window. Controls the
  /// border highlight in the design (cyan when active, faint otherwise).
  final bool active;

  /// Whether the underlying MDI window is currently maximised. Flips the
  /// maximise icon to a "restore" glyph.
  final bool isMaximized;

  const WatchPane({
    super.key,
    required this.spec,
    this.onClose,
    this.onSplit,
    this.onMinimize,
    this.onToggleMaximize,
    this.onDragDelta,
    this.active = false,
    this.isMaximized = false,
  });

  @override
  ConsumerState<WatchPane> createState() => _WatchPaneState();
}

class _WatchPaneState extends ConsumerState<WatchPane> {
  PaneView _view = PaneView.table;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(liveWatchProvider.notifier)
          .ensureDevicePolling(widget.spec.deviceId);
    });
  }

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
        color: AppColors.bg2,
        border: Border.all(
          color: widget.active ? AppColors.accent : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(2),
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
            onMinimize: widget.onMinimize,
            onToggleMaximize: widget.onToggleMaximize,
            onDragDelta: widget.onDragDelta,
            isMaximized: widget.isMaximized,
          ),
          if (_view == PaneView.table)
            _ParamsBar(
              spec: widget.spec,
              running: connState == DeviceConnState.connected,
            ),
          Expanded(
            child: switch (_view) {
              PaneView.table => connState != DeviceConnState.connected
                  ? _NotConnectedHint(connState: connState)
                  : _TableView(
                      spec: widget.spec,
                      format: sanitizeFormat(
                          widget.spec.format, widget.spec.functionCode),
                      asciiChars: widget.spec.asciiCharsPerRow,
                      result: result,
                    ),
              PaneView.comm => _CommView(spec: widget.spec),
              PaneView.errors => _ErrorView(deviceId: widget.spec.deviceId),
            },
          ),
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
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleMaximize;
  final ValueChanged<Offset>? onDragDelta;
  final bool isMaximized;

  const _PaneHeader({
    required this.spec,
    required this.device,
    required this.connState,
    required this.view,
    required this.onViewChanged,
    this.onEdit,
    this.onClose,
    this.onSplit,
    this.onMinimize,
    this.onToggleMaximize,
    this.onDragDelta,
    this.isMaximized = false,
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
    final dragDelta = onDragDelta;
    final titleArea = Row(
      children: [
        StatusDot(status: ConnIndicator.dotFor(connState), size: 7),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${device.name} · $_fcLabel · '
            '${spec.startAddress}–${spec.startAddress + spec.quantity - 1} · ${device.pollIntervalMs}ms',
            style: AppType.mono.copyWith(color: AppColors.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Row(
        children: [
          // Title region — drag handle for the MDI window when callback provided.
          Expanded(
            child: MouseRegion(
              cursor: dragDelta == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.move,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate:
                    dragDelta == null ? null : (d) => dragDelta(d.delta),
                onDoubleTap: onToggleMaximize,
                child: titleArea,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _ViewToggle(
              deviceId: spec.deviceId,
              value: view,
              onChanged: onViewChanged),
          if (onEdit != null)
            _PaneIcon(icon: Icons.edit, tooltip: 'Edit watch', onTap: onEdit!),
          if (onSplit != null)
            _PaneIcon(
                icon: Icons.splitscreen,
                tooltip: 'Split',
                onTap: onSplit!),
          if (onMinimize != null)
            _PaneIcon(
                icon: Icons.minimize,
                tooltip: 'Minimise',
                onTap: onMinimize!),
          if (onToggleMaximize != null)
            _PaneIcon(
                icon: isMaximized
                    ? Icons.filter_none_outlined
                    : Icons.crop_square,
                tooltip: isMaximized ? 'Restore' : 'Maximise',
                onTap: onToggleMaximize!),
          if (onClose != null)
            _PaneIcon(
                icon: Icons.close,
                tooltip: 'Close pane',
                hoverColor: AppColors.error,
                onTap: onClose!),
        ],
      ),
    );
  }
}

class _PaneIcon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? hoverColor;
  const _PaneIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hoverColor,
  });

  @override
  State<_PaneIcon> createState() => _PaneIconState();
}

class _PaneIconState extends State<_PaneIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hi = widget.hoverColor ?? AppColors.text;
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
            width: 20,
            height: 20,
            alignment: Alignment.center,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tab('TABLE', PaneView.table),
        const SizedBox(width: 2),
        _tab('COMM', PaneView.comm),
        const SizedBox(width: 2),
        _tab('ERRORS', PaneView.errors, badge: errorCount),
      ],
    );
  }

  Widget _tab(String label, PaneView v, {int badge = 0}) {
    final active = v == value;
    return InkWell(
      onTap: () => onChanged(v),
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.bg1 : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.border : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.labelSm.copyWith(
                color: active ? AppColors.text : AppColors.textMuted,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: AppType.labelSm.copyWith(
                    fontSize: 9,
                    color: AppColors.onError,
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

// ─── Params bar — inline-editable watch parameters ─────────────────────────

/// Replaces the old read-only Format bar. ADDR / QTY / ID commit on Enter or
/// focus loss; FC and FORMAT apply immediately. Every change is written back
/// to the [WatchSpec] via [watchListProvider], so it persists with the config
/// and the device poll loop picks it up on its next cycle — no restart needed.
/// The left side scrolls horizontally so narrow split panes stay usable.
class _ParamsBar extends ConsumerStatefulWidget {
  final WatchSpec spec;
  final bool running;
  const _ParamsBar({required this.spec, required this.running});

  @override
  ConsumerState<_ParamsBar> createState() => _ParamsBarState();
}

class _ParamsBarState extends ConsumerState<_ParamsBar> {
  static const _formatOptions = [
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

  static const _fcLabels = {
    1: 'FC01 Coils',
    2: 'FC02 DI',
    3: 'FC03 HR',
    4: 'FC04 IR',
  };

  late final TextEditingController _addrCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _asciiCtrl;
  late final FocusNode _addrFocus;
  late final FocusNode _qtyFocus;
  late final FocusNode _unitFocus;
  late final FocusNode _asciiFocus;

  WatchSpec get _spec => widget.spec;
  bool get _isBitMode => _spec.functionCode == 1 || _spec.functionCode == 2;

  @override
  void initState() {
    super.initState();
    _addrCtrl = TextEditingController(text: '${_spec.startAddress}');
    _qtyCtrl = TextEditingController(text: '${_spec.quantity}');
    _unitCtrl = TextEditingController(text: '${_spec.unitId}');
    _asciiCtrl = TextEditingController(text: '${_spec.asciiCharsPerRow}');
    _addrFocus = _commitOnBlur(_commitAddr);
    _qtyFocus = _commitOnBlur(_commitQty);
    _unitFocus = _commitOnBlur(_commitUnit);
    _asciiFocus = _commitOnBlur(_commitAscii);
  }

  /// Focus node that fires [commit] when the field loses focus — typing never
  /// touches the poll loop; only Enter or blur does.
  FocusNode _commitOnBlur(VoidCallback commit) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) commit();
    });
    return node;
  }

  @override
  void didUpdateWidget(covariant _ParamsBar old) {
    super.didUpdateWidget(old);
    if (old.spec == widget.spec) return;
    // Spec changed externally (edit dialog, another pane) — refresh any
    // field the user is not currently typing in.
    _syncIfUnfocused(_addrFocus, _addrCtrl, '${_spec.startAddress}');
    _syncIfUnfocused(_qtyFocus, _qtyCtrl, '${_spec.quantity}');
    _syncIfUnfocused(_unitFocus, _unitCtrl, '${_spec.unitId}');
    _syncIfUnfocused(_asciiFocus, _asciiCtrl, '${_spec.asciiCharsPerRow}');
  }

  void _syncIfUnfocused(
      FocusNode focus, TextEditingController ctrl, String value) {
    if (!focus.hasFocus && ctrl.text != value) ctrl.text = value;
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _asciiCtrl.dispose();
    _addrFocus.dispose();
    _qtyFocus.dispose();
    _unitFocus.dispose();
    _asciiFocus.dispose();
    super.dispose();
  }

  void _update(WatchSpec next) {
    if (next == _spec) return;
    ref.read(watchListProvider.notifier).update(next);
  }

  void _commitAddr() {
    var v = int.tryParse(_addrCtrl.text) ?? _spec.startAddress;
    if (v < 1) v = 1; // 1-based; UI never sends 0 (same rule as the dialog)
    _addrCtrl.text = '$v';
    _update(_spec.copyWith(startAddress: v));
  }

  void _commitQty() {
    var v = int.tryParse(_qtyCtrl.text) ?? _spec.quantity;
    if (v < 1) v = 1;
    _qtyCtrl.text = '$v';
    _update(_spec.copyWith(quantity: v));
  }

  void _commitUnit() {
    var v = int.tryParse(_unitCtrl.text) ?? _spec.unitId;
    v = v.clamp(0, 255);
    _unitCtrl.text = '$v';
    _update(_spec.copyWith(unitId: v));
  }

  void _commitAscii() {
    var v = int.tryParse(_asciiCtrl.text) ?? _spec.asciiCharsPerRow;
    if (v < 1) v = 1;
    _asciiCtrl.text = '$v';
    _update(_spec.copyWith(asciiCharsPerRow: v));
  }

  void _setFc(int fc) {
    _update(_spec.copyWith(
      functionCode: fc,
      format: sanitizeFormat(_spec.format, fc),
    ));
  }

  void _setFormat(RegisterFormat f) {
    _update(_spec.copyWith(format: f));
  }

  @override
  Widget build(BuildContext context) {
    final format = sanitizeFormat(_spec.format, _spec.functionCode);
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _label('ADDR'),
                  _numField(_addrCtrl, _addrFocus, _commitAddr, width: 64),
                  const SizedBox(width: 10),
                  _label('QTY'),
                  _numField(_qtyCtrl, _qtyFocus, _commitQty, width: 56),
                  const SizedBox(width: 10),
                  _label('ID'),
                  _numField(_unitCtrl, _unitFocus, _commitUnit, width: 44),
                  const SizedBox(width: 10),
                  _label('FC'),
                  _dropdown<int>(
                    value: _spec.functionCode,
                    items: [
                      for (final e in _fcLabels.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style:
                                AppType.mono.copyWith(color: AppColors.text),
                          ),
                        ),
                      if (!_fcLabels.containsKey(_spec.functionCode))
                        DropdownMenuItem(
                          value: _spec.functionCode,
                          child: Text(
                            'FC${_spec.functionCode}',
                            style:
                                AppType.mono.copyWith(color: AppColors.text),
                          ),
                        ),
                    ],
                    onChanged: _setFc,
                  ),
                  const SizedBox(width: 10),
                  _label('FORMAT'),
                  if (_isBitMode)
                    Text('Bool',
                        style: AppType.mono.copyWith(color: AppColors.text))
                  else
                    _dropdown<RegisterFormat>(
                      value: format,
                      items: [
                        for (final f in _formatOptions)
                          DropdownMenuItem(
                            value: f,
                            child: Text(
                              f.label,
                              style: AppType.mono
                                  .copyWith(color: AppColors.text),
                            ),
                          ),
                      ],
                      onChanged: _setFormat,
                    ),
                  if (format == RegisterFormat.ascii && !_isBitMode) ...[
                    const SizedBox(width: 10),
                    _label('CHARS/ROW'),
                    _numField(_asciiCtrl, _asciiFocus, _commitAscii,
                        width: 56),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (widget.running)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.fiber_manual_record,
                  size: 8, color: AppColors.online),
              const SizedBox(width: 5),
              Text('LIVE',
                  style:
                      AppType.labelSm.copyWith(color: AppColors.online)),
            ])
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.pause, size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('PAUSED',
                  style: AppType.labelSm
                      .copyWith(color: AppColors.textMuted)),
            ]),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(text,
            style: AppType.labelSm.copyWith(color: AppColors.textDim)),
      );

  Widget _numField(
    TextEditingController ctrl,
    FocusNode focus,
    VoidCallback commit, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      height: 26,
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        style: AppType.mono.copyWith(color: AppColors.text),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          filled: true,
          fillColor: AppColors.bg1,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
        onSubmitted: (_) => commit(),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          iconSize: 14,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
          dropdownColor: AppColors.bg2,
          style: AppType.mono.copyWith(color: AppColors.text),
          items: items,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
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
    // Subscribe so that a "Reset counters" action causes an instant rebuild.
    ref.watch(statsTickProvider);
    final loop = ref.read(deviceHubProvider).devicePoll(spec.deviceId);
    if (loop == null) {
      return Container(
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.bg3,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
      );
    }
    final s = loop.statsFor(spec.id);
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _Stat(label: 'OK', value: '${s.success}', color: AppColors.online),
          const SizedBox(width: 12),
          _Stat(
            label: 'ERR',
            value: '${s.errors}',
            color:
                s.errors > 0 ? AppColors.error : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          _Stat(
            label: 'AVG',
            value: '${s.avgLatency.inMilliseconds}ms',
            color: AppColors.textMuted,
          ),
          const Spacer(),
          if (result is PollErr)
            Flexible(
              child: Text(
                (result as PollErr).error.toString(),
                style: AppType.monoSm.copyWith(color: AppColors.error),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label,
            style: AppType.labelSm.copyWith(
              fontSize: 9,
              color: AppColors.textDim,
            )),
        const SizedBox(width: 5),
        Text(value,
            style: AppType.monoSm.copyWith(color: color)),
      ],
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
      return Center(
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
                   TextStyle(color: AppColors.connError, fontSize: 12)),
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
    final bg = value ? AppColors.online : AppColors.bg1;
    final fg = value ? AppColors.onOnline : AppColors.textMuted;
    final border = value ? AppColors.onlineDim : AppColors.border;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: pending ? 0.45 : 1.0,
          child: Container(
            width: 56,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              value ? 'TRUE' : 'FALSE',
              style: AppType.monoSm.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.8,
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
                  Text(
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

// ─── Comm view (per-watch packet log) ──────────────────────────────────────
//
// Filters the global packet log down to just the frames that belong to THIS
// watch. Without this filter every watch on the same device shows the same
// torrent of TX/RX, which makes it impossible to see what your watch is
// actually doing.
//
// Match rules:
//   * TX is kept when its PDU's (FC, startAddr, qty) matches the watch's
//     own (FC, startAddr-1, qty) signature. Single-register writes (FC05/06)
//     against the watch's range are also kept, as are multi-writes
//     (FC15/16) that overlap the range.
//   * RX is kept by pairing it back to a kept TX:
//       - TCP: by MBAP transactionId.
//       - RTU: half-duplex, so the RX is paired with the most recent TX on
//         the same device.

class _CommView extends ConsumerWidget {
  final WatchSpec spec;
  const _CommView({required this.spec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(rawLogProvider);
    final mine = _filterForWatch(all, spec);
    if (mine.isEmpty) {
      return Center(
        child: Text('No packets yet for this watch.',
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
          decoration: BoxDecoration(
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
                    style:  TextStyle(
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
                  style:  TextStyle(
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

/// Filters the global packet log down to frames that belong to [spec].
///
/// Two passes baked into one — TX matching by request signature, RX matching
/// by pairing back to a kept TX. The kept set is built incrementally so we
/// can correlate RTU responses (which have no transaction id) with the
/// preceding TX on the wire.
List<TaggedRawPacket> _filterForWatch(
    List<TaggedRawPacket> all, WatchSpec spec) {
  final out = <TaggedRawPacket>[];
  // TCP correlation: transactionIds whose TX we kept and whose RX is pending.
  final pendingTcp = <int>{};
  // RTU correlation: did the most recent TX on this device match?
  bool lastTxMatched = false;
  for (final p in all) {
    if (p.deviceId != spec.deviceId) continue;
    if (p.isTx) {
      final pdu = _parseRequestPdu(p);
      final keep = pdu != null && _txMatchesWatch(pdu, spec);
      if (keep) {
        out.add(p);
        final txId = p.transactionId;
        if (txId != null) pendingTcp.add(txId);
      }
      // RTU has no txId — record match state for the next RX.
      lastTxMatched = keep;
    } else {
      final txId = p.mbap?.transactionId;
      if (txId != null) {
        if (pendingTcp.remove(txId)) out.add(p);
      } else if (lastTxMatched) {
        out.add(p);
        // Half-duplex RTU: one RX per TX. Reset so a stray duplicate doesn't
        // get counted twice.
        lastTxMatched = false;
      }
    }
  }
  return out;
}

/// Parsed TX request — function code plus the address+quantity tuple we use
/// for the [_txMatchesWatch] filter. Returns null for non-Modbus or malformed
/// frames.
class _RequestPdu {
  final int fc;
  final int? address;
  final int? quantity;
  const _RequestPdu({required this.fc, this.address, this.quantity});
}

_RequestPdu? _parseRequestPdu(RawPacket p) {
  // PDU starts at byte 7 for MBAP (after MBAP header), or byte 1 for RTU
  // (after the slave id). Reject frames that are too short either way.
  int pduStart;
  if (p.transport == ModbusTransport.tcp) {
    if (p.bytes.length < 8) return null;
    pduStart = 7;
  } else {
    if (p.bytes.length < 4) return null;
    pduStart = 1;
  }
  final b = p.bytes;
  final fc = b[pduStart] & 0x7F;
  // Read FCs (01/02/03/04) and multi-writes (15/16) all share the same
  // request layout: addr (BE u16) + qty (BE u16) at PDU bytes 1..4.
  // Single-coil/register writes (05/06) carry an address but no quantity.
  switch (fc) {
    case 1:
    case 2:
    case 3:
    case 4:
    case 15:
    case 16:
      if (b.length < pduStart + 5) return _RequestPdu(fc: fc);
      return _RequestPdu(
        fc: fc,
        address: (b[pduStart + 1] << 8) | b[pduStart + 2],
        quantity: (b[pduStart + 3] << 8) | b[pduStart + 4],
      );
    case 5:
    case 6:
      if (b.length < pduStart + 3) return _RequestPdu(fc: fc);
      return _RequestPdu(
        fc: fc,
        address: (b[pduStart + 1] << 8) | b[pduStart + 2],
        quantity: 1,
      );
    default:
      return _RequestPdu(fc: fc);
  }
}

bool _txMatchesWatch(_RequestPdu pdu, WatchSpec spec) {
  // Watch addresses are 1-based; on the wire they're 0-based.
  final wireStart = spec.startAddress - 1;
  final wireEnd = wireStart + spec.quantity; // exclusive

  // Same FC, exact (addr, qty) match — the normal poll case.
  if (pdu.fc == spec.functionCode &&
      pdu.address == wireStart &&
      pdu.quantity == spec.quantity) {
    return true;
  }

  // Writes triggered from the user's interactions on this watch:
  //   * FC01 coils  → FC05 (single) or FC15 (multi)
  //   * FC03 holding → FC06 (single) or FC16 (multi)
  //   * FC02/FC04 are read-only — no writes to match.
  final singleWriteFc = switch (spec.functionCode) {
    1 => 5,
    3 => 6,
    _ => null,
  };
  final multiWriteFc = switch (spec.functionCode) {
    1 => 15,
    3 => 16,
    _ => null,
  };
  if (pdu.address == null) return false;
  if (pdu.fc == singleWriteFc) {
    return pdu.address! >= wireStart && pdu.address! < wireEnd;
  }
  if (pdu.fc == multiWriteFc && pdu.quantity != null) {
    final aStart = pdu.address!;
    final aEnd = aStart + pdu.quantity!;
    return aStart < wireEnd && aEnd > wireStart;
  }
  return false;
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
               Icon(Icons.error_outline,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${mine.length} error${mine.length == 1 ? '' : 's'}',
                style:  TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
              const Spacer(),
              if (mine.isNotEmpty)
                InkWell(
                  onTap: () => ref
                      .read(errorLogProvider.notifier)
                      .clearDevice(deviceId),
                  child: Padding(
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
              ? Center(
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
                      decoration: BoxDecoration(
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
                                style:  TextStyle(
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
                                style:  TextStyle(
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
                              style:  TextStyle(
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
                  style:  TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              Text(widget.subtitle,
                  style:  TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 12),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                style:  TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    color: AppColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg,
                  errorText: _error,
                  errorStyle:  TextStyle(
                      fontSize: 11, color: AppColors.connError),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:  BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:  BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:  BorderSide(color: AppColors.brand),
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
                  style:  TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              Text('Holding register · 16 bits (MSB ← bit 15 … bit 0 → LSB)',
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
                      style:  TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_hexStr  ·  dec $_value',
                      style:  TextStyle(
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
              style:  TextStyle(
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
