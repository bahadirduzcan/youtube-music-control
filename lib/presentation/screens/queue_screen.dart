import 'dart:convert';
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
      final queueInfo = await ref.read(musicApiServiceProvider).getQueueInfo();
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
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.textPrimaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Icon(Icons.queue_music, color: theme.primaryColor, size: 24),
          SizedBox(width: 8),
          Text(
            'Up Next',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
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

    // Parse queue items from new API structure
    List<dynamic> queueItems = [];
    try {
      if (_queueData!.containsKey('items')) {
        final items = _queueData!['items'] as List<dynamic>;
        // Extract from playlistPanelVideoRenderer structure
        for (final item in items) {
          if (item is Map<String, dynamic> &&
              item.containsKey('playlistPanelVideoRenderer')) {
            queueItems.add(item['playlistPanelVideoRenderer']);
          }
        }
      }
    } catch (e) {
      queueItems = [];
    }

    if (queueItems.isEmpty) {
      // Show raw JSON if we can't parse it
      return SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue Data (Raw)',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textSecondaryColor,
              ),
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: SelectableText(
                    JsonEncoder.withIndent('  ').convert(_queueData),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: theme.textPrimaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Display as list
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: queueItems.length,
      itemBuilder: (context, index) {
        final item = queueItems[index] as Map<String, dynamic>;
        return _buildQueueItem(item, index, theme);
      },
    );
  }

  Widget _buildQueueItem(
      Map<String, dynamic> item, int index, ThemeConfig theme) {
    // Extract from new API structure
    String? title;
    String? artist;
    String? thumbnail;
    String? duration;

    try {
      // Title from title.runs[0].text
      if (item.containsKey('title') && item['title'] is Map) {
        final titleData = item['title'] as Map;
        if (titleData.containsKey('runs') && titleData['runs'] is List) {
          final runs = titleData['runs'] as List;
          if (runs.isNotEmpty && runs[0] is Map) {
            title = runs[0]['text']?.toString();
          }
        }
      }

      // Artist from longBylineText.runs[0].text
      if (item.containsKey('longBylineText') && item['longBylineText'] is Map) {
        final byline = item['longBylineText'] as Map;
        if (byline.containsKey('runs') && byline['runs'] is List) {
          final runs = byline['runs'] as List;
          if (runs.isNotEmpty && runs[0] is Map) {
            artist = runs[0]['text']?.toString();
          }
        }
      }

      // Thumbnail from thumbnail.thumbnails[0].url (get highest quality)
      if (item.containsKey('thumbnail') && item['thumbnail'] is Map) {
        final thumbData = item['thumbnail'] as Map;
        if (thumbData.containsKey('thumbnails') && thumbData['thumbnails'] is List) {
          final thumbs = thumbData['thumbnails'] as List;
          if (thumbs.isNotEmpty) {
            // Get last thumbnail (usually highest quality)
            final thumb = thumbs.last as Map;
            thumbnail = thumb['url']?.toString();
          }
        }
      }

      // Duration from lengthText.runs[0].text
      if (item.containsKey('lengthText') && item['lengthText'] is Map) {
        final lengthData = item['lengthText'] as Map;
        if (lengthData.containsKey('runs') && lengthData['runs'] is List) {
          final runs = lengthData['runs'] as List;
          if (runs.isNotEmpty && runs[0] is Map) {
            duration = runs[0]['text']?.toString();
          }
        }
      }
    } catch (e) {
      // Ignore parse errors
    }

    // Skip items without title
    if (title == null || title.trim().isEmpty) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                // Index number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: (thumbnail != null && thumbnail.isNotEmpty)
                      ? Image.network(
                          thumbnail,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(theme),
                        )
                      : _buildPlaceholderImage(theme),
                ),
                SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist != null && artist.trim().isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          artist,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Duration (if available)
                if (duration != null && duration.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      duration,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeConfig theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.music_note,
        color: theme.primaryColor.withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }
}
