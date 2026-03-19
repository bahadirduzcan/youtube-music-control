import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveformProgressBar extends StatefulWidget {
  final double progress;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;
  final Function(double) onSeek;
  final double height;

  const WaveformProgressBar({
    super.key,
    required this.progress,
    required this.isPlaying,
    this.activeColor = const Color(0xFF00F5FF),
    this.inactiveColor = const Color(0xFF2C2C2C),
    required this.onSeek,
    this.height = 40,
  });

  @override
  State<WaveformProgressBar> createState() => _WaveformProgressBarState();
}

class _WaveformProgressBarState extends State<WaveformProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _barHeights;

  static const int _barCount = 40;

  @override
  void initState() {
    super.initState();

    final seededRandom = math.Random(42);
    _barHeights = List.generate(_barCount, (index) {
      return 0.2 + seededRandom.nextDouble() * 0.8;
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(WaveformProgressBar oldWidget) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              // Use local position directly from tap — no globalToLocal needed
              final percentage = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              widget.onSeek(percentage);
            },
            onHorizontalDragUpdate: (details) {
              final percentage = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
              widget.onSeek(percentage);
            },
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _WaveformPainter(
                    barHeights: _barHeights,
                    progress: widget.progress.clamp(0.0, 1.0),
                    isPlaying: widget.isPlaying,
                    activeColor: widget.activeColor,
                    inactiveColor: widget.inactiveColor,
                    animationValue: _controller.value,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final double progress;
  final bool isPlaying;
  final Color activeColor;
  final Color inactiveColor;
  final double animationValue;

  static const int _barCount = 40;

  _WaveformPainter({
    required this.barHeights,
    required this.progress,
    required this.isPlaying,
    required this.activeColor,
    required this.inactiveColor,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate bar width to fill the entire available width
    final gap = 2.0;
    final barWidth = (size.width - gap * (_barCount - 1)) / _barCount;
    final maxBarHeight = size.height;

    for (int i = 0; i < _barCount; i++) {
      // Bar's center position as a fraction of total width
      final barX = i * (barWidth + gap);
      final barCenter = (barX + barWidth / 2) / size.width;
      final isActive = barCenter <= progress;

      double heightMultiplier = barHeights[i];
      if (isPlaying) {
        final oscillation = math.sin(
          animationValue * 2 * math.pi + i * 0.3,
        ) * 0.08;
        heightMultiplier = (heightMultiplier + oscillation).clamp(0.15, 1.0);
      }

      final barHeight = maxBarHeight * heightMultiplier;
      final y = (size.height - barHeight) / 2;

      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      canvas.drawRRect(rect, paint);

      if (isActive) {
        final glowPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawRRect(rect, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
