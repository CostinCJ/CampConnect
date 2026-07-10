import 'dart:math';

import 'package:flutter/material.dart';

/// A short, dependency-free confetti burst. Fires once on mount and stops.
/// Honors reduced motion: renders nothing, and never starts its animation
/// ticker, when `MediaQuery.disableAnimationsOf(context)` is true (the
/// celebration card carries the information; confetti is decoration only).
class ConfettiBurst extends StatefulWidget {
  /// Primary confetti color (the kid's team color); a few neutrals are mixed
  /// in automatically.
  final Color color;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    required this.color,
    this.duration = const Duration(milliseconds: 2200),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  final double x0; // 0..1 horizontal start
  final double vx; // horizontal drift
  final double vy; // initial upward velocity
  final double size;
  final double rotation;
  final Color color;

  const _Particle({
    required this.x0,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.color,
  });
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final palette = [
      widget.color,
      widget.color.withValues(alpha: 0.7),
      const Color(0xFFFFC107),
      const Color(0xFF4CAF50),
      const Color(0xFF1E88E5),
    ];
    _particles = List.generate(48, (i) {
      return _Particle(
        x0: rng.nextDouble(),
        vx: (rng.nextDouble() - 0.5) * 0.6,
        vy: 0.6 + rng.nextDouble() * 0.8,
        size: 6 + rng.nextDouble() * 6,
        rotation: rng.nextDouble() * pi * 2,
        color: palette[i % palette.length],
      );
    });
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // forward() is deliberately not started here: MediaQuery isn't safely
    // readable in initState, and starting the ticker unconditionally would
    // keep it running for the full duration even under reduced motion. See
    // didChangeDependencies below.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _particles,
            t: _controller.value,
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1

  const _ConfettiPainter({required this.particles, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      // Ballistic arc: up then down under gravity, fading near the end.
      final x = (p.x0 + p.vx * t) * size.width;
      final y = size.height * (0.55 - p.vy * t + 1.1 * t * t);
      final opacity = t < 0.8 ? 1.0 : (1.0 - (t - 0.8) / 0.2);
      paint.color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + t * pi * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
