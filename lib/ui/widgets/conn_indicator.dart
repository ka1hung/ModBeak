import 'package:flutter/material.dart';

import '../../core/runtime/device_hub.dart';
import '../theme/app_theme.dart';

/// Dot + colour + optional label for a [DeviceConnState]. Designed so the
/// state is readable from across the room: distinct hues, a glow ring on
/// the live state, and a label for accessibility.
class ConnIndicator extends StatelessWidget {
  final DeviceConnState state;
  final bool showLabel;
  final double dotSize;
  const ConnIndicator({
    super.key,
    required this.state,
    this.showLabel = false,
    this.dotSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorFor(state);
    final label = labelFor(state);
    final dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: state == DeviceConnState.connected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: state == DeviceConnState.disconnected
            ? Border.all(color: AppColors.border)
            : null,
      ),
    );
    if (!showLabel) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static Color colorFor(DeviceConnState s) => switch (s) {
        DeviceConnState.disconnected => AppColors.connDisconnected,
        DeviceConnState.connecting => AppColors.connConnecting,
        DeviceConnState.connected => AppColors.connConnected,
        DeviceConnState.error => AppColors.connError,
      };

  static String labelFor(DeviceConnState s) => switch (s) {
        DeviceConnState.disconnected => 'OFFLINE',
        DeviceConnState.connecting => 'CONNECTING',
        DeviceConnState.connected => 'ONLINE',
        DeviceConnState.error => 'ERROR',
      };
}
