/// Modbus client exceptions, mirroring `mbclient` (Go) sentinel errors.
sealed class MbException implements Exception {
  final String message;
  const MbException(this.message);

  @override
  String toString() => 'MbException: $message';
}

/// TCP socket disconnected, write failed, or never opened.
class MbDisconnect extends MbException {
  const MbDisconnect([super.message = 'Disconnect']);
}

/// Slave did not respond within timeout.
class MbNoResponse extends MbException {
  const MbNoResponse([super.message = 'NoResponse']);
}

/// Slave returned a Modbus exception response (FC byte high bit set).
class MbModbusError extends MbException {
  final int? code;
  const MbModbusError(super.message, {this.code});

  factory MbModbusError.fromCode(int code) =>
      MbModbusError(_exceptionText(code), code: code);
}

String _exceptionText(int code) => switch (code) {
      1 => '(01 illegal function)',
      2 => '(02 illegal data address)',
      3 => '(03 illegal data value)',
      4 => '(04 slave device failure)',
      5 => '(05 acknowledge)',
      6 => '(06 slave device busy)',
      7 => '(07 negative acknowledge)',
      8 => '(08 memory parity error)',
      10 => '(0A gateway path unavailable)',
      11 => '(0B gateway target device failed to respond)',
      _ =>
        '(${code.toRadixString(16).padLeft(2, '0').toUpperCase()} error code not in list)',
    };
