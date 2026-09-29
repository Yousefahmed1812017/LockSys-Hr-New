import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lean angle of the L stem in the LockSys mark (degrees).
const double kLeanDegrees = 15.5;

/// Diagonal parallel lines at the L stem angle. Brand background texture.
/// Use ONLY on splash, onboarding art, login art, sidebar/navy hero cards,
/// with 9-16% opacity. Never behind tables or dense text.
class LPattern extends StatelessWidget {
  const LPattern({
    super.key,
    this.color,
    this.gap = 40,
    this.fade = false,
    this.child,
  });

  final Color? color;
  final double gap;

  /// Fade the pattern out toward the edges (used on hero art).
  final bool fade;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget paint = CustomPaint(
      painter: _LPatternPainter(
        color ?? AppColors.blue.withValues(alpha: .09),
        gap,
      ),
      child: const SizedBox.expand(),
    );
    if (fade) {
      final dir = Directionality.of(context);
      paint = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
          colors: [Colors.transparent, Colors.black, Colors.transparent],
          stops: [0, .6, 1],
        ).createShader(r, textDirection: dir),
        child: paint,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: paint),
        ?child,
      ],
    );
  }
}

class _LPatternPainter extends CustomPainter {
  _LPatternPainter(this.color, this.gap);
  final Color color;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final a = (90 + kLeanDegrees) * math.pi / 180; // gradient direction
    final dir = Offset(math.sin(a), -math.cos(a));
    final perp = Offset(-dir.dy, dir.dx);
    final c = size.center(Offset.zero);
    final diag = size.longestSide * 1.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.clipRect(Offset.zero & size);
    for (double t = -diag; t <= diag; t += gap) {
      final p = c + dir * t;
      canvas.drawLine(p - perp * diag, p + perp * diag, paint);
    }
  }

  @override
  bool shouldRepaint(_LPatternPainter old) =>
      old.color != color || old.gap != gap;
}

/// The L corner marker (stem + foot). Structural marker on cards / headers.
class LTick extends StatelessWidget {
  const LTick({super.key, this.color, this.opacity = .3, this.height = 15});

  final Color? color;
  final double opacity;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size(height * 24 / 28, height),
        painter: _LTickPainter(color ?? AppColors.blue),
      ),
    );
  }
}

class _LTickPainter extends CustomPainter {
  _LTickPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(12 * s, 1 * s)
      ..lineTo(5 * s, 26 * s)
      ..lineTo(23 * s, 26 * s);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(_LTickPainter old) => old.color != color;
}

/// The LockSys "L" mark. [progress] 0..1 draws the stroke (splash animation).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 112,
    this.color,
    this.progress = 1,
    this.strokeUnits = 3.2,
  });

  final double height;
  final Color? color;
  final double progress;

  /// Stroke width in a 30x40 viewBox. 3.2 = logo, ~0.9 = big outline art.
  final double strokeUnits;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(height * 30 / 40, height),
      painter: _LogoPainter(color ?? AppColors.blue, progress, strokeUnits),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.color, this.progress, this.units);
  final Color color;
  final double progress;
  final double units;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 30;
    final path = Path()
      ..moveTo(14 * s, 1 * s)
      ..lineTo(4 * s, 36 * s)
      ..lineTo(26 * s, 36 * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = units * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress.clamp(0, 1)), paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.progress != progress || old.color != color || old.units != units;
}
