import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/music_providers.dart';
import '../../domain/entities/media_status.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _volumeInitialized = false;
  late AnimationController _pulseController;
  MediaStatus? _lastValidStatus;
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final padded = remaining.toString().padLeft(2, '0');
    return '$minutes:$padded';
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(statusStreamProvider);
    final volumeValue = ref.watch(volumeProvider);

    // Track last valid status and errors
    statusAsync.whenData((status) {
      _lastValidStatus = status;
      _errorCount = 0;
    });

    if (statusAsync.hasError) {
      _errorCount++;
    }

    // Show error only after 3 consecutive errors
    final shouldShowError = statusAsync.hasError && _errorCount > 3;
    final effectiveStatus =
        shouldShowError ? null : (_lastValidStatus ?? statusAsync.valueOrNull);

    if (!_volumeInitialized) {
      _volumeInitialized = true;
      Future.microtask(() async {
        try {
          await ref.read(musicApiServiceProvider).setVolume(25);
          ref.read(volumeProvider.notifier).state = 25;
        } catch (_) {}
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Cosmic gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A0E27),
                  Color(0xFF1A1535),
                  Color(0xFF2D1B4E),
                  Color(0xFF1A0B2E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
          // Animated cosmic orbs
          Positioned(
            top: -100,
            left: -80,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                height: 280,
                width: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF00F5FF).withValues(
                          alpha: 0.15 + _pulseController.value * 0.1),
                      Color(0xFF00F5FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                height: 350,
                width: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFFF00FF).withValues(
                          alpha: 0.12 + _pulseController.value * 0.08),
                      Color(0xFFFF00FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            right: -60,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF7B2BFF).withValues(
                          alpha: 0.18 + (1 - _pulseController.value) * 0.1),
                      Color(0xFF7B2BFF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Stars effect
          ...List.generate(50, (index) {
            final random = index * 7919 % 100;
            return Positioned(
              top: (index * 137 % 100) /
                  100 *
                  MediaQuery.of(context).size.height,
              left: (random) / 100 * MediaQuery.of(context).size.width,
              child: Container(
                height: 2,
                width: 2,
                decoration: BoxDecoration(
                  color:
                      Colors.white.withValues(alpha: 0.3 + (random % 40) / 100),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }),
          SafeArea(
            child: _buildContent(effectiveStatus, shouldShowError, volumeValue),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      MediaStatus? effectiveStatus, bool shouldShowError, double volumeValue) {
    if (effectiveStatus == null && shouldShowError) {
      return _buildErrorState();
    }

    if (effectiveStatus == null) {
      return _buildLoadingState();
    }

    return _buildMainContent(effectiveStatus, volumeValue);
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Color(0xFFFF0080).withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF0080).withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFFF0080).withValues(alpha: 0.3),
                          Color(0xFFFF0080).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: Color(0xFFFF0080),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connection Lost',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0xFF00F5FF).withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Check WiFi & API server\n192.168.1.48:8877',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _GlowButton(
                    onPressed: () {
                      setState(() => _errorCount = 0);
                      ref.invalidate(statusStreamProvider);
                    },
                    label: 'RECONNECT',
                    icon: Icons.refresh_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFF00F5FF).withValues(alpha: 0.3),
                  Color(0xFF00F5FF).withValues(alpha: 0.0),
                ],
              ),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF00F5FF)),
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(MediaStatus status, double volumeValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(status),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTrackCard(status),
                  ],
                ),
              ),
              _buildControls(status),
              const SizedBox(height: 16),
              _buildVolumeControl(volumeValue),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(MediaStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YT MUSIC',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [
                      Color(0xFF00F5FF),
                      Color(0xFF7B2BFF),
                    ],
                  ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                shadows: [
                  Shadow(
                    color: Color(0xFF00F5FF).withValues(alpha: 0.6),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: status.state == PlaybackState.playing
                      ? [
                          Color(0xFF00F5FF).withValues(alpha: 0.3),
                          Color(0xFF7B2BFF).withValues(alpha: 0.3),
                        ]
                      : [
                          Color(0xFFFF0080).withValues(alpha: 0.3),
                          Color(0xFFFF0080).withValues(alpha: 0.3),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status.state == PlaybackState.playing
                      ? Color(0xFF00F5FF).withValues(alpha: 0.5)
                      : Color(0xFFFF0080).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                status.state == PlaybackState.playing
                    ? '● PLAYING'
                    : status.state == PlaybackState.paused
                        ? '❚❚ PAUSED'
                        : '■ STOPPED',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: status.state == PlaybackState.playing
                      ? const Color(0xFF00F5FF)
                      : const Color(0xFFFF0080),
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackCard(MediaStatus status) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Color(0xFF00F5FF).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00F5FF).withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildAlbumArt(status),
              const SizedBox(height: 20),
              _buildTrackInfo(status),
              const SizedBox(height: 20),
              _buildProgressBar(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MediaStatus status) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0xFF7B2BFF).withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: Color(0xFF00F5FF).withValues(alpha: 0.4),
              blurRadius: 60,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Container(
            height: 170,
            width: 170,
            child: status.track.albumArtUrl != null
                ? Image.network(
                    status.track.albumArtUrl!,
                    key: ValueKey(status.track.albumArtUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Color(0xFF1A1535),
                      child: Icon(
                        Icons.music_note_rounded,
                        size: 60,
                        color: Color(0xFF00F5FF).withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : Container(
                    color: Color(0xFF1A1535),
                    child: Icon(
                      Icons.music_note_rounded,
                      size: 60,
                      color: Color(0xFF00F5FF).withValues(alpha: 0.5),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(MediaStatus status) {
    return Column(
      children: [
        if (status.track.title.isNotEmpty)
          Text(
            status.track.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        if (status.track.artist.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            status.track.artist,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF00F5FF).withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
        if (status.track.album.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            status.track.album,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(MediaStatus status) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FractionallySizedBox(
              widthFactor: status.progress,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00F5FF),
                      Color(0xFF7B2BFF),
                      Color(0xFFFF0080),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00F5FF).withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatTime(status.elapsedSeconds),
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF00F5FF).withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _formatTime(status.totalSeconds),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(MediaStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CosmicButton(
          icon: Icons.skip_previous_rounded,
          action: 'previous',
          size: 52,
          glowColor: const Color(0xFF7B2BFF),
        ),
        const SizedBox(width: 16),
        _CosmicButton(
          icon: status.state == PlaybackState.playing
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          action: status.state == PlaybackState.playing ? 'pause' : 'play',
          size: 72,
          glowColor: const Color(0xFF00F5FF),
          isPrimary: true,
        ),
        const SizedBox(width: 16),
        _CosmicButton(
          icon: Icons.skip_next_rounded,
          action: 'next',
          size: 52,
          glowColor: const Color(0xFFFF0080),
        ),
      ],
    );
  }

  Widget _buildVolumeControl(double volumeValue) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFFFF0080).withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF0080).withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFFFF0080),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'VOLUME',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${volumeValue.toInt()}%',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF0080),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 20,
                            ),
                            activeTrackColor: const Color(0xFFFF0080),
                            inactiveTrackColor:
                                Colors.white.withValues(alpha: 0.1),
                            thumbColor: Colors.white,
                            overlayColor:
                                Color(0xFFFF0080).withValues(alpha: 0.3),
                          ),
                          child: Slider(
                            value: volumeValue,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (value) {
                              ref.read(volumeProvider.notifier).state = value;
                            },
                            onChangeEnd: (value) async {
                              await ref
                                  .read(musicApiServiceProvider)
                                  .setVolume(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SmallCosmicButton(
                    icon: Icons.volume_down_rounded,
                    onPressed: () async {
                      final next = (volumeValue - 5).clamp(0, 100).toDouble();
                      ref.read(volumeProvider.notifier).state = next;
                      await ref.read(musicApiServiceProvider).setVolume(next);
                    },
                  ),
                  _SmallCosmicButton(
                    icon: Icons.volume_off_rounded,
                    onPressed: () async {
                      await ref
                          .read(musicApiServiceProvider)
                          .sendControl('toggleMute');
                    },
                  ),
                  _SmallCosmicButton(
                    icon: Icons.volume_up_rounded,
                    onPressed: () async {
                      final next = (volumeValue + 5).clamp(0, 100).toDouble();
                      ref.read(volumeProvider.notifier).state = next;
                      await ref.read(musicApiServiceProvider).setVolume(next);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Cosmic themed control button
class _CosmicButton extends ConsumerWidget {
  final IconData icon;
  final String action;
  final double size;
  final Color glowColor;
  final bool isPrimary;

  const _CosmicButton({
    required this.icon,
    required this.action,
    required this.size,
    required this.glowColor,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        try {
          await ref.read(musicApiServiceProvider).sendControl(action);
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: const Color(0xFFFF0080),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      },
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              glowColor.withValues(alpha: 0.4),
              glowColor.withValues(alpha: 0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: glowColor.withValues(alpha: isPrimary ? 0.6 : 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: isPrimary ? 0.6 : 0.3),
                blurRadius: isPrimary ? 30 : 20,
                spreadRadius: isPrimary ? 2 : 0,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              size: size * (isPrimary ? 0.45 : 0.4),
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// Small cosmic button for volume controls
class _SmallCosmicButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallCosmicButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: Color(0xFFFF0080).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Color(0xFFFF0080),
        ),
      ),
    );
  }
}

// Glow button for reconnect
class _GlowButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _GlowButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00F5FF),
              Color(0xFF7B2BFF),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF00F5FF).withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
