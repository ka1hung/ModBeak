import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart' as sp;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/modbus/mb_client.dart';
import '../../../data/models/device_config.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';

const _baudOptions = [
  1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200, 230400,
];

/// One row in the serial port dropdown.
class _PortChoice {
  final String name;
  final String? description;
  final String? manufacturer;
  final bool offline;

  const _PortChoice({
    required this.name,
    this.description,
    this.manufacturer,
    this.offline = false,
  });

  String get label {
    final detail = description?.trim().isNotEmpty == true
        ? description!.trim()
        : (manufacturer?.trim().isNotEmpty == true ? manufacturer!.trim() : null);
    final base = detail == null ? name : '$name — $detail';
    return offline ? '$base (not connected)' : base;
  }
}

class AddDeviceDialog extends ConsumerStatefulWidget {
  final DeviceConfig? edit;
  const AddDeviceDialog({super.key, this.edit});

  @override
  ConsumerState<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends ConsumerState<AddDeviceDialog> {
  late ModbusTransport _transport;

  // Shared
  late final TextEditingController _name;
  late final TextEditingController _timeout;
  late final TextEditingController _gap;
  late final TextEditingController _pollInterval;
  late bool _serialize;
  late bool _autoReconnect;

  // TCP
  late final TextEditingController _host;
  late final TextEditingController _port;

  // RTU
  late String _serialPort;
  late int _baudRate;
  late int _dataBits;
  late int _stopBits;
  late SerialParity _parity;
  List<_PortChoice> _ports = const [];

  String? _testStatus;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _transport = e?.transport ?? ModbusTransport.tcp;

    _name = TextEditingController(text: e?.name ?? '');
    _timeout = TextEditingController(text: '${e?.timeoutMs ?? 2000}');
    _gap = TextEditingController(text: '${e?.minRequestGapMs ?? 100}');
    _pollInterval =
        TextEditingController(text: '${e?.pollIntervalMs ?? 1000}');
    _serialize = e?.serializeRequests ?? true;
    _autoReconnect = e?.autoReconnect ?? true;

    _host = TextEditingController(text: e?.host ?? '192.168.1.10');
    _port = TextEditingController(text: '${e?.port ?? 502}');

    _serialPort = e?.serialPort ?? '';
    _baudRate = e?.baudRate ?? 9600;
    _dataBits = e?.dataBits ?? 8;
    _stopBits = e?.stopBits ?? 1;
    _parity = e?.parity ?? SerialParity.none;

    _refreshPorts();
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _timeout.dispose();
    _gap.dispose();
    _pollInterval.dispose();
    super.dispose();
  }

  /// Enumerate serial ports and capture descriptions.
  ///
  /// If the currently-selected port is gone (other machine, unplugged
  /// adapter), keep it in the list flagged offline so the user can see the
  /// problem without losing the saved value.
  void _refreshPorts() {
    final List<_PortChoice> found = [];
    for (final name in sp.SerialPort.availablePorts) {
      final port = sp.SerialPort(name);
      try {
        found.add(_PortChoice(
          name: name,
          description: _safeStr(() => port.description),
          manufacturer: _safeStr(() => port.manufacturer),
        ));
      } finally {
        port.dispose();
      }
    }
    _sortPorts(found);

    final selected = _serialPort;
    if (selected.isNotEmpty &&
        !found.any((c) => c.name == selected)) {
      found.insert(0, _PortChoice(name: selected, offline: true));
    }
    setState(() => _ports = found);
  }

  static String? _safeStr(String? Function() get) {
    try {
      return get();
    } catch (_) {
      return null;
    }
  }

