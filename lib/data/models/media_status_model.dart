import '../../domain/entities/media_status.dart';
import 'track_model.dart';

class MediaStatusModel extends MediaStatus {
  const MediaStatusModel({
    required super.track,
    required super.state,
    required super.positionMs,
  });

  factory MediaStatusModel.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase and PascalCase keys (from both old and current .NET versions)
    final PlaybackState playbackState = _parseState(json);
    final int positionMs = _resolvePositionMs(json);

    // API returns all fields at root level (no nested song/track object).
    // Check for nested object first, fall back to root json.
    final Map<String, dynamic> trackJson = (json['song'] ??
            json['Song'] ??
            json['track'] ??
            json['Track']) as Map<String, dynamic>? ??
        json;

    return MediaStatusModel(
      track: TrackModel.fromJson(trackJson),
      state: playbackState,
      positionMs: positionMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'track': track is TrackModel
            ? (track as TrackModel).toJson()
            : {'title': track.title, 'artist': track.artist, 'album': track.album, 'albumArtUrl': track.albumArtUrl, 'durationMs': track.durationMs},
        'state': state.name,
        'positionMs': positionMs,
      };

  /// Safely convert dynamic value to bool (handles bool, int, String)
  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return defaultValue;
  }

  static PlaybackState _parseState(Map<String, dynamic> json) {
    final isPlayingVal = json['isPlaying'] ?? json['IsPlaying'];
    if (isPlayingVal != null) {
      return _toBool(isPlayingVal) ? PlaybackState.playing : PlaybackState.paused;
    }

    final isPausedVal = json['isPaused'] ?? json['IsPaused'];
    if (isPausedVal != null) {
      return _toBool(isPausedVal, defaultValue: true) ? PlaybackState.paused : PlaybackState.playing;
    }

    final playbackStateStr = (json['state'] ?? json['State'])?.toString().toLowerCase() ?? 'stopped';
    return PlaybackState.values.firstWhere(
      (e) => e.name == playbackStateStr,
      orElse: () => PlaybackState.stopped,
    );
  }

  static int _resolvePositionMs(Map<String, dynamic> json) {
    // Fields already in milliseconds
    if (json.containsKey('positionMs') || json.containsKey('PositionMs')) {
      final v = json['positionMs'] ?? json['PositionMs'];
      if (v is num) return v.round();
    }

    // Fields in seconds - convert to ms
    if (json.containsKey('elapsedSeconds') || json.containsKey('ElapsedSeconds')) {
      final v = json['elapsedSeconds'] ?? json['ElapsedSeconds'];
      if (v is num) return (v * 1000).round();
    }

    // "position" field - could be seconds (small) or ms (large)
    if (json.containsKey('position') || json.containsKey('Position')) {
      final v = json['position'] ?? json['Position'];
      if (v is num) {
        if (v == 0) return 0;
        // If value is small, it's likely seconds
        if (v < 1000) return (v * 1000).round();
        return v.round();
      }
    }

    return 0;
  }
}
