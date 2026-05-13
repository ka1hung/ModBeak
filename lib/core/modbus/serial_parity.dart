/// Parity setting for a serial line. Used by both [RtuMbClient] (the
/// runtime transport) and [DeviceConfig] (the serialised user choice).
///
/// Values map onto libserialport's `SerialPortParity` constants inside
/// the RTU client.
enum SerialParity { none, even, odd }