  static void _sortPorts(List<_PortChoice> ports) {
    ports.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _testConnection() async {
    setState(() {
      _testStatus = 'connecting…';
      _testOk = false;
    });
    final t0 = DateTime.now();
    final timeout = Duration(milliseconds: int.tryParse(_timeout.text) ?? 2000);
    final c = switch (_transport) {
      ModbusTransport.tcp => MbClient.tcp(
          host: _host.text.trim(),
          port: int.tryParse(_port.text) ?? 502,
          timeout: timeout,
        ),
      ModbusTransport.rtu => MbClient.rtu(
          serialPortName: _serialPort,
          baudRate: _baudRate,
          dataBits: _dataBits,
          stopBits: _stopBits,
          parity: _parity,
          timeout: timeout,
        ),
    };
    try {
      await c.open();
      final ms = DateTime.now().difference(t0).inMilliseconds;
      await c.close();
      if (!mounted) return;
      setState(() {
        _testStatus = 'OK · ${ms}ms';
        _testOk = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testStatus = 'FAIL · $e';
        _testOk = false;
      });
    }
  }

  Future<void> _save() async {
    final defaultName = _transport == ModbusTransport.tcp
        ? _host.text
        : (_serialPort.isEmpty ? 'RTU device' : _serialPort);
    final cfg = DeviceConfig(
      id: widget.edit?.id ?? const Uuid().v4(),
      name: _name.text.trim().isEmpty ? defaultName : _name.text.trim(),
      transport: _transport,
      host: _host.text.trim(),
      port: int.tryParse(_port.text) ?? 502,
      serialPort: _serialPort,
      baudRate: _baudRate,
      dataBits: _dataBits,
      stopBits: _stopBits,
      parity: _parity,
      timeoutMs: int.tryParse(_timeout.text) ?? 2000,
      minRequestGapMs:
          (int.tryParse(_gap.text) ?? 100).clamp(0, 60000),
      pollIntervalMs:
          (int.tryParse(_pollInterval.text) ?? 1000).clamp(0, 600000),
      // RTU is half-duplex; keep the user's TCP setting in JSON for round-trip
      // but the runtime client ignores it for RTU.
      serializeRequests:
          _transport == ModbusTransport.rtu ? true : _serialize,
      autoReconnect: _autoReconnect,
    );

    final notifier = ref.read(deviceListProvider.notifier);
    if (widget.edit != null) {
      await notifier.update(cfg);
    } else {
      notifier.add(cfg);
    }
    if (!mounted) return;
    Navigator.of(context).pop(cfg);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.edit == null ? 'New Device' : 'Edit Device',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              _TransportToggle(
                value: _transport,
                onChanged: (t) => setState(() {
                  _transport = t;
                  _testStatus = null;
                }),
              ),
              const SizedBox(height: 12),
              _Field(label: 'Name', controller: _name),
              const SizedBox(height: 8),
              if (_transport == ModbusTransport.tcp) ..._tcpFields(),
              if (_transport == ModbusTransport.rtu) ..._rtuFields(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Poll interval (ms)',
                      controller: _pollInterval,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        _Field(label: 'Min request gap (ms)', controller: _gap),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Poll interval = whole-device cycle. Each cycle queries '
                  'every watch in sequence, separated by Min request gap.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              if (_transport == ModbusTransport.tcp)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _serialize,
                  onChanged: (v) => setState(() => _serialize = v ?? false),
                  title: const Text('Serialize requests',
                      style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                      'One in-flight request at a time. On by default — most '
                      'slaves expect this.',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
              if (_transport == ModbusTransport.rtu)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'RTU is half-duplex — requests are always serialized.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _autoReconnect,
                onChanged: (v) => setState(() => _autoReconnect = v ?? true),
                title: const Text('Auto-reconnect',
                    style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _testConnection,
                    child: const Text('Test'),
                  ),
                  const SizedBox(width: 12),
                  if (_testStatus != null)
                    Expanded(
                      child: Text(
                        _testStatus!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _testOk ? AppColors.brand : AppColors.danger,
                        ),
                      ),
                    ),
                ],
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
                    onPressed: _save,
                    child: Text(widget.edit == null ? 'Save' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tcpFields() => [
        _Field(label: 'Host / IP', controller: _host),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Field(label: 'Port', controller: _port)),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _Field(label: 'Timeout (ms)', controller: _timeout)),
          ],
        ),
      ];

  List<Widget> _rtuFields() => [
        _PortDropdown(
          choices: _ports,
          value: _serialPort,
          onChanged: (v) => setState(() => _serialPort = v ?? ''),
          onRefresh: _refreshPorts,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DropdownField<int>(
                label: 'Baud',
                value: _baudOptions.contains(_baudRate)
                    ? _baudRate
                    : _baudOptions.first,
                items: _baudOptions
                    .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                    .toList(),
                onChanged: (v) => setState(() => _baudRate = v ?? 9600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _Field(label: 'Timeout (ms)', controller: _timeout)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DropdownField<int>(
                label: 'Data bits',
                value: _dataBits,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7')),
                  DropdownMenuItem(value: 8, child: Text('8')),
                ],
                onChanged: (v) => setState(() => _dataBits = v ?? 8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DropdownField<int>(
                label: 'Stop bits',
                value: _stopBits,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1')),
                  DropdownMenuItem(value: 2, child: Text('2')),
                ],
                onChanged: (v) => setState(() => _stopBits = v ?? 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DropdownField<SerialParity>(
                label: 'Parity',
                value: _parity,
                items: const [
                  DropdownMenuItem(
                      value: SerialParity.none, child: Text('None')),
                  DropdownMenuItem(
                      value: SerialParity.even, child: Text('Even')),
                  DropdownMenuItem(
                      value: SerialParity.odd, child: Text('Odd')),
                ],
                onChanged: (v) =>
                    setState(() => _parity = v ?? SerialParity.none),
              ),
            ),
          ],
        ),
      ];
}

class _TransportToggle extends StatelessWidget {
  final ModbusTransport value;
  final ValueChanged<ModbusTransport> onChanged;
  const _TransportToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ModbusTransport>(
      segments: const [
        ButtonSegment(value: ModbusTransport.tcp, label: Text('TCP')),
        ButtonSegment(value: ModbusTransport.rtu, label: Text('RTU')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _PortDropdown extends StatelessWidget {
  final List<_PortChoice> choices;
  final String value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;

  const _PortDropdown({
    required this.choices,
    required this.value,
    required this.onChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasMatch = choices.any((c) => c.name == value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Serial port',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: DropdownButtonFormField<String>(
                  value: hasMatch ? value : null,
                  isDense: true,
                  isExpanded: true,
                  hint: Text(
                    choices.isEmpty ? 'No ports detected' : 'Select port',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  items: choices
                      .map((c) => DropdownMenuItem(
                            value: c.name,
                            child: Text(
                              c.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.offline
                                    ? AppColors.textMuted
                                    : null,
                                fontStyle:
                                    c.offline ? FontStyle.italic : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Refresh ports',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onRefresh,
              constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: DropdownButtonFormField<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: items,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: AppColors.border),
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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _Field({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}
