import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../providers/music_providers.dart';
import '../../domain/entities/media_status.dart';
import '../utils/theme_config.dart';
import '../utils/share_helper.dart';
import '../widgets/floating_particles.dart';
import '../widgets/waveform_progress_bar.dart';
import '../widgets/animated_gradient_background.dart';
import 'settings_screen.dart';
import 'queue_screen.dart';
import 'search_screen.dart';
import 'story_preview_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  MediaStatus? _lastValidStatus;
  int _errorCount = 0;
  bool _isLiked = false;
  bool _isDisliked = false;
  String? _currentTrackId;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConnectionTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionTimer?.cancel();
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
    if (seconds < 0) seconds = 0;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    final padded = remaining.toString().padLeft(2, '0');
    return '$minutes:$padded';
  }

  void _showVolumeOverlay(BuildContext context, ThemeConfig theme) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => Center(
        child: Consumer(
          builder: (context, ref, _) {
            final volumeValue = ref.watch(volumeProvider);
            return Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.volume,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(Icons.volume_down, color: theme.textSecondaryColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: theme.primaryColor,
                                  inactiveTrackColor: theme.textSecondaryColor.withValues(alpha: 0.2),
                                  thumbColor: theme.textPrimaryColor,
                                ),
                                child: Slider(
                                  value: volumeValue,
                                  min: 0,
                                  max: 100,
                                  onChanged: (value) {
                                    ref.read(volumeProvider.notifier).state = value;
                                  },
                                  onChangeEnd: (value) async {
                                    await ref.read(musicApiServiceProvider).setVolume(value);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.volume_up, color: theme.textSecondaryColor, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${volumeValue.round()}%',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
        final hasTrackData = status.track.title.isNotEmpty ||
            status.track.artist.isNotEmpty ||
            status.track.durationMs > 0;

        if (hasTrackData) {
          _lastValidStatus = status;
        } else if (_lastValidStatus != null) {
          _lastValidStatus = MediaStatus(
            track: _lastValidStatus!.track,
            state: status.state,
            positionMs: status.positionMs > 0
                ? status.positionMs
                : _lastValidStatus!.positionMs,
          );
        }

        _errorCount = 0;
        _connectionTimer?.cancel();
      },
      error: (_, __) {
        _errorCount++;
      },
      loading: () {},
    );

    final shouldShowError = _lastValidStatus == null && _errorCount > 3;
    final effectiveStatus =
        shouldShowError ? null : (_lastValidStatus ?? statusAsync.valueOrNull);
    final isPlaying = effectiveStatus?.state == PlaybackState.playing;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedGradientBackground(
            isPlaying: isPlaying,
            colors: theme.backgroundGradient,
          ),
          // Album art blur background
          if (theme.useAlbumArtBlur &&
              effectiveStatus != null &&
              effectiveStatus.track.albumArtUrl != null)
            Positioned.fill(
              child: Stack(
                children: [
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
    final l10n = AppLocalizations.of(context)!;
    if (effectiveStatus == null && shouldShowError) {
      return _buildErrorState(theme, l10n);
    }
    if (effectiveStatus == null) {
      return _buildLoadingState(theme, l10n);
    }
    return _buildMainContent(effectiveStatus, volumeValue, theme);
  }

  Widget _buildErrorState(ThemeConfig theme, AppLocalizations l10n) {
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
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Color(0xFFFF0080).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFFFF0080)),
                  const SizedBox(height: 24),
                  Text(
                    l10n.connectionLost,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final config = ref.watch(musicConfigProvider);
                      return Text(
                        '${l10n.checkConnection}\n${config.host}:${config.port}',
                        style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
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
                    label: Text(l10n.reconnect),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00F5FF),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                    icon: Icon(Icons.settings, size: 20),
                    label: Text(l10n.settings),
                    style: TextButton.styleFrom(foregroundColor: theme.textSecondaryColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeConfig theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(theme.primaryColor),
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(l10n.connecting, style: TextStyle(color: theme.textSecondaryColor, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildMainContent(MediaStatus status, double volumeValue, ThemeConfig theme) {
    final trackId = '${status.track.title}_${status.track.artist}';
    if (_currentTrackId != trackId) {
      _currentTrackId = trackId;
      _isLiked = false;
      _isDisliked = false;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _buildHeader(theme, status),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAlbumArt(status, theme),
                const SizedBox(height: 20),
                _buildTrackInfo(status, theme),
                const SizedBox(height: 20),
                _buildProgressWithLikes(status, theme),
                const SizedBox(height: 24),
                _buildGlassControls(status, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeConfig theme, MediaStatus status) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, color: theme.primaryColor, size: 24),
            SizedBox(width: 8),
            Text(
              l10n.nowPlaying,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimaryColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Search
            IconButton(
              icon: Icon(Icons.search, color: theme.textSecondaryColor, size: 22),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
            // Queue
            IconButton(
              icon: Icon(Icons.queue_music, color: theme.textSecondaryColor, size: 22),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueScreen()));
              },
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
            ),
            // More menu (share, volume, settings)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.textSecondaryColor, size: 22),
              color: theme.overlayBackgroundColor,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                switch (value) {
                  case 'share':
                    _showShareMenu(context, theme, status);
                    break;
                  case 'volume':
                    _showVolumeOverlay(context, theme);
                    break;
                  case 'settings':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, color: theme.textSecondaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(l10n.share, style: TextStyle(color: theme.textPrimaryColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'volume',
                  child: Row(
                    children: [
                      Icon(Icons.volume_up, color: theme.textSecondaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(l10n.volume, style: TextStyle(color: theme.textPrimaryColor)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: theme.textSecondaryColor, size: 20),
                      const SizedBox(width: 12),
                      Text(l10n.settings, style: TextStyle(color: theme.textPrimaryColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _showShareMenu(BuildContext ctx, ThemeConfig theme, MediaStatus status) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.overlayBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.textSecondaryColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.share, color: theme.primaryColor),
              title: Text(l10n.share, style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                ShareHelper.shareTrack(
                  status.track,
                  l10n.shareText(status.track.title, status.track.artist),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: theme.primaryColor),
              title: Text(l10n.shareStory, style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryPreviewScreen(track: status.track, theme: theme),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumArt(MediaStatus status, ThemeConfig theme) {
    final isPlaying = status.state == PlaybackState.playing;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Floating particles behind album art
        if (isPlaying)
          SizedBox(
            width: 320,
            height: 320,
            child: FloatingParticles(
              isPlaying: isPlaying,
              color: theme.primaryColor,
              size: 320,
            ),
          ),
        // Album art with animated transition
        Container(
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: status.track.albumArtUrl != null
                  ? Image.network(
                      status.track.albumArtUrl!,
                      key: ValueKey(status.track.albumArtUrl),
                      fit: BoxFit.cover,
                      width: 280,
                      height: 280,
                      errorBuilder: (_, __, ___) => _buildPlaceholderArt(theme),
                    )
                  : _buildPlaceholderArt(theme),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderArt(ThemeConfig theme) {
    return Container(
      width: 280,
      height: 280,
      color: Color(0xFF1A1535),
      child: Icon(
        Icons.music_note_rounded,
        size: 100,
        color: theme.primaryColor.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildTrackInfo(MediaStatus status, ThemeConfig theme) {
    return Column(
      children: [
        if (status.track.title.isNotEmpty)
          Text(
            status.track.title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        if (status.track.artist.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            status.track.artist,
            style: TextStyle(fontSize: 15, color: theme.primaryColor, fontWeight: FontWeight.w500),
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
      child: Column(
        children: [
          // Waveform progress bar
          WaveformProgressBar(
            progress: status.progress,
            isPlaying: status.state == PlaybackState.playing,
            activeColor: theme.primaryColor,
            inactiveColor: theme.textSecondaryColor.withValues(alpha: 0.2),
            height: 32,
            onSeek: (percentage) {
              final positionMs = (status.track.durationMs * percentage).round();
              ref.read(musicApiServiceProvider).seekTo(positionMs);
            },
          ),
          const SizedBox(height: 8),
          // Time + like/dislike row
          Row(
            children: [
              IconButton(
                onPressed: () {
                  final wasDisliked = _isDisliked;
                  setState(() {
                    if (_isDisliked) {
                      _isDisliked = false;
                    } else {
                      _isDisliked = true;
                      _isLiked = false;
                    }
                  });
                  if (!wasDisliked) ref.read(musicApiServiceProvider).dislike();
                },
                icon: Icon(
                  _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                  color: _isDisliked ? Color(0xFFFF0080) : theme.textSecondaryColor,
                  size: 22,
                ),
              ),
              Text(
                _formatTime(status.elapsedSeconds),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.textSecondaryColor.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(status.totalSeconds),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.textSecondaryColor.withValues(alpha: 0.8),
                ),
              ),
              IconButton(
                onPressed: () {
                  final wasLiked = _isLiked;
                  setState(() {
                    if (_isLiked) {
                      _isLiked = false;
                    } else {
                      _isLiked = true;
                      _isDisliked = false;
                    }
                  });
                  if (!wasLiked) ref.read(musicApiServiceProvider).like();
                },
                icon: Icon(
                  _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  color: _isLiked ? Color(0xFF00F5FF) : theme.textSecondaryColor,
                  size: 22,
                ),
              ),
            ],
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
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: theme.cardBorderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () => ref.read(musicApiServiceProvider).goBack(10),
                icon: Icon(Icons.replay_10, color: theme.textSecondaryColor, size: 28),
              ),
              IconButton(
                onPressed: () => ref.read(musicApiServiceProvider).sendControl('previous'),
                icon: Icon(Icons.skip_previous, color: theme.textPrimaryColor.withValues(alpha: 0.8), size: 32),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  final action = status.state == PlaybackState.playing ? 'pause' : 'play';
                  ref.read(musicApiServiceProvider).sendControl(action);
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: Icon(
                    status.state == PlaybackState.playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(musicApiServiceProvider).sendControl('next'),
                icon: Icon(Icons.skip_next, color: theme.textPrimaryColor.withValues(alpha: 0.8), size: 32),
              ),
              IconButton(
                onPressed: () => ref.read(musicApiServiceProvider).goForward(10),
                icon: Icon(Icons.forward_10, color: theme.textSecondaryColor, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
