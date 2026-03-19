import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../providers/music_providers.dart';
import '../utils/theme_config.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    try {
      final response = await ref.read(musicApiServiceProvider).search(query);
      if (!mounted) return;
      final items = _parseSearchResults(response);
      debugPrint('Search keys: ${response.keys.toList()}, parsed: ${items.length}');
      setState(() {
        _results = items;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      if (!mounted) return;
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = true;
        _lastError = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _parseSearchResults(Map<String, dynamic> response) {
    final List<Map<String, dynamic>> parsed = [];
    try {
      // First, try to unwrap YouTube Music internal renderer structures
      final unwrapped = _unwrapRendererItems(response);
      if (unwrapped.isNotEmpty) {
        for (final item in unwrapped) {
          // Pre-extracted items (from musicCardShelfRenderer) already have flat fields
          if (item['_isTopResult'] == true) {
            if (item['videoId'] != null && (item['title'] as String?)?.isNotEmpty == true) {
              parsed.add({
                'title': item['title'] ?? '',
                'artist': item['artist'] ?? '',
                'thumbnail': item['thumbnail'],
                'videoId': item['videoId'],
                'duration': item['duration'],
              });
            }
            continue;
          }
          final result = _extractItem(item);
          if (result != null) parsed.add(result);
        }
        if (parsed.isNotEmpty) return parsed;
      }

      // Fallback: Collect ALL lists of maps found anywhere in the response
      final allLists = <List<dynamic>>[];
      _collectAllLists(response, allLists, 0);

      // Use the list with the highest score (containing videoId/title items)
      List<dynamic>? bestList;
      int bestScore = 0;

      for (final list in allLists) {
        int score = 0;
        for (final item in list) {
          if (item is Map) {
            if (_deepFind(item, 'videoId') != null) score += 10;
            if (item.containsKey('videoId')) score += 10;
            if (item.containsKey('title')) score += 5;
            if (item.containsKey('artist') || item.containsKey('author')) score += 3;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestList = list;
        }
      }

      if (bestList != null) {
        for (final item in bestList) {
          if (item is! Map<String, dynamic>) continue;
          final result = _extractItem(item);
          if (result != null) parsed.add(result);
        }
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return parsed;
  }

  /// Unwrap YouTube Music internal renderer structures
  /// Handles formats like musicShelfRenderer > contents > musicResponsiveListItemRenderer
  List<Map<String, dynamic>> _unwrapRendererItems(Map<String, dynamic> response) {
    final items = <Map<String, dynamic>>[];

    // Try direct results/content arrays
    for (final key in ['results', 'items', 'content', 'tracks', 'songs', 'videos']) {
      final val = response[key];
      if (val is List) {
        for (final item in val) {
          if (item is Map<String, dynamic>) items.add(item);
        }
        if (items.isNotEmpty) return items;
      }
    }

    // Try YouTube Music internal API structures
    // Path: contents > tabbedSearchResultsRenderer > tabs[0] (selected) > tabRenderer > content > sectionListRenderer > contents
    try {
      final tabs = response['contents']?['tabbedSearchResultsRenderer']?['tabs'];
      if (tabs is List) {
        // Find the selected tab (first tab = YT Music catalog)
        for (final tab in tabs) {
          if (tab is Map && tab['tabRenderer'] is Map) {
            final tabRenderer = tab['tabRenderer'] as Map;
            if (tabRenderer['selected'] == true || tabs.indexOf(tab) == 0) {
              _extractFromSections(tabRenderer['content'], items);
              break;
            }
          }
        }
      }
    } catch (_) {}

    // Fallback: full recursive search
    if (items.isEmpty) {
      _extractFromSections(response, items);
    }

    return items;
  }

  /// Extract items from YouTube Music section/shelf renderer structures
  void _extractFromSections(dynamic json, List<Map<String, dynamic>> items, [int depth = 0]) {
    if (depth > 15 || json == null) return;

    if (json is Map<String, dynamic>) {
      // musicCardShelfRenderer is the "top result" card - extract it as an item
      if (json.containsKey('musicCardShelfRenderer') && json['musicCardShelfRenderer'] is Map<String, dynamic>) {
        final card = json['musicCardShelfRenderer'] as Map<String, dynamic>;
        // Extract top result from musicCardShelfRenderer
        final videoId = _deepFind(card['onTap'], 'videoId')
            ?? _deepFind(card['title'], 'videoId');
        if (videoId != null) {
          final title = _extractRunsText(card['title']);
          // Parse subtitle: "Şarkı • Emre Fel ve Funktakl • 3:36"
          String? artist;
          String? duration;
          if (card['subtitle'] is Map) {
            final runs = (card['subtitle'] as Map)['runs'];
            if (runs is List) {
              final textParts = <String>[];
              for (final run in runs) {
                if (run is Map) textParts.add(run['text']?.toString() ?? '');
              }
              final joined = textParts.join('');
              // Split by " • " to get parts like ["Şarkı", "Emre Fel ve Funktakl", "3:36"]
              final parts = joined.split(' • ');
              if (parts.length >= 3) {
                artist = parts[1]; // Second part is artist
                duration = parts.last; // Last part is duration
              } else if (parts.length == 2) {
                artist = parts[1];
              }
            }
          }
          // Get thumbnail
          String? thumbnail;
          final thumbRenderer = card['thumbnail'];
          if (thumbRenderer is Map) {
            final musicThumb = thumbRenderer['musicThumbnailRenderer'];
            if (musicThumb is Map && musicThumb['thumbnail'] is Map) {
              final thumbs = (musicThumb['thumbnail'] as Map)['thumbnails'];
              if (thumbs is List && thumbs.isNotEmpty) {
                thumbnail = (thumbs.last as Map)['url']?.toString();
              }
            }
          }
          items.add({
            'videoId': videoId,
            'title': title ?? '',
            'artist': artist ?? '',
            'thumbnail': thumbnail,
            'duration': duration,
            '_isTopResult': true,
          });
        }
        // Also recurse into musicCardShelfRenderer's contents for YouTube videos
        _extractFromSections(card['contents'], items, depth + 1);
      }

      // If this map IS a renderer item with extractable data, unwrap it
      for (final rendererKey in [
        'musicResponsiveListItemRenderer',
        'playlistPanelVideoRenderer',
        'musicTwoRowItemRenderer',
        'musicCardRenderer',
      ]) {
        if (json.containsKey(rendererKey) && json[rendererKey] is Map<String, dynamic>) {
          items.add(json[rendererKey] as Map<String, dynamic>);
        }
      }

      // Recurse into known container keys
      for (final containerKey in [
        'contents', 'content', 'items', 'tabs', 'tabRenderer',
        'sectionListRenderer', 'musicShelfRenderer',
        'tabbedSearchResultsRenderer', 'itemSectionRenderer',
        'gridRenderer',
      ]) {
        if (json.containsKey(containerKey)) {
          _extractFromSections(json[containerKey], items, depth + 1);
        }
      }
    } else if (json is List) {
      for (final item in json) {
        _extractFromSections(item, items, depth + 1);
      }
    }
  }

  /// Recursively collect all List<Map> from the JSON tree
  void _collectAllLists(dynamic json, List<List<dynamic>> results, int depth) {
    if (depth > 10) return;

    if (json is List && json.isNotEmpty && json.first is Map) {
      results.add(json);
    }

    if (json is Map) {
      for (final value in json.values) {
        _collectAllLists(value, results, depth + 1);
      }
    } else if (json is List) {
      for (final item in json) {
        _collectAllLists(item, results, depth + 1);
      }
    }
  }

  /// Recursively find a value by key in a nested JSON structure
  String? _deepFind(dynamic json, String key, [int depth = 0]) {
    if (depth > 8) return null;
    if (json is Map) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key].toString();
      }
      for (final value in json.values) {
        final found = _deepFind(value, key, depth + 1);
        if (found != null) return found;
      }
    } else if (json is List) {
      for (final item in json) {
        final found = _deepFind(item, key, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Extract text from YouTube Music's runs format: {runs: [{text: "..."}]}
  String? _extractRunsText(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      if (data['runs'] is List) {
        final runs = data['runs'] as List;
        return runs.whereType<Map>().map((r) => r['text']?.toString() ?? '').join('');
      }
      if (data['text'] is String) return data['text'] as String;
    }
    return null;
  }

  Map<String, dynamic>? _extractItem(Map<String, dynamic> item) {
    String? title;
    String? artist;
    String? thumbnail;
    String? videoId;
    String? duration;

    try {
      // VideoId - check multiple locations
      videoId = item['videoId']?.toString()
          ?? item['id']?.toString()
          ?? (item['playlistItemData'] is Map ? (item['playlistItemData'] as Map)['videoId']?.toString() : null)
          ?? _deepFind(item['overlay'], 'videoId')
          ?? _deepFind(item['navigationEndpoint'], 'videoId');

      // Title - multiple formats
      title = _extractRunsText(item['title'])
          ?? (item['name'] is String ? item['name'] as String : null);

      // If title is in flexColumns (YouTube Music internal format)
      if (title == null && item['flexColumns'] is List) {
        final cols = item['flexColumns'] as List;
        if (cols.isNotEmpty && cols[0] is Map) {
          final renderer = (cols[0] as Map)['musicResponsiveListItemFlexColumnRenderer'];
          if (renderer is Map) {
            title = _extractRunsText(renderer['text']);
          }
        }
      }

      // Artist - multiple formats
      artist = (item['artist'] is String ? item['artist'] as String : null)
          ?? (item['author'] is String ? item['author'] as String : null)
          ?? _extractRunsText(item['longBylineText'])
          ?? _extractRunsText(item['shortBylineText']);

      // Artist from flexColumns (second column has format: "Type • Artist • Views/Duration")
      if (artist == null && item['flexColumns'] is List) {
        final cols = item['flexColumns'] as List;
        if (cols.length > 1 && cols[1] is Map) {
          final renderer = (cols[1] as Map)['musicResponsiveListItemFlexColumnRenderer'];
          if (renderer is Map && renderer['text'] is Map) {
            final runs = (renderer['text'] as Map)['runs'];
            if (runs is List) {
              // Find artist: the run with a browseEndpoint pointing to an artist/channel page
              for (final run in runs) {
                if (run is! Map) continue;
                final nav = run['navigationEndpoint'];
                if (nav is Map && nav['browseEndpoint'] is Map) {
                  final pageType = _deepFind(nav['browseEndpoint'], 'pageType');
                  if (pageType != null && (pageType.contains('ARTIST') || pageType.contains('CHANNEL'))) {
                    artist = run['text']?.toString();
                    break;
                  }
                }
              }
              // Fallback: parse "Type • Artist • ..." pattern
              if (artist == null) {
                final texts = runs.whereType<Map>().map((r) => r['text']?.toString() ?? '').toList();
                final joined = texts.join('');
                final parts = joined.split(' • ');
                // Second part is typically the artist (first is type like "Şarkı", "Video")
                if (parts.length >= 2) {
                  artist = parts[1];
                }
              }
              // Extract duration from runs (last text matching time pattern like "3:36")
              for (final run in runs.reversed) {
                if (run is! Map) continue;
                final text = run['text']?.toString() ?? '';
                if (RegExp(r'^\d+:\d{2}$').hasMatch(text)) {
                  duration ??= text;
                  break;
                }
              }
            }
          }
        }
      }

      // Artist from artists array
      if (artist == null && item['artists'] is List) {
        final artists = item['artists'] as List;
        if (artists.isNotEmpty) {
          artist = artists[0] is String
              ? artists[0] as String
              : (artists[0] is Map ? (artists[0]['name'] ?? artists[0]['text'])?.toString() : null);
        }
      }

      // Thumbnail - multiple formats
      if (item['thumbnail'] is String) {
        thumbnail = item['thumbnail'] as String;
      } else if (item['thumbnail'] is Map) {
        final thumbData = item['thumbnail'] as Map;
        if (thumbData['thumbnails'] is List) {
          final thumbs = thumbData['thumbnails'] as List;
          if (thumbs.isNotEmpty) thumbnail = (thumbs.last as Map)['url']?.toString();
        } else if (thumbData['musicThumbnailRenderer'] is Map) {
          final renderer = thumbData['musicThumbnailRenderer'] as Map;
          if (renderer['thumbnail'] is Map) {
            final innerThumbs = (renderer['thumbnail'] as Map)['thumbnails'];
            if (innerThumbs is List && innerThumbs.isNotEmpty) {
              thumbnail = (innerThumbs.last as Map)['url']?.toString();
            }
          }
        } else {
          thumbnail = thumbData['url']?.toString();
        }
      } else if (item['thumbnails'] is List) {
        final thumbs = item['thumbnails'] as List;
        if (thumbs.isNotEmpty && thumbs.last is Map) thumbnail = (thumbs.last as Map)['url']?.toString();
      }

      // Duration - multiple formats
      duration = _extractRunsText(item['lengthText']);
      if (duration == null && item['duration'] is String) {
        duration = item['duration'] as String;
      } else if (duration == null && item['duration_seconds'] is num) {
        final secs = (item['duration_seconds'] as num).toInt();
        duration = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
      }
      // Duration from fixedColumns (YouTube Music internal)
      if (duration == null && item['fixedColumns'] is List) {
        final cols = item['fixedColumns'] as List;
        if (cols.isNotEmpty && cols[0] is Map) {
          final renderer = (cols[0] as Map)['musicResponsiveListItemFixedColumnRenderer'];
          if (renderer is Map) {
            duration = _extractRunsText(renderer['text']);
          }
        }
      }

      if ((title == null || title.trim().isEmpty) && videoId == null) return null;

      return {
        'title': title ?? '',
        'artist': artist ?? '',
        'thumbnail': thumbnail,
        'videoId': videoId,
        'duration': duration,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _playNow(String videoId, String title, ThemeConfig theme) async {
    final l10n = AppLocalizations.of(context)!;
    // Show loading feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${l10n.playing}: $title',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: theme.primaryColor.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await ref.read(musicApiServiceProvider).playNow(videoId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: theme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _addToQueue(String videoId, ThemeConfig theme) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(musicApiServiceProvider).addToQueue(videoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.addedToQueue, style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: theme.primaryColor.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: theme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final theme = ThemeConfig(currentTheme);
    final l10n = AppLocalizations.of(context)!;

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
              _buildSearchBar(theme, l10n),
              Expanded(child: _buildContent(theme, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeConfig theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.textPrimaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    style: GoogleFonts.poppins(color: theme.textPrimaryColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      hintStyle: GoogleFonts.poppins(color: theme.textSecondaryColor, fontSize: 15),
                      prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: theme.textSecondaryColor, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeConfig theme, AppLocalizations l10n) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(theme.primaryColor)),
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: theme.textSecondaryColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _lastError != null ? _lastError! : l10n.searchEmpty,
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_rounded, size: 64, color: theme.primaryColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(l10n.searchHint, style: TextStyle(fontSize: 16, color: theme.textSecondaryColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildResultItem(_results[index], theme, index),
    );
  }

  Widget _buildResultItem(Map<String, dynamic> item, ThemeConfig theme, int index) {
    final title = item['title'] as String? ?? '';
    final artist = item['artist'] as String? ?? '';
    final thumbnail = item['thumbnail'] as String?;
    final videoId = item['videoId'] as String?;
    final duration = item['duration'] as String?;

    if (title.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: videoId != null ? () => _playNow(videoId, title, theme) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                // Index number
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Thumbnail with play overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (thumbnail != null && thumbnail.isNotEmpty)
                          ? Image.network(
                              thumbnail,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                            )
                          : _buildPlaceholder(theme),
                    ),
                    // Play icon overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (artist.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          artist,
                          style: GoogleFonts.poppins(fontSize: 12, color: theme.textSecondaryColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Duration
                if (duration != null && duration.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      duration,
                      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor.withValues(alpha: 0.7)),
                    ),
                  ),
                // Add to queue
                if (videoId != null)
                  IconButton(
                    icon: Icon(Icons.playlist_add, color: theme.primaryColor, size: 22),
                    onPressed: () => _addToQueue(videoId, theme),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeConfig theme) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.music_note, color: theme.primaryColor.withValues(alpha: 0.5), size: 24),
    );
  }
}
