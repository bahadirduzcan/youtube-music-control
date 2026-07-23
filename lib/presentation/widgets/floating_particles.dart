import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A particle that floats and orbits around album art
class _Particle {
  double angle;
  double radius;
  double speed;
  double size;
  double opacity;
  double opacitySpeed;
  double radiusOffset;

  _Particle({
    required this.angle,
    required this.radius,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.opacitySpeed,
    required this.radiusOffset,
  });
}

/// Floating particles widget that renders orbiting particles around album art
class FloatingParticles extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;

  const FloatingParticles({
    super.key,
    required this.isPlaying,
    this.color = const Color(0xFF00F5FF),
    this.size = 200,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Initialize 20 particles with random properties
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        angle: _random.nextDouble() * 2 * math.pi,
        radius: 0.3 + _random.nextDouble() * 0.4,
        speed: 0.002 + _random.nextDouble() * 0.006,
        size: 1.5 + _random.nextDouble() * 3.5,
        opacity: _random.nextDouble(),
        opacitySpeed: 0.005 + _random.nextDouble() * 0.015,
        radiusOffset: _random.nextDouble() * 2 * math.pi,
      ));
    }

    // Setup animation controller.
    // Particle positions are advanced on every tick, but we intentionally do
    // NOT call setState here — that would rebuild the entire widget subtree
    // ~60 times per second. Instead the painter repaints from this controller
    // (see build), so only the CustomPaint layer redraws each frame.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
        if (!widget.isPlaying) return;
        for (final particle in _particles) {
          // Update angle for orbital motion
          particle.angle += particle.speed;
          if (particle.angle > 2 * math.pi) {
            particle.angle -= 2 * math.pi;
          }

          // Fade in/out
          particle.opacity += particle.opacitySpeed;
          if (particle.opacity >= 1.0 || particle.opacity <= 0.0) {
            particle.opacitySpeed = -particle.opacitySpeed;
            particle.opacity = particle.opacity.clamp(0.0, 1.0);
          }
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(FloatingParticles oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            color: widget.color,
            isPlaying: widget.isPlaying,
            repaint: _controller,
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final bool isPlaying;

  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.isPlaying,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = size.width / 2;

    for (final particle in particles) {
      // Calculate radius with subtle oscillation
      final oscillation = math.sin(particle.angle * 3 + particle.radiusOffset) * 0.05;
      final currentRadius = (particle.radius + oscillation) * maxRadius;

      // Calculate position
      final x = centerX + math.cos(particle.angle) * currentRadius;
      final y = centerY + math.sin(particle.angle) * currentRadius;

      // Draw particle with glow
      final opacity = isPlaying ? particle.opacity : particle.opacity * 0.3;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particle.size * 0.8);

      canvas.drawCircle(Offset(x, y), particle.size * 1.5, paint);

      // Draw solid core
      final corePaint = Paint()
        ..color = color.withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), particle.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
