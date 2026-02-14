import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/media_status_model.dart';
import '../../domain/entities/media_status.dart';
import '../models/track_model.dart';

class MusicServiceException implements Exception {
  final String message;
  MusicServiceException(this.message);

  @override
  String toString() => 'MusicServiceException: $message';
}

class MusicApiService {
  final String host;
  final int port;
  final String authId;

  late String _baseUrl;
  late String _wsUrl;

  WebSocketChannel? _wsChannel;
  StreamController<MediaStatusModel>? _statusController;
  String? _accessToken;
  Timer? _reconnectTimer;
  Timer? _progressTimer;
  int _reconnectAttempt = 0;
  bool _isConnecting = false;
  bool _disposed = false;
  double? _lastVolume;
  MediaStatusModel? _lastStatus;

  MusicApiService({
    required this.host,
    required this.port,
    required this.authId,
  }) {
    _baseUrl = 'http://$host:$port';
    _wsUrl = 'ws://$host:$port/api/v1/ws';
  }

  Map<String, String> _authHeaders() => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> _ensureToken() async {
    if (_accessToken != null) return;

    final response = await http
        .post(Uri.parse('$_baseUrl/auth/$authId'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw MusicServiceException(
        'Failed to authenticate: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body);
    final token = json['accessToken'];
    if (token is! String || token.isEmpty) {
      throw MusicServiceException('Invalid access token');
    }

    _accessToken = token;
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    await _ensureToken();
    var headers = _authHeaders();
    var response = await request(headers);

    if (response.statusCode == 401) {
      _accessToken = null;
      await _ensureToken();
      headers = _authHeaders();
      response = await request(headers);
    }

    return response;
  }

  /// Fetch current playback status (one-time request)
  Future<MediaStatusModel> getStatus() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/song'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return MediaStatusModel.fromJson(json);
      } else if (response.statusCode == 204) {
        return MediaStatusModel.fromJson({});
      } else {
        throw MusicServiceException(
          'Failed to fetch status: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh status from server and update the stream
  Future<void> refreshStatus() async {
    try {
      final status = await getStatus();
      _lastStatus = status;
      _statusController?.add(status);

      if (status.state == PlaybackState.playing) {
        _startProgress();
      } else {
        _stopProgress();
      }
    } catch (_) {}
  }

  /// Stream status updates over WebSocket
  Stream<MediaStatusModel> statusStream() {
    _statusController ??= StreamController.broadcast();

    _connectWebSocket();

    return _statusController!.stream;
  }

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      await _ensureToken();
      _wsChannel?.sink.close();
      _wsChannel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: _authHeaders(),
        connectTimeout: const Duration(seconds: 10),
      );
      _reconnectAttempt = 0;

      // Fetch initial status from API if no cached data
      if (_lastStatus == null) {
        try {
          final initialStatus = await getStatus();
          _lastStatus = initialStatus;
          _statusController?.add(initialStatus);

          // Start progress timer if playing
          if (initialStatus.state == PlaybackState.playing) {
            _startProgress();
          }
        } catch (e) {
          // Ignore initial fetch errors, WS will provide updates
        }
      }

      _wsChannel!.stream.listen(
        (message) {
          try {
            final String payload =
                message is String ? message : utf8.decode(message as List<int>);
            final json = jsonDecode(payload) as Map<String, dynamic>;
            _handleIncoming(json);
          } catch (e) {
            // Silent catch for malformed messages
          }
        },
        onError: (error) {
          _statusController?.addError(error);
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _statusController?.addError(e);
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _wsChannel = null;
    _reconnectTimer?.cancel();

    final delaySeconds = (2 << _reconnectAttempt).clamp(2, 30);
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 6);

    _reconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () async {
        try {
          await _connectWebSocket();
        } catch (_) {
          // Swallow reconnect errors to avoid crashing the app.
        }
      },
    );
  }

  void _handleIncoming(Map<String, dynamic> json) {
    final String? eventType = json['type'];

    // PLAYER_STATE_CHANGED only has isPlaying + position (no track info)
    // VIDEO_CHANGED has full track info
    final isStateChangeOnly = eventType == 'PLAYER_STATE_CHANGED';

    final incoming = MediaStatusModel.fromJson(json);

    // Check if YTM is closed (no track info)
    final hasValidTrack = incoming.track.title.isNotEmpty ||
        incoming.track.artist.isNotEmpty ||
        incoming.track.durationMs > 0;

    MediaStatusModel merged;
    if (!hasValidTrack && _lastStatus != null && isStateChangeOnly) {
      // State change only - preserve track info from last status
      final hasPosition = json.containsKey('position');
      merged = MediaStatusModel(
        track: _lastStatus!.track,
        state: incoming.state,
        positionMs: hasPosition ? incoming.positionMs : _lastStatus!.positionMs,
      );
    } else if (!hasValidTrack) {
      // YTM closed - stop everything
      merged = MediaStatusModel(
        track: incoming.track,
        state: PlaybackState.stopped,
        positionMs: 0,
      );
      _stopProgress();
    } else {
      merged = _mergeStatus(incoming, json);

      if (merged.state == PlaybackState.playing) {
        _startProgress();
      } else {
        _stopProgress();
      }
    }

    _lastStatus = merged;
    _statusController?.add(merged);
  }

  MediaStatusModel _mergeStatus(
    MediaStatusModel incoming,
    Map<String, dynamic> raw,
  ) {
    if (_lastStatus == null) return incoming;

    final last = _lastStatus!;
    final hasState = raw.containsKey('isPlaying') ||
        raw.containsKey('IsPlaying') ||
        raw.containsKey('isPaused') ||
        raw.containsKey('IsPaused') ||
        raw.containsKey('state') ||
        raw.containsKey('State');
    final hasPosition = raw.containsKey('position') ||
        raw.containsKey('Position') ||
        raw.containsKey('positionMs') ||
        raw.containsKey('PositionMs') ||
        raw.containsKey('elapsedSeconds') ||
        raw.containsKey('ElapsedSeconds');

    final mergedTrack = TrackModel(
      title: incoming.track.title.isNotEmpty
          ? incoming.track.title
          : last.track.title,
      artist: incoming.track.artist.isNotEmpty
          ? incoming.track.artist
          : last.track.artist,
      album: incoming.track.album.isNotEmpty
          ? incoming.track.album
          : last.track.album,
      albumArtUrl: incoming.track.albumArtUrl ?? last.track.albumArtUrl,
      durationMs: incoming.track.durationMs > 0
          ? incoming.track.durationMs
          : last.track.durationMs,
    );

    final mergedState = hasState ? incoming.state : last.state;
    final mergedPosition = hasPosition ? incoming.positionMs : last.positionMs;

    return MediaStatusModel(
      track: mergedTrack,
      state: mergedState,
      positionMs: mergedPosition,
    );
  }

  void _startProgress() {
    _progressTimer?.cancel();

    // First tick after 300ms for faster UI update on track change
    _progressTimer = Timer(const Duration(milliseconds: 300), () {
      if (_disposed || _lastStatus?.state != PlaybackState.playing) return;
      _doProgressTick();

      // Then continue with normal 1-second intervals
      _progressTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _doProgressTick(),
      );
    });
  }

  void _doProgressTick() {
    if (_disposed) return;
    final current = _lastStatus;
    if (current == null || current.state != PlaybackState.playing) return;

    final nextPosition = current.positionMs + 1000;
    final duration = current.track.durationMs;
    final clamped =
        duration > 0 ? nextPosition.clamp(0, duration) : nextPosition;

    _lastStatus = MediaStatusModel(
      track: current.track,
      state: current.state,
      positionMs: clamped.toInt(),
    );
    _statusController?.add(_lastStatus!);
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Send a control command (play, pause, next, prev, stop)
  Future<void> sendControl(String action) async {
    try {
      switch (action) {
        case 'previous':
          await _post('/api/v1/previous');
          break;
        case 'next':
          await _post('/api/v1/next');
          break;
        case 'play':
          await _post('/api/v1/play');
          _applyLocalPlaybackState(PlaybackState.playing);
          break;
        case 'pause':
          await _post('/api/v1/pause');
          _applyLocalPlaybackState(PlaybackState.paused);
          break;
        case 'togglePlay':
          await _post('/api/v1/toggle-play');
          break;
        case 'toggleMute':
          await _post('/api/v1/toggle-mute');
          break;
        case 'volumeUp':
          await _changeVolumeBy(1);
          break;
        case 'volumeDown':
          await _changeVolumeBy(-1);
          break;
        default:
          throw MusicServiceException('Unsupported action: $action');
      }

      // If no status cached yet, fetch it now to ensure UI updates
      if (_lastStatus == null) {
        try {
          final status = await getStatus();
          _lastStatus = status;
          _statusController?.add(status);

          // Start progress timer if playing
          if (status.state == PlaybackState.playing) {
            _startProgress();
          }
        } catch (e) {
          // Ignore fetch errors, WS will eventually provide updates
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  void _applyLocalPlaybackState(PlaybackState state) {
    final current = _lastStatus;
    if (current == null) return;

    _lastStatus = MediaStatusModel(
      track: current.track,
      state: state,
      positionMs: current.positionMs,
    );
    _statusController?.add(_lastStatus!);

    if (state == PlaybackState.playing) {
      _startProgress();
    } else {
      _stopProgress();
    }
  }

  Future<void> _post(String path, {Map<String, dynamic>? body}) async {
    final response = await _authorizedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicServiceException(
        'Request failed: ${response.statusCode}',
      );
    }
  }

  Future<void> _setVolume(double volume) async {
    await _post('/api/v1/volume', body: {'volume': volume});
    _lastVolume = volume;
  }

  Future<void> _changeVolumeBy(double delta) async {
    final current = _lastVolume ?? 25;
    final next = (current + delta).clamp(0, 100);
    await _setVolume(next.toDouble());
  }

  Future<void> setVolume(double volume) async {
    await _setVolume(volume.clamp(0, 100).toDouble());
  }

  /// Seek to specific position in milliseconds
  Future<void> seekTo(int positionMs) async {
    try {
      // Convert milliseconds to seconds for API
      final seconds = (positionMs / 1000).round();

      await _post('/api/v1/seek-to', body: {'seconds': seconds});

      // Update local status immediately for better UX
      final current = _lastStatus;
      if (current != null) {
        _lastStatus = MediaStatusModel(
          track: current.track,
          state: current.state,
          positionMs: positionMs,
        );
        _statusController?.add(_lastStatus!);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Like the current song
  Future<void> like() async {
    await _post('/api/v1/like');
  }

  /// Dislike the current song
  Future<void> dislike() async {
    await _post('/api/v1/dislike');
  }

  /// Get like state of current song
  /// Returns 'LIKE', 'DISLIKE', 'INDIFFERENT', or null
  Future<String?> getLikeState() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/like-state'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['state'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current queue
  Future<Map<String, dynamic>?> getQueue() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/queue'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 204) {
        // No queue
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get queue info (detailed queue information)
  Future<Map<String, dynamic>?> getQueueInfo() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/queue-info'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 204) {
        // No queue
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    await _post('/api/v1/shuffle');
  }

  /// Get shuffle state
  Future<bool?> getShuffleState() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/shuffle'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['state'] as bool?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Go forward by seconds
  Future<void> goForward(int seconds) async {
    await _post('/api/v1/go-forward', body: {'seconds': seconds});
  }

  /// Go back by seconds
  Future<void> goBack(int seconds) async {
    await _post('/api/v1/go-back', body: {'seconds': seconds});
  }

  /// Cleanup WebSocket connection
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _progressTimer?.cancel();
    _wsChannel?.sink.close();
    _statusController?.close();
  }
}
