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

    final Map<String, dynamic> trackJson = (json['song'] ??
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
        'track': (track as TrackModel).toJson(),
        'state': state.name,
        'positionMs': positionMs,
      };

  static PlaybackState _parseState(Map<String, dynamic> json) {
    if (json.containsKey('isPlaying') || json.containsKey('IsPlaying')) {
      final isPlaying = json['isPlaying'] ?? json['IsPlaying'] ?? false;
      return (isPlaying == true) ? PlaybackState.playing : PlaybackState.paused;
    }

    if (json.containsKey('isPaused') || json.containsKey('IsPaused')) {
      final isPaused = json['isPaused'] ?? json['IsPaused'] ?? true;
      return (isPaused == true) ? PlaybackState.paused : PlaybackState.playing;
    }

    final playbackStateStr = json['state'] ?? json['State'] ?? 'stopped';
    return PlaybackState.values.firstWhere(
      (e) => e.name == playbackStateStr.toString().toLowerCase(),
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
