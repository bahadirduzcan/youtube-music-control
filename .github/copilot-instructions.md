# Project goal

Build a Flutter mobile app that controls and displays playback info from the YouTube Music Windows app, via a local Windows companion service.

# Architecture

- Flutter app (Android) connects to the companion over LAN (same Wi-Fi) using HTTP for commands and WebSocket for real-time status.
- Companion service runs on Windows, reads media info and playback position from GlobalSystemMediaTransportControls (GSMTC).
- Secure requests with a shared API key header: `X-Api-Key`.

# Flutter app guidelines

- Use clean architecture: `data`, `domain`, `presentation` layers.
- Use a simple state manager (Riverpod or Bloc). Prefer Riverpod.
- UI shows: track title, artist, album art, playback status, elapsed seconds, total duration, and progress bar.
- Provide buttons: play/pause, next, previous, stop.
- Handle offline states gracefully (reconnect with backoff).

# Windows companion guidelines

- Use .NET (C#) minimal API for HTTP + WebSocket.
- Expose endpoints:
  - `GET /status` -> current track, artist, album, duration, position, state
  - `POST /control` with action: play, pause, toggle, next, prev, stop
- Publish status updates over WebSocket `ws://<host>:8765/ws` every 500ms or on change.
- Use JSON with stable schema; include `positionMs` and `durationMs`.
- Implement API key check middleware for all endpoints.

# Quality

- Keep files small and focused; avoid giant widgets/classes.
- Add lightweight logging for connection and control actions.
- Include basic unit tests for JSON parsing and state reducers.
