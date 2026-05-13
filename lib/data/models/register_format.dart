/// All formats a Watch Pane can use to interpret raw register / coil data.
///
/// Width semantics:
///   * 1 register / row : u16, i16, hex, bin
///   * 2 registers / row: u32be, u32le, i32be, i32le, f32be, f32le
///   * N registers / row: ascii (configurable chars per row)
///   * 1 bit / row      : bool_  (used for FC 01 / 02 / 05 / 15)
enum RegisterFormat {
  u16,
  i16,
  hex,
  bin,
  u32be,
  u32le,
  i32be,
  i32le,
  f32be,
  f32le,
  ascii,
  bool_,
}

extension RegisterFormatX on RegisterFormat {
  /// Number of 16-bit registers consumed per displayed row.
  /// Returns -1 for ASCII (caller-controlled) and 0 for Bool.
  int get registersPerRow {
    switch (this) {
      case RegisterFormat.u16:
      case RegisterFormat.i16:
      case RegisterFormat.hex:
      case RegisterFormat.bin:
        return 1;
      case RegisterFormat.u32be:
      case RegisterFormat.u32le:
      case RegisterFormat.i32be:
      case RegisterFormat.i32le:
      case RegisterFormat.f32be:
      case RegisterFormat.f32le:
        return 2;
      case RegisterFormat.ascii:
        return -1;
      case RegisterFormat.bool_:
        return 0;
    }
  }

  /// Human-readable label used in UI dropdowns.
  String get label {
    switch (this) {
      case RegisterFormat.u16:
        return 'UInt16';
      case RegisterFormat.i16:
        return 'Int16';
      case RegisterFormat.hex:
        return 'Hex';
      case RegisterFormat.bin:
        return 'Binary';
      case RegisterFormat.u32be:
        return 'UInt32 BE';
      case RegisterFormat.u32le:
        return 'UInt32 LE';
      case RegisterFormat.i32be:
        return 'Int32 BE';
      case RegisterFormat.i32le:
        return 'Int32 LE';
      case RegisterFormat.f32be:
        return 'Float32 BE';
      case RegisterFormat.f32le:
        return 'Float32 LE';
      case RegisterFormat.ascii:
        return 'ASCII';
      case RegisterFormat.bool_:
        return 'Bool';
    }
  }

  bool get isBoolFormat => this == RegisterFormat.bool_;
}

/// Coerce [format] so it matches the [functionCode]:
///   * Bit FCs (01/02/05/15) must use [RegisterFormat.bool_].
///   * Register FCs (03/04/06/16) must NOT use [RegisterFormat.bool_].
RegisterFormat sanitizeFormat(RegisterFormat format, int functionCode) {
  final isBit = functionCode == 1 || functionCode == 2;
  if (isBit && format != RegisterFormat.bool_) return RegisterFormat.bool_;
  if (!isBit && format == RegisterFormat.bool_) return RegisterFormat.u16;
  return format;
}
