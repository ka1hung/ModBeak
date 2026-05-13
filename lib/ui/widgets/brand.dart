import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cockatiel head — ModBeak's mascot, rendered as a [CustomPaint] so it
/// stays sharp at any size without shipping a font asset.
class CockatielHead extends StatelessWidget {
  final double size;

  /// `false` skips eye highlight + beak shadow for tiny sizes (≤24 px).
  final bool detailed;

  const CockatielHead({super.key, this.size = 26, this.detailed = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CockatielPainter(detailed: detailed)),
    );
  }
}

class _CockatielPainter extends CustomPainter {
  final bool detailed;
  const _CockatielPainter({required this.detailed});

  @override
  void paint(Canvas canvas, Size size) {
    // Source viewBox is 100×100 — scale uniformly.
    final s = size.width / 100;
    canvas.scale(s, s);

    final fill = Paint()..style = PaintingStyle.fill;

    // Crest — 3 swept-back feathers
    fill.color = const Color(0xFFFAD65B);
    canvas.drawPath(
      Path()
        ..moveTo(56, 24)
        ..lineTo(74, 6)
        ..lineTo(64, 32)
        ..close(),
      fill,
    );
    fill.color = const Color(0xFFF0C032);
    canvas.drawPath(
      Path()
        ..moveTo(64, 26)
        ..lineTo(90, 10)
        ..lineTo(72, 36)
        ..close(),
      fill,
    );
    fill.color = const Color(0xFFD9A519);
    canvas.drawPath(
      Path()
        ..moveTo(70, 34)
        ..lineTo(96, 28)
        ..lineTo(78, 44)
        ..close(),
      fill,
    );

    // Head fill (light yellow)
    fill.color = const Color(0xFFFCE088);
    canvas.drawPath(
      Path()
        ..moveTo(30, 50)
        ..cubicTo(30, 30, 44, 22, 56, 22)
        ..cubicTo(72, 22, 82, 34, 82, 52)
        ..cubicTo(82, 72, 70, 84, 54, 84)
        ..cubicTo(38, 84, 28, 74, 28, 62)
        ..lineTo(28, 56)
        ..close(),
      fill,
    );

    if (detailed) {
      fill.color = const Color(0xFFF5C860).withValues(alpha: 0.6);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(44, 64), width: 28, height: 22),
        fill,
      );
    }

    // Orange cheek
    fill.color = const Color(0xFFFF7C3D);
    canvas.drawCircle(const Offset(44, 63), 11, fill);

    // Eye
    fill.color = const Color(0xFF1A0F08);
    canvas.drawCircle(const Offset(42, 46), 4, fill);
    if (detailed) {
      fill.color = const Color(0xFFFFFFFF);
      canvas.drawCircle(const Offset(43.2, 44.8), 1.2, fill);
    }

    // Beak — dark hook
    fill.color = const Color(0xFF2A1810);
    canvas.drawPath(
      Path()
        ..moveTo(28, 50)
        ..quadraticBezierTo(14, 56, 14, 66)
        ..quadraticBezierTo(16, 71, 24, 70)
        ..quadraticBezierTo(30, 66, 32, 60)
        ..close(),
      fill,
    );
    if (detailed) {
      fill.color = const Color(0xFF0D0703);
      canvas.drawPath(
        Path()
          ..moveTo(22, 64)
          ..quadraticBezierTo(18, 65, 18, 67)
          ..quadraticBezierTo(20, 69, 24, 68)
          ..close(),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CockatielPainter old) =>
      old.detailed != detailed;
}

/// Wordmark: "Mod" (regular) + "Beak" (bold) next to the cockatiel.
class BrandMark extends StatelessWidget {
  final double iconSize;
  const BrandMark({super.key, this.iconSize = 26});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CockatielHead(size: iconSize),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: AppType.h2.copyWith(color: AppColors.text),
            children: const [
              TextSpan(text: 'Mod', style: TextStyle(fontWeight: FontWeight.w400)),
              TextSpan(text: 'Beak', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shape-encoded status dot — colour AND shape so the indicator stays
/// readable for colour-blind users.
///
/// - online → solid circle (lime)
/// - connecting → dashed ring (amber, animated)
/// - error → solid SQUARE (coral — different shape)
/// - offline → outlined ring (gray)
enum DotStatus { online, connecting, error, offline }

class StatusDot extends StatefulWidget {
  final DotStatus status;
  final double size;
  final bool animated;
  const StatusDot({
    super.key,
    required this.status,
    this.size = 8,
    this.animated = true,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated && widget.status == DotStatus.connecting) {
      _spin.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldSpin =
        widget.animated && widget.status == DotStatus.connecting;
    if (shouldSpin && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!shouldSpin && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    Widget child;
    switch (widget.status) {
      case DotStatus.online:
        child = CustomPaint(
          size: Size.square(size),
          painter: _SolidCirclePainter(AppColors.online),
        );
      case DotStatus.error:
        child = CustomPaint(
          size: Size.square(size),
          painter: _SolidSquarePainter(AppColors.error),
        );
      case DotStatus.offline:
        child = CustomPaint(
          size: Size.square(size),
          painter:
              _OutlineCirclePainter(AppColors.offline, strokeWidth: 1.25),
        );
      case DotStatus.connecting:
        child = AnimatedBuilder(
          animation: _spin,
          builder: (_, _) => Transform.rotate(
            angle: _spin.value * 6.2831853,
            child: CustomPaint(
              size: Size.square(size),
              painter: _DashedRingPainter(AppColors.connecting),
            ),
          ),
        );
    }
    return SizedBox(width: size, height: size, child: child);
  }
}

class _SolidCirclePainter extends CustomPainter {
  final Color color;
  const _SolidCirclePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 0.5, p);
  }

  @override
  bool shouldRepaint(covariant _SolidCirclePainter old) =>
      old.color != color;
}

class _SolidSquarePainter extends CustomPainter {
  final Color color;
  const _SolidSquarePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _SolidSquarePainter old) =>
      old.color != color;
}

class _OutlineCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _OutlineCirclePainter(this.color, {this.strokeWidth = 1.25});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 1, p);
  }

  @override
  bool shouldRepaint(covariant _OutlineCirclePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  const _DashedRingPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 1;
    final c = size.center(Offset.zero);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // 8 short dashes around the circle for a subtle dashed feel
    const dashCount = 8;
    for (var i = 0; i < dashCount; i++) {
      final a0 = (i * 6.2831853 / dashCount) + 0.05;
      final a1 = a0 + 0.45;
      final path = Path()
        ..addArc(Rect.fromCircle(center: c, radius: r), a0, a1 - a0);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.color != color;
}
