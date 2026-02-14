import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/music_providers.dart';
import '../../domain/entities/media_status.dart';
import '../utils/theme_config.dart';
import 'settings_screen.dart';
import 'queue_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  MediaStatus? _lastValidStatus;
  int _errorCount = 0;
  OverlayEntry? _volumeOverlay;
  bool _isLiked = false;
  bool _isDisliked = false;
  String? _currentTrackId;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startConnectionTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _volumeOverlay?.remove();
    _volumeOverlay = null;
    _connectionTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(musicApiServiceProvider).refreshStatus();
    }
  }

  void _startConnectionTimer() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _lastValidStatus == null) {
        setState(() => _errorCount = 10);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final padded = remaining.toString().padLeft(2, '0');
    return '$minutes:$padded';
  }

  void _showVolumeOverlay(BuildContext context, double currentVolume) {
    _volumeOverlay?.remove();

    _volumeOverlay = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setOverlayState) {
          final volumeValue = ref.watch(volumeProvider);

          return Stack(
            children: [
              // Background tap to close
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    _volumeOverlay?.remove();
                    _volumeOverlay = null;
                  },
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
              // Volume menu - centered
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 300,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        decoration: BoxDecoration(
                          color: Color(0xFF2A2A3A).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Color(0xFF00F5FF).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00F5FF).withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Volume',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00F5FF),
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Icon(
                                  Icons.volume_down,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: 12),
                                      activeTrackColor: Color(0xFF00F5FF),
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.2),
                                      thumbColor: Colors.white,
                                    ),
                                    child: Slider(
                                      value: volumeValue,
                                      min: 0,
                                      max: 100,
                                      onChanged: (value) {
                                        setOverlayState(() {
                                          ref
                                              .read(volumeProvider.notifier)
                                              .state = value;
                                        });
                                      },
                                      onChangeEnd: (value) async {
                                        await ref
                                            .read(musicApiServiceProvider)
                                            .setVolume(value);
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Icon(
                                  Icons.volume_up,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${volumeValue.round()}%',
                              style: TextStyle(
                                color: Color(0xFF00F5FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    Overlay.of(context).insert(_volumeOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(statusStreamProvider);
    final volumeValue = ref.watch(volumeProvider);
    final currentTheme = ref.watch(themeProvider);
    final theme = ThemeConfig(currentTheme);

    // Track last valid status and errors
    statusAsync.when(
      data: (status) {
        _lastValidStatus = status;
        _errorCount = 0;
        _connectionTimer?.cancel();
      },
      error: (_, __) {
        _errorCount++;
        if (_lastValidStatus == null) {
          _errorCount = 10;
        }
      },
      loading: () {},
    );

    // Hata durumunu göster
    final shouldShowError = _errorCount > 3;
    if (shouldShowError && _lastValidStatus != null) {
      _lastValidStatus = null;
    }
    final effectiveStatus =
        shouldShowError ? null : (_lastValidStatus ?? statusAsync.valueOrNull);

    return Scaffold(
      body: Stack(
        children: [
          // Theme-based gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.backgroundGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
          // Album art blur background (only for dark/cosmic themes)
          if (theme.useAlbumArtBlur &&
              effectiveStatus != null &&
              effectiveStatus.track.albumArtUrl != null)
            Positioned.fill(
              child: Stack(
                children: [
                  // Blurred album art
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                    child: Image.network(
                      effectiveStatus.track.albumArtUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => SizedBox.shrink(),
                    ),
                  ),
                  // Dark overlay for better readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            child: _buildContent(
                effectiveStatus, shouldShowError, volumeValue, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MediaStatus? effectiveStatus, bool shouldShowError,
      double volumeValue, ThemeConfig theme) {
    if (effectiveStatus == null && shouldShowError) {
      return _buildErrorState(theme);
    }

    if (effectiveStatus == null) {
      return _buildLoadingState(theme);
    }

    return _buildMainContent(effectiveStatus, volumeValue, theme);
  }

  Widget _buildErrorState(ThemeConfig theme) {
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 56,
                    color: Color(0xFFFF0080),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connection Lost',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final config = ref.watch(musicConfigProvider);
                      return Text(
                        'Check WiFi and API server\n${config.host}:${config.port}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _errorCount = 0);
                      _startConnectionTimer();
                      ref.invalidate(statusStreamProvider);
                    },
                    icon: Icon(Icons.refresh_rounded),
                    label: Text('RECONNECT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00F5FF),
                      foregroundColor: Colors.black,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.settings, size: 20),
                    label: Text('Settings'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeConfig theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF00F5FF)),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Connecting...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      MediaStatus status, double volumeValue, ThemeConfig theme) {
    // Reset like/dislike state when track changes
    final trackId = '${status.track.title}_${status.track.artist}';
    if (_currentTrackId != trackId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentTrackId = trackId;
            _isLiked = false;
            _isDisliked = false;
          });
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAlbumArt(status, theme),
                const SizedBox(height: 32),
                _buildTrackInfo(status, theme),
                const SizedBox(height: 32),
                _buildProgressWithLikes(status, theme),
                const SizedBox(height: 48),
                _buildGlassControls(status, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeConfig theme) {
    final volumeValue = ref.watch(volumeProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, color: theme.primaryColor, size: 24),
            SizedBox(width: 8),
            Text(
              'Now Playing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.queue_music,
                  color: Colors.white.withValues(alpha: 0.7)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QueueScreen(),
                  ),
                );
              },
            ),
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.volume_up,
                    color: Colors.white.withValues(alpha: 0.7)),
                onPressed: () => _showVolumeOverlay(context, volumeValue),
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings,
                  color: Colors.white.withValues(alpha: 0.7)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAlbumArt(MediaStatus status, ThemeConfig theme) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: status.track.albumArtUrl != null
            ? Image.network(
                status.track.albumArtUrl!,
                key: ValueKey(status.track.albumArtUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Color(0xFF1A1535),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 100,
                    color: theme.primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              )
            : Container(
                color: Color(0xFF1A1535),
                child: Icon(
                  Icons.music_note_rounded,
                  size: 100,
                  color: theme.primaryColor.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }

  Widget _buildTrackInfo(MediaStatus status, ThemeConfig theme) {
    return Column(
      children: [
        if (status.track.title.isNotEmpty)
          Text(
            status.track.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        if (status.track.artist.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            status.track.artist,
            style: TextStyle(
              fontSize: 18,
              color: theme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildProgressWithLikes(MediaStatus status, ThemeConfig theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Dislike button
          IconButton(
            onPressed: () async {
              try {
                await ref.read(musicApiServiceProvider).dislike();
                setState(() {
                  if (_isDisliked) {
                    // Already disliked, toggle off
                    _isDisliked = false;
                  } else {
                    // Not disliked, dislike it
                    _isDisliked = true;
                    _isLiked = false;
                  }
                });
              } catch (e) {}
            },
            icon: Icon(
              _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: _isDisliked
                  ? Color(0xFFFF0080)
                  : Colors.white.withValues(alpha: 0.4),
              size: 24,
            ),
          ),
          // Elapsed time (gerçek konumdan)
          Text(
            _formatTime(status.positionMs ~/ 1000),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          // Progress bar
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    final localPosition = details.localPosition.dx;
                    final percentage = (localPosition / width).clamp(0.0, 1.0);
                    final positionMs =
                        (status.track.durationMs * percentage).round();
                    ref.read(musicApiServiceProvider).seekTo(positionMs);
                  },
                  child: Stack(
                    children: [
                      // Background track
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Progress track
                      FractionallySizedBox(
                        widthFactor: status.progress,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Thumb
                      Positioned(
                        left: (constraints.maxWidth * status.progress) - 6,
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Total time
          Text(
            _formatTime(status.totalSeconds),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.5,
            ),
          ),
          // Like button
          IconButton(
            onPressed: () async {
              try {
                await ref.read(musicApiServiceProvider).like();
                setState(() {
                  if (_isLiked) {
                    // Already liked, toggle off
                    _isLiked = false;
                  } else {
                    // Not liked, like it
                    _isLiked = true;
                    _isDisliked = false;
                  }
                });
              } catch (e) {}
            },
            icon: Icon(
              _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: _isLiked
                  ? Color(0xFF00F5FF)
                  : Colors.white.withValues(alpha: 0.4),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassControls(MediaStatus status, ThemeConfig theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(48),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(48),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () async {
                  try {
                    await ref.read(musicApiServiceProvider).goBack(10);
                  } catch (e) {}
                },
                icon: Icon(
                  Icons.replay_10,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 28,
                ),
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(musicApiServiceProvider)
                        .sendControl('previous');
                  } catch (e) {}
                },
                icon: Icon(
                  Icons.skip_previous,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 32,
                ),
              ),
              // Play/Pause button
              GestureDetector(
                onTap: () async {
                  try {
                    final action = status.state == PlaybackState.playing
                        ? 'pause'
                        : 'play';
                    await ref.read(musicApiServiceProvider).sendControl(action);
                  } catch (e) {}
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    status.state == PlaybackState.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await ref.read(musicApiServiceProvider).sendControl('next');
                  } catch (e) {}
                },
                icon: Icon(
                  Icons.skip_next,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 32,
                ),
              ),
              IconButton(
                onPressed: () async {
                  try {
                    await ref.read(musicApiServiceProvider).goForward(10);
                  } catch (e) {}
                },
                icon: Icon(
                  Icons.forward_10,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
