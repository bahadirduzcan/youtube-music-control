import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated audio visualizer bars
class AudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final int barCount;
  final double height;

  const AudioVisualizer({
    super.key,
    required this.isPlaying,
    this.color = const Color(0xFF00F5FF),
    this.barCount = 24,
    this.height = 60,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Initialize bar heights
    for (int i = 0; i < widget.barCount; i++) {
      _barHeights.add(_random.nextDouble());
    }

    // Setup animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (widget.isPlaying && mounted) {
          setState(() {
            // Randomly update bar heights for animation effect
            for (int i = 0; i < _barHeights.length; i++) {
              if (_random.nextDouble() > 0.6) {
                _barHeights[i] = _random.nextDouble() * 0.8 + 0.2;
              }
            }
          });
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
        // Reset to low heights when paused
        setState(() {
          for (int i = 0; i < _barHeights.length; i++) {
            _barHeights[i] = 0.1;
          }
        });
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
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (index) {
            final barHeight = _barHeights[index] * widget.height;
            final delay = index * 0.02;

            return AnimatedContainer(
              duration: Duration(milliseconds: 150 + (delay * 1000).toInt()),
              curve: Curves.easeInOut,
              width: 3,
              height: widget.isPlaying ? barHeight : 4,
              margin: EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: widget.isPlaying
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
            );
          }),
        ),
      ),
    );
  }
}
