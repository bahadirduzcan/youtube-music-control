import 'package:flutter/foundation.dart';

@immutable
class Track {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final int durationMs;

  const Track({
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    required this.durationMs,
  });

  @override
  String toString() => 'Track(title: $title, artist: $artist, album: $album)';
}
