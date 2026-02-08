import '../../domain/entities/track.dart';

class TrackModel extends Track {
  const TrackModel({
    required super.title,
    required super.artist,
    required super.album,
    super.albumArtUrl,
    required super.durationMs,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase and PascalCase keys (from .NET JsonSerializer)
    final durationValue = json['durationMs'] ??
        json['DurationMs'] ??
        json['songDuration'] ??
        json['SongDuration'];

    final int durationMs = _durationToMs(durationValue);

    return TrackModel(
      title: json['title'] ?? json['Title'] ?? '',
      artist: json['artist'] ?? json['Artist'] ?? '',
      album: json['album'] ?? json['Album'] ?? '',
      albumArtUrl: json['albumArtUrl'] ??
          json['AlbumArtUrl'] ??
          json['imageSrc'] ??
          json['ImageSrc'],
      durationMs: durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'durationMs': durationMs,
      };

  static int _durationToMs(dynamic value) {
    if (value is num) {
      if (value == 0) return 0;
      if (value < 1000) {
        return (value * 1000).round();
      }
      return value.round();
    }
    return 0;
  }
}
