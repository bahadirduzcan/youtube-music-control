import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/music_providers.dart';
import '../utils/theme_config.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  Map<String, dynamic>? _queueData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final queueInfo = await ref.read(musicApiServiceProvider).getQueue();
      if (mounted) {
        setState(() {
          _queueData = queueInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final theme = ThemeConfig(currentTheme);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.backgroundGradient,
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: _buildContent(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeConfig theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.textPrimaryColor, size: 20),
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          SizedBox(width: 4),
          Icon(Icons.queue_music, color: theme.primaryColor, size: 20),
          SizedBox(width: 6),
          Text(
            'Up Next',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeConfig theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(theme.primaryColor),
        ),
      );
    }

    if (_error != null) {
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
                    color: theme.tertiaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.tertiaryColor,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load queue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadQueue,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    if (_queueData == null || _queueData!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Queue is empty',
              style: TextStyle(
                fontSize: 18,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    // Parse queue items from API structure
    List<Map<String, dynamic>> queueItems = [];
    try {
      if (_queueData!.containsKey('items')) {
        final items = _queueData!['items'] as List<dynamic>;
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is Map<String, dynamic>) {
            // Extract from playlistPanelVideoWrapperRenderer.primaryRenderer.playlistPanelVideoRenderer
            Map<String, dynamic>? renderer;
            if (item.containsKey('playlistPanelVideoWrapperRenderer')) {
              final wrapper = item['playlistPanelVideoWrapperRenderer'] as Map<String, dynamic>;
              if (wrapper.containsKey('primaryRenderer') && wrapper['primaryRenderer'] is Map) {
                final primary = wrapper['primaryRenderer'] as Map<String, dynamic>;
                if (primary.containsKey('playlistPanelVideoRenderer') && primary['playlistPanelVideoRenderer'] is Map) {
                  renderer = Map<String, dynamic>.from(primary['playlistPanelVideoRenderer'] as Map);
                }
              }
            } else if (item.containsKey('playlistPanelVideoRenderer')) {
              renderer = Map<String, dynamic>.from(item['playlistPanelVideoRenderer'] as Map);
            }
            if (renderer != null) {
              renderer['_queueIndex'] = i;
              queueItems.add(renderer);
            }
          }
        }
      }
    } catch (e) {
      queueItems = [];
    }

    if (queueItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.queue_music,
              size: 64,
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Queue is empty',
              style: TextStyle(
                fontSize: 18,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    // Display as list
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: queueItems.length,
      itemBuilder: (context, index) {
        return _buildQueueItem(queueItems[index], index, theme);
      },
    );
  }

  Future<void> _onQueueItemTap(int queueIndex) async {
    try {
      await ref.read(musicApiServiceProvider).setQueueIndex(queueIndex);
      if (mounted) {
        _loadQueue();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to play song')),
        );
      }
    }
  }

  Widget _buildQueueItem(
      Map<String, dynamic> item, int index, ThemeConfig theme) {
    String? title;
    String? artist;
    String? thumbnail;
    String? duration;
    bool isSelected = item['selected'] == true;
    int queueIndex = item['_queueIndex'] as int? ?? index;

    try {
      if (item.containsKey('title') && item['title'] is Map) {
        final runs = (item['title'] as Map)['runs'];
        if (runs is List && runs.isNotEmpty && runs[0] is Map) {
          title = runs[0]['text']?.toString();
        }
      }

      if (item.containsKey('longBylineText') && item['longBylineText'] is Map) {
        final runs = (item['longBylineText'] as Map)['runs'];
        if (runs is List && runs.isNotEmpty && runs[0] is Map) {
          artist = runs[0]['text']?.toString();
        }
      }

      if (item.containsKey('thumbnail') && item['thumbnail'] is Map) {
        final thumbs = (item['thumbnail'] as Map)['thumbnails'];
        if (thumbs is List && thumbs.isNotEmpty) {
          thumbnail = (thumbs.last as Map)['url']?.toString();
        }
      }

      if (item.containsKey('lengthText') && item['lengthText'] is Map) {
        final runs = (item['lengthText'] as Map)['runs'];
        if (runs is List && runs.isNotEmpty && runs[0] is Map) {
          duration = runs[0]['text']?.toString();
        }
      }
    } catch (e) {
      // Ignore parse errors
    }

    if (title == null || title.trim().isEmpty) {
      return SizedBox.shrink();
    }

    return InkWell(
      onTap: isSelected ? null : () => _onQueueItemTap(queueIndex),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            // Index or playing indicator
            SizedBox(
              width: 22,
              child: Center(
                child: isSelected
                    ? Icon(Icons.equalizer, color: theme.primaryColor, size: 14)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 11,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 8),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: (thumbnail != null && thumbnail.isNotEmpty)
                  ? Image.network(
                      thumbnail,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(theme),
                    )
                  : _buildPlaceholderImage(theme),
            ),
            SizedBox(width: 8),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? theme.primaryColor
                          : theme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist != null && artist.trim().isNotEmpty)
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Duration
            if (duration != null && duration.isNotEmpty)
              Text(
                duration,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textSecondaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeConfig theme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.primaryColor.withValues(alpha: 0.5),
        size: 16,
      ),
    );
  }
}
