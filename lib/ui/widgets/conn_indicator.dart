import 'package:flutter/material.dart';

import '../../core/runtime/device_hub.dart';
import '../theme/app_theme.dart';
import 'brand.dart';

/// Shape-and-colour indicator for a [DeviceConnState]. Designed so the
/// state is readable from across the room: distinct hues, a different
/// SHAPE for the error state (square), and an optional uppercase label.
class ConnIndicator extends StatelessWidget {
  final DeviceConnState state;
  final bool showLabel;
  final double dotSize;
  const ConnIndicator({
    super.key,
    required this.state,
    this.showLabel = false,
    this.dotSize = 8,
  });

  static DotStatus dotFor(DeviceConnState s) => switch (s) {
        DeviceConnState.connected => DotStatus.online,
        DeviceConnState.connecting => DotStatus.connecting,
        DeviceConnState.error => DotStatus.error,
        DeviceConnState.disconnected => DotStatus.offline,
      };

  static Color colorFor(DeviceConnState s) => switch (s) {
        DeviceConnState.connected => AppColors.online,
        DeviceConnState.connecting => AppColors.connecting,
        DeviceConnState.error => AppColors.error,
        DeviceConnState.disconnected => AppColors.offline,
      };

  static String labelFor(DeviceConnState s) => switch (s) {
        DeviceConnState.connected => 'ONLINE',
        DeviceConnState.connecting => 'CONNECTING',
        DeviceConnState.error => 'ERROR',
        DeviceConnState.disconnected => 'OFFLINE',
      };

  @override
  Widget build(BuildContext context) {
    final dot = StatusDot(status: dotFor(state), size: dotSize);
    if (!showLabel) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          labelFor(state),
          style: AppType.labelSm.copyWith(color: colorFor(state)),
        ),
      ],
    );
  }
}
