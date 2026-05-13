import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/device_config.dart';
import '../../../data/models/register_format.dart';
import '../../../data/models/watch_spec.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Dialog used both from the main console and from inside a Watch Window
/// (when adding a new pane).
class AddWatchDialog extends ConsumerStatefulWidget {
  /// If non-null, dialog opens with this device pre-selected.
  final String? initialDeviceId;
  final WatchSpec? edit;
  const AddWatchDialog({super.key, this.initialDeviceId, this.edit});

  @override
  ConsumerState<AddWatchDialog> createState() => _AddWatchDialogState();
}

class _AddWatchDialogState extends ConsumerState<AddWatchDialog> {
  late String _deviceId;
  late int _functionCode;
  late int _unitId;
  late int _startAddr;
  late int _qty;
  late RegisterFormat _format;
  late int _asciiChars;

  late final TextEditingController _unitCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _asciiCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    final devices = ref.read(deviceListProvider);
    _deviceId = e?.deviceId ?? widget.initialDeviceId ?? devices.firstOrNull?.id ?? '';
    _functionCode = e?.functionCode ?? 3;
    _unitId = e?.unitId ?? 1;
    _startAddr = e?.startAddress ?? 1;
    _qty = e?.quantity ?? 10;
    final rawFormat = e?.format ?? RegisterFormat.u16;
    _format = sanitizeFormat(rawFormat, _functionCode);
    _asciiChars = e?.asciiCharsPerRow ?? 8;

    _unitCtrl = TextEditingController(text: '$_unitId');
    _addrCtrl = TextEditingController(text: '$_startAddr');
    _qtyCtrl = TextEditingController(text: '$_qty');
    _asciiCtrl = TextEditingController(text: '$_asciiChars');
  }

  @override
  void dispose() {
    _unitCtrl.dispose();
    _addrCtrl.dispose();
    _qtyCtrl.dispose();
    _asciiCtrl.dispose();
    super.dispose();
  }

  bool get _isBitFc => _functionCode == 1 || _functionCode == 2;

  void _onFcChanged(int v) {
    setState(() {
      _functionCode = v;
      _format = sanitizeFormat(_format, v);
    });
  }

  void _save() {
    _unitId = int.tryParse(_unitCtrl.text) ?? _unitId;
    _startAddr = int.tryParse(_addrCtrl.text) ?? _startAddr;
    if (_startAddr < 1) _startAddr = 1; // 1-based; UI never sends 0
    _qty = int.tryParse(_qtyCtrl.text) ?? _qty;
    _asciiChars = int.tryParse(_asciiCtrl.text) ?? _asciiChars;

    final spec = WatchSpec(
      id: widget.edit?.id ?? const Uuid().v4(),
      deviceId: _deviceId,
      unitId: _unitId,
      functionCode: _functionCode,
      startAddress: _startAddr,
      quantity: _qty,
      format: _isBitFc ? RegisterFormat.bool_ : _format,
      asciiCharsPerRow: _asciiChars,
    );

    final notifier = ref.read(watchListProvider.notifier);
    if (widget.edit != null) {
      notifier.update(spec);
    } else {
      notifier.add(spec);
    }
    Navigator.of(context).pop(spec);
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.edit == null ? 'New Watch / Pane' : 'Edit Watch',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _Label('Device'),
                _DeviceDropdown(
                  devices: devices,
                  selected: _deviceId,
                  onChanged: (id) => setState(() => _deviceId = id ?? ''),
                ),
                const SizedBox(height: 12),
                _Label('Function Code'),
                Wrap(
                  spacing: 12,
                  children: [
                    _FcRadio(value: 3, group: _functionCode, label: 'FC 03 — Holding Reg', onChanged: _onFcChanged),
                    _FcRadio(value: 4, group: _functionCode, label: 'FC 04 — Input Reg', onChanged: _onFcChanged),
                    _FcRadio(value: 1, group: _functionCode, label: 'FC 01 — Coils', onChanged: _onFcChanged),
                    _FcRadio(value: 2, group: _functionCode, label: 'FC 02 — Discrete In', onChanged: _onFcChanged),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _LabeledField(label: 'Unit ID', controller: _unitCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _LabeledField(label: 'Start Addr (1-based)', controller: _addrCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _LabeledField(label: 'Qty', controller: _qtyCtrl)),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Poll interval is now configured per device (cycle '
                    'queries every watch in sequence).',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                if (!_isBitFc) ...[
                  _Label('Initial Format'),
                  _FormatPicker(
                    value: _format,
                    onChanged: (f) => setState(() => _format = f),
                  ),
                  if (_format == RegisterFormat.ascii) ...[
                    const SizedBox(height: 8),
                    _LabeledField(label: 'ASCII chars per row', controller: _asciiCtrl),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'FC 01/02 → bit (Bool) format auto-locked.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _deviceId.isEmpty ? null : _save,
                      child: Text(widget.edit == null ? 'Save' : 'Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style:  TextStyle(fontSize: 11, color: AppColors.textMuted)),
      );
}

class _DeviceDropdown extends StatelessWidget {
  final List<DeviceConfig> devices;
  final String selected;
  final ValueChanged<String?> onChanged;
  const _DeviceDropdown(
      {required this.devices, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: devices.any((d) => d.id == selected) ? selected : null,
          dropdownColor: AppColors.panel,
          hint: Text('Add a device first',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          items: [
            for (final d in devices)
              DropdownMenuItem(
                value: d.id,
                child: Text('${d.name}  ${d.addressLine}',
                    style: const TextStyle(fontSize: 13)),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FcRadio extends StatelessWidget {
  final int value;
  final int group;
  final String label;
  final ValueChanged<int> onChanged;
  const _FcRadio(
      {required this.value,
      required this.group,
      required this.label,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              group == value ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: group == value ? AppColors.brand : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _LabeledField({required this.label, required this.controller});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        SizedBox(
          height: 32,
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bg,
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

class _FormatPicker extends StatelessWidget {
  final RegisterFormat value;
  final ValueChanged<RegisterFormat> onChanged;
  const _FormatPicker({required this.value, required this.onChanged});

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
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RegisterFormat>(
          isExpanded: true,
          value: value,
          dropdownColor: AppColors.panel,
          items: [
            for (final f in _options)
              DropdownMenuItem(
                  value: f,
                  child: Text(f.label,
                      style: const TextStyle(fontSize: 13))),
          ],
          onChanged: (f) {
            if (f != null) onChanged(f);
          },
        ),
      ),
    );
  }
}
