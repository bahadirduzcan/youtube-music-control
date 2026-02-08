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
    final int positionMs = _positionToMs(
      json['positionMs'] ??
          json['PositionMs'] ??
          json['position'] ??
          json['Position'] ??
          json['elapsedSeconds'] ??
          json['ElapsedSeconds'],
    );

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

  static int _positionToMs(dynamic value) {
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
