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
  StreamSubscription? _wsSubscription;
  StreamController<MediaStatusModel>? _statusController;
  String? _accessToken;
  Completer<void>? _tokenCompleter;
  Timer? _reconnectTimer;
  Timer? _progressTimer;
  Timer? _pollTimer;
  int _reconnectAttempt = 0;
  bool _isConnecting = false;
  bool _disposed = false;
  bool _isProgressRunning = false;
  double? _lastVolume;
  MediaStatusModel? _lastStatus;
  DateTime? _optimisticGuardUntil;
  PlaybackState? _optimisticState;

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
    if (_tokenCompleter != null) return _tokenCompleter!.future;

    _tokenCompleter = Completer<void>();
    try {
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
      _tokenCompleter!.complete();
    } catch (e) {
      _tokenCompleter!.completeError(e);
      rethrow;
    } finally {
      _tokenCompleter = null;
    }
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
  }

  /// Safely emit status to stream (prevents crash after dispose)
  void _emitStatus(MediaStatusModel status) {
    if (_disposed) return;
    _lastStatus = status;
    _statusController?.add(status);
  }

  /// Refresh status from server and update the stream
  Future<void> refreshStatus() async {
    if (_disposed) return;
    try {
      final status = await getStatus();
      if (_disposed) return;
      final previousState = _lastStatus?.state;

      // Use server position if non-zero, otherwise keep local
      final int syncedPosition;
      if (status.positionMs > 0) {
        syncedPosition = status.positionMs;
      } else if (_lastStatus != null &&
          _lastStatus!.track.title == status.track.title) {
        // Same track, server returned 0 - keep local position
        syncedPosition = _lastStatus!.positionMs;
      } else {
        syncedPosition = 0;
      }

      // Respect optimistic guard during refresh — never clear early,
      // let it expire naturally to prevent stale WS messages from flipping state
      final PlaybackState effectiveState;
      if (_isOptimisticGuardActive && status.state != _optimisticState) {
        effectiveState = _optimisticState!;
      } else {
        effectiveState = status.state;
      }

      final merged = MediaStatusModel(
        track: status.track,
        state: effectiveState,
        positionMs: syncedPosition,
      );

      _emitStatus(merged);

      if (merged.state != previousState || previousState == null) {
        if (merged.state == PlaybackState.playing) {
          _startProgress();
        } else {
          _stopProgress();
        }
      }
    } catch (_) {}
  }

  /// Stream status updates over WebSocket
  Stream<MediaStatusModel> statusStream() {
    _statusController ??= StreamController<MediaStatusModel>.broadcast();

    _connectWebSocket();
    _startPolling();

    return _statusController!.stream;
  }

  /// Periodic poll as safety net for missed WS events
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_disposed) refreshStatus();
    });
  }

  Future<void> _connectWebSocket() async {
    if (_disposed) return;
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      await _ensureToken();
      if (_disposed) return;

      // Cancel old subscription before replacing channel
      _wsSubscription?.cancel();
      _wsChannel?.sink.close();
      _wsChannel = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: _authHeaders(),
        connectTimeout: const Duration(seconds: 10),
      );
      _reconnectAttempt = 0;

      // Fetch status from API on (re)connect
      try {
        final freshStatus = await getStatus();
        if (_disposed) return;
        final previousState = _lastStatus?.state;

        // Use server position if non-zero, otherwise keep local for same track
        final int syncedPosition;
        if (freshStatus.positionMs > 0) {
          syncedPosition = freshStatus.positionMs;
        } else if (_lastStatus != null &&
            _lastStatus!.track.title == freshStatus.track.title) {
          syncedPosition = _lastStatus!.positionMs;
        } else {
          syncedPosition = 0;
        }

        // Respect optimistic guard on (re)connect fetch too
        final PlaybackState effectiveState;
        if (_isOptimisticGuardActive && freshStatus.state != _optimisticState) {
          effectiveState = _optimisticState!;
        } else {
          effectiveState = freshStatus.state;
        }

        final merged = MediaStatusModel(
          track: freshStatus.track,
          state: effectiveState,
          positionMs: syncedPosition,
        );
        _emitStatus(merged);

        // Timer'ı sadece state değiştiyse veya ilk bağlantıysa yönet
        if (merged.state != previousState || previousState == null) {
          if (merged.state == PlaybackState.playing) {
            _startProgress();
          } else {
            _stopProgress();
          }
        }
      } catch (e) {
        // Ignore fetch errors, WS will provide updates
      }

      _isConnecting = false;

      _wsSubscription = _wsChannel!.stream.listen(
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
          if (!_disposed) _statusController?.addError(error);
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnecting = false;
      if (!_disposed) _statusController?.addError(e);
      _scheduleReconnect();
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

  /// Whether we are within the optimistic guard window
  bool get _isOptimisticGuardActive =>
      _optimisticGuardUntil != null &&
      _optimisticState != null &&
      DateTime.now().isBefore(_optimisticGuardUntil!);

  void _handleIncoming(Map<String, dynamic> json) {
    final String? eventType = json['type'];

    // PLAYER_STATE_CHANGED only has isPlaying + position (no track info)
    // VIDEO_CHANGED has full track info but often no state field
    final isStateChangeOnly = eventType == 'PLAYER_STATE_CHANGED';
    final isVideoChanged = eventType == 'VIDEO_CHANGED';

    final incoming = MediaStatusModel.fromJson(json);

    // Check if the raw JSON contains an explicit state field
    final hasExplicitState = json.containsKey('isPlaying') ||
        json.containsKey('IsPlaying') ||
        json.containsKey('isPaused') ||
        json.containsKey('IsPaused') ||
        json.containsKey('state') ||
        json.containsKey('State');

    // Check if YTM is closed (no track info)
    final hasValidTrack = incoming.track.title.isNotEmpty ||
        incoming.track.artist.isNotEmpty ||
        incoming.track.durationMs > 0;

    // Only use incoming state if the event actually has a state field.
    // Otherwise preserve last known state (prevents defaulting to 'stopped').
    final effectiveIncomingState = hasExplicitState
        ? incoming.state
        : (_lastStatus?.state ?? incoming.state);

    MediaStatusModel merged;
    if (!hasValidTrack && _lastStatus != null && isStateChangeOnly) {
      // State change only - preserve track info from last status
      final hasPosition = json.containsKey('position');
      merged = MediaStatusModel(
        track: _lastStatus!.track,
        state: effectiveIncomingState,
        positionMs: hasPosition ? incoming.positionMs : _lastStatus!.positionMs,
      );
    } else if (!hasValidTrack && _lastStatus != null) {
      // No track info and not a state-change event - preserve last track
      merged = MediaStatusModel(
        track: _lastStatus!.track,
        state: effectiveIncomingState,
        positionMs: _lastStatus!.positionMs,
      );
    } else if (!hasValidTrack) {
      // No track info and no previous status - skip emitting
      return;
    } else {
      merged = _mergeStatus(incoming, json);
    }

    // VIDEO_CHANGED without explicit state means a new track started playing.
    // Set state to playing AND activate guard to block transitional
    // PLAYER_STATE_CHANGED {isPlaying: false} events that the server sends
    // briefly during track transitions.
    if (isVideoChanged && !hasExplicitState) {
      merged = MediaStatusModel(
        track: merged.track,
        state: PlaybackState.playing,
        positionMs: merged.positionMs,
      );
      _optimisticState = PlaybackState.playing;
      _optimisticGuardUntil = DateTime.now().add(const Duration(seconds: 3));
    }

    // Guard: After play/pause or track change, ignore contradicting state from WebSocket
    // for the full guard window. Never clear early — a single "confirmation"
    // doesn't guarantee no more stale messages are in flight.
    if (_isOptimisticGuardActive && merged.state != _optimisticState) {
      merged = MediaStatusModel(
        track: merged.track,
        state: _optimisticState!,
        positionMs: merged.positionMs,
      );
    }

    _emitStatus(merged);

    // Manage progress timer: restart if playing with valid duration, stop otherwise
    if (merged.state == PlaybackState.playing && merged.track.durationMs > 0) {
      _startProgress();
    } else if (merged.state != PlaybackState.playing) {
      _stopProgress();
    }
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
    // Zaten çalışıyorsa tekrar başlatma — timer leak'in ana sebebi buydu
    if (_isProgressRunning) return;

    _stopProgress();
    _isProgressRunning = true;

    _progressTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _doProgressTick(),
    );
  }

  void _doProgressTick() {
    if (_disposed) {
      _stopProgress();
      return;
    }
    final current = _lastStatus;
    if (current == null || current.state != PlaybackState.playing) {
      _stopProgress();
      return;
    }

    final nextPosition = current.positionMs + 1000;
    final duration = current.track.durationMs;

    // Duration bilinmiyorsa (0) timer'ı durdur, süre sınırsız artmasın
    if (duration <= 0) {
      _stopProgress();
      return;
    }

    // Şarkı süresine ulaştıysa artık artırma
    if (nextPosition >= duration) {
      _emitStatus(MediaStatusModel(
        track: current.track,
        state: current.state,
        positionMs: duration,
      ));
      _stopProgress();
      return;
    }

    _emitStatus(MediaStatusModel(
      track: current.track,
      state: current.state,
      positionMs: nextPosition,
    ));
  }

  void _stopProgress() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _isProgressRunning = false;
  }

  /// Send a control command (play, pause, next, prev, stop)
  Future<void> sendControl(String action) async {
    switch (action) {
      case 'previous':
        await _post('/api/v1/previous');
        break;
      case 'next':
        await _post('/api/v1/next');
        break;
      case 'play':
        _applyLocalPlaybackState(PlaybackState.playing);
        await _post('/api/v1/play');
        break;
      case 'pause':
        _applyLocalPlaybackState(PlaybackState.paused);
        await _post('/api/v1/pause');
        break;
      case 'togglePlay':
        final currentState = _lastStatus?.state;
        final toggledState = currentState == PlaybackState.playing
            ? PlaybackState.paused
            : PlaybackState.playing;
        _applyLocalPlaybackState(toggledState);
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

    // Always fetch status after control actions to sync state + position.
    // For play/pause we already applied local state above for instant UI,
    // but we still need server sync for accurate position.
    try {
      final isTrackChange = action == 'previous' || action == 'next';
      final isPlayPause = action == 'play' || action == 'pause' || action == 'togglePlay';
      await Future.delayed(Duration(milliseconds: isTrackChange ? 500 : 300));
      if (_disposed) return;
      final status = await getStatus();
      if (_disposed) return;

      // For track changes, always use server position (new song).
      // For play/pause, use server position if non-zero, otherwise keep local.
      final int syncedPosition;
      if (isTrackChange) {
        syncedPosition = status.positionMs;
      } else if (status.positionMs > 0) {
        syncedPosition = status.positionMs;
      } else if (_lastStatus != null) {
        syncedPosition = _lastStatus!.positionMs;
      } else {
        syncedPosition = 0;
      }

      // For play/pause: respect guard, never clear early
      final PlaybackState effectiveState;
      if (isPlayPause && _isOptimisticGuardActive && status.state != _optimisticState) {
        effectiveState = _optimisticState!;
      } else {
        effectiveState = status.state;
      }

      final previousState = _lastStatus?.state;
      final merged = MediaStatusModel(
        track: status.track,
        state: effectiveState,
        positionMs: syncedPosition,
      );
      _emitStatus(merged);

      if (merged.state != previousState || previousState == null) {
        if (merged.state == PlaybackState.playing) {
          _startProgress();
        } else {
          _stopProgress();
        }
      }
    } catch (_) {
      // Ignore fetch errors, WS will eventually provide updates
    }
  }

  void _applyLocalPlaybackState(PlaybackState newState) {
    final current = _lastStatus;
    if (current == null) return;

    final previousState = current.state;

    // Set optimistic guard to prevent WebSocket from overriding this state
    _optimisticState = newState;
    _optimisticGuardUntil = DateTime.now().add(const Duration(seconds: 3));

    _emitStatus(MediaStatusModel(
      track: current.track,
      state: newState,
      positionMs: current.positionMs,
    ));

    // Timer'ı sadece state gerçekten değiştiyse yönet
    if (newState != previousState) {
      if (newState == PlaybackState.playing) {
        _startProgress();
      } else {
        _stopProgress();
      }
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

  /// Get current volume state from the server (0-100) and mute state.
  /// Also caches the value locally so volumeUp/volumeDown operate from the
  /// real player volume instead of a hardcoded default.
  Future<({double volume, bool isMuted})?> getVolume() async {
    try {
      final response = await _authorizedRequest(
        (headers) => http.get(
          Uri.parse('$_baseUrl/api/v1/volume'),
          headers: headers,
        ),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final v = (json['state'] as num?)?.toDouble();
        if (v != null) {
          _lastVolume = v;
          return (
            volume: v.clamp(0, 100).toDouble(),
            isMuted: json['isMuted'] == true,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Seek to specific position in milliseconds
  Future<void> seekTo(int positionMs) async {
    final current = _lastStatus;
    final maxMs = current?.track.durationMs ?? 0;
    final clampedMs = maxMs > 0 ? positionMs.clamp(0, maxMs) : positionMs.clamp(0, positionMs);
    final seconds = (clampedMs / 1000).round();

    await _post('/api/v1/seek-to', body: {'seconds': seconds});

    // Update local status immediately for better UX
    if (current != null) {
      _emitStatus(MediaStatusModel(
        track: current.track,
        state: current.state,
        positionMs: clampedMs,
      ));
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

  /// Search for music
  Future<Map<String, dynamic>> search(String query,
      {String? params, String? continuation}) async {
    final body = <String, dynamic>{'query': query};
    if (params != null) body['params'] = params;
    if (continuation != null) body['continuation'] = continuation;

    final response = await _authorizedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/api/v1/search'),
        headers: headers,
        body: jsonEncode(body),
      ),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw MusicServiceException(
        'Search failed: ${response.statusCode}',
      );
    }
  }

  /// Add a video to the queue
  Future<void> addToQueue(String videoId,
      {String insertPosition = 'INSERT_AT_END'}) async {
    await _post('/api/v1/queue',
        body: {'videoId': videoId, 'insertPosition': insertPosition});
  }

  /// Play a video immediately
  Future<void> playNow(String videoId) async {
    // 1. Get current queue to find the current playing index
    int currentIndex = -1;
    try {
      final queue = await getQueue();
      if (queue != null && queue['items'] is List) {
        final items = queue['items'] as List;
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          if (item is Map) {
            final wrapperRenderer = item['playlistPanelVideoWrapperRenderer'];
            final primaryRenderer = (wrapperRenderer is Map && wrapperRenderer['primaryRenderer'] is Map)
                ? (wrapperRenderer['primaryRenderer'] as Map)['playlistPanelVideoRenderer']
                : null;
            final renderer = item['playlistPanelVideoRenderer'] ?? primaryRenderer;
            if (renderer is Map && renderer['selected'] == true) {
              currentIndex = i;
              break;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Add song after current position
    await addToQueue(videoId, insertPosition: 'INSERT_AFTER_CURRENT_VIDEO');
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Jump directly to the new song's index
    if (currentIndex >= 0) {
      await setQueueIndex(currentIndex + 1);
    } else {
      // Fallback: use next if we couldn't determine the index
      await sendControl('next');
    }
  }

  /// Set queue index to play a specific position in the queue
  Future<void> setQueueIndex(int index) async {
    await _authorizedRequest(
      (headers) => http.patch(
        Uri.parse('$_baseUrl/api/v1/queue'),
        headers: headers,
        body: jsonEncode({'index': index}),
      ),
    ).timeout(const Duration(seconds: 5));
  }

  /// Cleanup WebSocket connection
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _stopProgress();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _statusController?.close();
  }
}
