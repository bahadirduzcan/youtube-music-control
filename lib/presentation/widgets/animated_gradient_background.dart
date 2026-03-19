import 'package:flutter/material.dart';

/// Animated gradient background that slowly shifts colors while music plays
class AnimatedGradientBackground extends StatefulWidget {
  final bool isPlaying;
  final List<Color> colors;
  final Widget? child;

  const AnimatedGradientBackground({
    super.key,
    required this.isPlaying,
    required this.colors,
    this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedGradientBackground oldWidget) {
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

  /// Generates a shifted version of the color list by interpolating
  /// each color toward the next color in the list.
  List<Color> _shiftedColors(List<Color> colors) {
    if (colors.length < 2) return colors;

    final shifted = <Color>[];
    for (int i = 0; i < colors.length; i++) {
      final nextIndex = (i + 1) % colors.length;
      shifted.add(Color.lerp(colors[i], colors[nextIndex], 0.5)!);
    }
    return shifted;
  }

  @override
  Widget build(BuildContext context) {
    final baseColors = widget.colors.length >= 2
        ? widget.colors
        : [widget.colors.firstOrNull ?? Colors.black, Colors.black];

    final shiftedColors = _shiftedColors(baseColors);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Interpolate between base colors and shifted colors
        final animatedColors = <Color>[];
        for (int i = 0; i < baseColors.length; i++) {
          final tween = ColorTween(
            begin: baseColors[i],
            end: shiftedColors[i],
          );

          // Use a sinusoidal curve for smooth breathing effect
          final t = (Curves.easeInOut.transform(
            (((_controller.value * 2) % 2) > 1)
                ? 2 - ((_controller.value * 2) % 2)
                : (_controller.value * 2) % 2,
          ));

          animatedColors.add(tween.transform(t)!);
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: animatedColors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
