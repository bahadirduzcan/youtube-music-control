import 'package:flutter/foundation.dart';
import 'track.dart';

enum PlaybackState {
  playing,
  paused,
  stopped,
}

@immutable
class MediaStatus {
  final Track track;
  final PlaybackState state;
  final int positionMs;

  const MediaStatus({
    required this.track,
    required this.state,
    required this.positionMs,
  });

  double get progress {
    if (track.durationMs == 0) return 0;
    return (positionMs / track.durationMs).clamp(0, 1);
  }

  int get elapsedSeconds => (positionMs ~/ 1000);
  int get totalSeconds => (track.durationMs ~/ 1000);

  @override
  String toString() =>
      'MediaStatus(track: ${track.title}, state: $state, pos: ${elapsedSeconds}s/${totalSeconds}s)';
}
