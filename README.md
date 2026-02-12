# YouTube Music Control

APP Screen:

[![ff}](https://i.hizliresim.com/5o9vwdk.jpeg)](https://hizliresim.com/5o9vwdk)

> **Control YouTube Music from your Android device over your local network**

A Flutter-based mobile app that remotely controls YouTube Music playback on Windows by directly communicating with the YouTube Music application API. Control playback, view real-time track info, and manage your music experience seamlessly over LAN.

> **🎵 Works with:** [@pear-devs/pear-desktop](https://github.com/pear-devs/pear-desktop) - A modern YouTube Music desktop client for Windows with built-in HTTP API support.

## 🎯 Features

- ⏯️ **Play/Pause Control** – Start, pause, or resume playback with a single tap
- ⏭️ **Next/Previous Track** – Navigate through your playlist seamlessly
- 🎨 **Real-time Status Updates** – View current track info and progress instantly
- 📊 **Progress Bar** – Visual representation of playback position
- 🎵 **Track Information** – Display title, artist, album, and duration
- 🔒 **Secure Authentication** – Bearer token-based authorization
- 🔄 **Auto-Reconnect** – Graceful handling of network disconnections
- 📱 **LAN-Only** – Works over local Wi-Fi, no internet required
- 🏗️ **Clean Architecture** – Separation of concerns with data, domain, and presentation layers
- 🔌 **Direct API Integration** – No backend server dependency

## 🏛️ Architecture

The project uses **clean architecture pattern** with direct YouTube Music API integration:

```
┌─────────────────────────────────────────┐
│         Flutter Mobile App (Android)    │
│  ┌───────────────────────────────────┐  │
│  │    Presentation Layer (UI)        │  │
│  │  - Screens, Widgets, Controllers  │  │
│  └───────────────────────────────────┘  │
│              ↕️ (HTTP)                   │
│  ┌───────────────────────────────────┐  │
│  │     Domain Layer (Business Logic) │  │
│  │  - Entities, Use Cases, Repos     │  │
│  └───────────────────────────────────┘  │
│              ↕️                          │
│  ┌───────────────────────────────────┐  │
│  │      Data Layer (API Client)      │  │
│  │  - Models, Services, YouTube API  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
         LAN (HTTP + REST API)
         ↕️
┌─────────────────────────────────────────┐
│   YouTube Music Windows Application    │
│  - Active HTTP API Server (Port 8877)  │
│  - Playback Control & Status Endpoint  │
└─────────────────────────────────────────┘
```

## 📦 Project Structure

```
youtube-music-control/
│
├── lib/                                  # Flutter Application
│   ├── main.dart                         # App entry point
│   ├── data/                             # Data Layer
│   │   ├── models/                       # JSON serializable models
│   │   │   ├── track_model.dart          # Track data model
│   │   │   └── media_status_model.dart   # Playback status model
│   │   └── services/                     # YouTube Music API service
│   │       └── music_api_service.dart    # HTTP client to YouTube Music API
│   │
│   ├── domain/                           # Domain Layer (Business Logic)
│   │   ├── entities/                     # Pure domain entities
│   │   │   ├── track.dart                # Track entity
│   │   │   └── media_status.dart         # Media status entity
│   │   └── repositories/                 # Abstract repository interfaces
│   │       └── music_repository.dart     # Repository pattern
│   │
│   ├── presentation/                     # Presentation Layer (UI)
│   │   ├── screens/                      # App screens
│   │   │   └── home_screen.dart          # Main playback control screen
│   │   └── widgets/                      # Reusable UI components
│   │       ├── playback_controls.dart    # Control buttons
│   │       ├── progress_bar.dart         # Progress indicator
│   │       └── track_info_card.dart      # Track information display
│   │
│   └── providers/                        # Riverpod State Management
│       └── music_providers.dart          # State providers & notifiers
│
├── test/                                 # Unit & Widget Tests
│   └── widget_test.dart
│
└── .github/
    └── copilot-instructions.md           # Development guidelines

```

## 🚀 Getting Started

### Prerequisites

- **Flutter**: SDK 3.6.0 or higher
- **Android Device**: Android 8.0 or higher
- **YouTube Music for Windows**: Desktop application installed and running
- **Network**: Both devices on the same Wi-Fi network
- **Local Network Access**: Enabled on both Windows and Android

### Installation

#### 1. YouTube Music Windows Setup

Ensure YouTube Music is installed and has local API enabled:

> **📌 Note:** This app is designed to work with [@pear-devs/pear-desktop](https://github.com/pear-devs/pear-desktop) - a YouTube Music desktop application that provides the required HTTP API endpoints.

1. **Install Pear Desktop (YouTube Music)** from [@pear-devs/pear-desktop](https://github.com/pear-devs/pear-desktop)
2. **Start the application** on Windows
3. **Verify local API access** (should be running on `http://localhost:8877`)

Check if API is accessible:

```bash
curl http://localhost:8877/startPage -H "Authorization: Bearer {authId}"
```

#### 2. Find Your Windows IP Address

Your Android device needs to know your Windows computer's IP:

**Windows:**

```bash
ipconfig
# Look for "IPv4 Address" under your network adapter (e.g., 192.168.1.48)
```

**Mac/Linux:**

```bash
ifconfig
# Look for inet (IPv4) address
```

#### 3. Flutter App Configuration

Update the configuration in [lib/providers/music_providers.dart](lib/providers/music_providers.dart):

```dart
final musicConfigProvider = StateProvider<({String host, int port, String authId})>((ref) {
  return (
    host: '192.168.1.48',       // ← Replace with your Windows IP
    port: 8877,                  // ← YouTube Music API port
    authId: 'bahadir',           // ← Your auth identifier
  );
});
```

Install Flutter dependencies:

```bash
flutter pub get
```

#### 4. Running the Flutter App

```bash
flutter run
```

Or for a specific device:

```bash
flutter run -d <device_id>
```

## 📡 YouTube Music API

The app communicates directly with YouTube Music's REST API endpoints.

### Supported Endpoints

#### Get Current Playback Status

```http
GET /playback
Host: 192.168.1.48:8877
Authorization: Bearer bahadir
```

**Response:**

```json
{
  "title": "Song Title",
  "artist": "Artist Name",
  "album": "Album Name",
  "duration": 180000,
  "position": 45000,
  "isPlaying": true,
  "albumArt": "..."
}
```

#### Control Playback

```http
POST /playback/control
Host: 192.168.1.48:8877
Authorization: Bearer bahadir
Content-Type: application/json

{
  "action": "play|pause|toggle|next|prev|stop"
}
```

**Actions:**

- `play` – Resume playback
- `pause` – Pause playback
- `toggle` – Toggle between play and pause
- `next` – Skip to next track
- `prev` – Go to previous track
- `stop` – Stop playback

**Response:**

```json
{
  "success": true,
  "message": "Action executed"
}
```

## 🛠️ Development

### Tech Stack

**Flutter App:**

- **Framework**: Flutter 3.6.0+
- **State Management**: Riverpod 2.x
- **Architecture**: Clean Architecture (Data, Domain, Presentation layers)
- **HTTP Client**: Built-in `dart:io` and `http` package
- **JSON Serialization**: `json_serializable`

**Backend:**

- **YouTube Music REST API** (HTTP)
- **Local Network Communication** (LAN)
- **No external server required**

### Code Structure

**Data Layer** (`lib/data/`)

- Implements repository interfaces
- Handles API calls and WebSocket communication
- JSON model serialization/deserialization
- Manages connection lifecycle

**Domain Layer** (`lib/domain/`)

- Pure business logic entities
- Repository abstract interfaces
- No framework dependencies

**Presentation Layer** (`lib/presentation/`)

- Stateless/Stateful widgets
- Screen-level organization
- Reusable UI components
- State consumption through providers

**State Management** (`lib/providers/`)

```dart
// Example: Music status provider
final musicStatusProvider = StreamProvider<MediaStatus>((ref) async* {
  // Real-time updates via WebSocket
});

// Example: Configuration provider
final musicConfigProvider = StateProvider<MusicConfig>((ref) {
  // Mutable configuration
});
```

### Running Tests

Unit tests:

```bash
flutter test
```

Widget tests:

```bash
flutter test -d linux  # or android, ios
```

### Building for Release

**Android APK:**

```bash
flutter build apk --release
```

**Android App Bundle:**

```bash
flutter build appbundle --release
```

## 🧪 Testing

The project includes example tests. To run tests:

```bash
flutter test
```

Test coverage can be generated with:

```bash
flutter test --coverage
```

### Manual Testing Steps

1. **Start YouTube Music on Windows:**
   - Ensure the desktop app is running and playing or ready to play

2. **Verify API is accessible:**

   ```bash
   curl http://localhost:8877/startPage -H "Authorization: Bearer bahadir"
   ```

3. **Run the Flutter app:**

   ```bash
   flutter run
   ```

4. **Test controls in the Flutter app:**
   - Verify play/pause works
   - Check next/previous buttons
   - Monitor real-time status updates
   - Observe progress bar accuracy
   - Test with different songs

## 🔧 Troubleshooting

### "Connection refused" Error

**Problem:** Flutter app cannot connect to YouTube Music API

**Solutions:**

- Verify YouTube Music is running on Windows
- Check if API is accessible: `curl http://localhost:8877/startPage`
- Confirm correct IP address in `music_providers.dart`
- Ensure both devices are on the same Wi-Fi network
- Check Windows Firewall: Allow port 8877 for YouTube Music
- Restart YouTube Music app

### "Invalid Authorization"

**Problem:** 401 Unauthorized response from API

**Solution:**

- Verify `authId` in Flutter matches your setup
- Check header format: `Authorization: Bearer {authId}`
- Restart both app and YouTube Music

### Network Not Reachable

**Problem:** Cannot reach Windows from Android device

**Solutions:**

- Check Wi-Fi signal strength
- Verify network latency: `ping <windows_ip>` from Android
- Ensure Windows and Android are on same network (not guest network)
- Disable VPN if active
- Check if IP has changed (run `ipconfig` again)

### API Not Responding

**Problem:** Timeout or no response from YouTube Music API

**Solutions:**

- Ensure YouTube Music is fully loaded and visible
- Check if port 8877 is actually in use
- Restart YouTube Music Windows application
- Verify no other app is using port 8877
- Check system logs for permission issues

## 📚 Documentation

- [SETUP.md](SETUP.md) – Detailed development guide
- [SUMMARY.md](SUMMARY.md) – Project completion status and next steps
- [copilot-instructions.md](.github/copilot-instructions.md) – AI assistant guidelines

## 🔒 Security

All requests to the YouTube Music API use Bearer token authentication:

- Authorization header format: `Authorization: Bearer {authId}`
- No sensitive data is logged
- All communication over local network only
- No external service access required

**Best Practices:**

```dart
// ✅ Secure: Use environment variables
const authId = String.fromEnvironment('YOUTUBE_MUSIC_AUTH_ID');

// ✅ Good: Configuration file (not committed to git)
const authId = 'your-auth-id';  // In .env or config file

// ❌ Insecure: Hardcoded in source control
const authId = 'hardcoded-secret';  // Never do this
```

**Recommendations:**

- Keep `authId` in local configuration, not version control
- Use `.env` files for development
- Store sensitive config separately per environment
- Regularly update `authId` for security

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** following the code style
4. **Commit with clear messages**: `git commit -m 'Add: amazing feature'`
5. **Push to branch**: `git push origin feature/amazing-feature`
6. **Open a Pull Request** with description of changes

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` for formatting
- Run `dart analyze` before committing
- Keep functions small and focused
- Write meaningful commit messages

### Before Submitting PR

```bash
# Format code
dart format .

# Analyze for issues
dart analyze

# Run tests
flutter test

# Build for check
flutter build apk --analyze-size
```

## 📝 Commit Message Convention

```
type: subject

body (optional)

footer (optional)
```

**Types:**

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Code style
- `refactor:` Code refactoring
- `perf:` Performance improvement
- `test:` Adding tests

**Example:**

```
feat: Add volume control to playback UI

Implement volume up/down buttons and display current volume level.
Integrate with Windows Media Transport Controls API.

Closes #42
```

## 📄 License

This project is licensed under the MIT License – see [LICENSE](LICENSE) file for details.

## 💡 Future Enhancements

- [ ] Volume control integration
- [ ] Queue management from mobile
- [ ] Album art caching and display
- [ ] Search functionality
- [ ] Playlist creation and management
- [ ] Thumb up/down rating
- [ ] Custom UI themes (light/dark mode)
- [ ] Keyboard shortcut support
- [ ] iOS support
- [ ] Multi-device queue support
- [ ] Repeat and shuffle modes
- [ ] Track history sync

## 🙏 Acknowledgments

- Flutter community for excellent documentation
- Microsoft for Global System Media Transport Controls API
- The open-source community for amazing packages

## 📞 Support

For issues, questions, or suggestions:

- Open an [Issue](../../issues)
- Check existing documentation in [SETUP.md](SETUP.md)
- Review [Troubleshooting](#-troubleshooting) section
- Check Windows Event Viewer for service logs

---

**Last Updated:** February 2026  
**Status:** Active Development  
**Maintainer:** YouTube Music Control Team

```dart
host: '192.168.1.X', // Bilgisayarınızın IP adresi
port: 8765,
apiKey: 'your-api-key-here',
```

4. **Android cihazda çalıştır**:
   ```bash
   flutter run
   ```

### Windows Companion Service

1. **.NET projesini build et**:

   ```bash
   cd MusicCompanion
   dotnet build
   ```

2. **API Key'i ayarla** ([MusicCompanion/Program.cs](MusicCompanion/Program.cs#L18)):

   ```csharp
   const string ApiKey = "your-api-key-here"; // Flutter uygulamasıyla aynı olmalı
   ```

3. **Service'i başlat**:

   ```bash
   dotnet run
   ```

   - Service şu anda mock playback bilgileri verir (test amaçlı)
   - Gerçek YouTube Music kontrolü için [MediaControllerService.cs](MusicCompanion/Services/MediaControllerService.cs)'yi GSMTC (GlobalSystemMediaTransportControls) ile güncelle

## API Endpoint'leri

### GET /status

```bash
curl -H "X-Api-Key: your-api-key-here" http://localhost:8765/status
```

**Yanıt**:

```json
{
  "track": {
    "title": "Song Title",
    "artist": "Artist Name",
    "album": "Album Name",
    "albumArtUrl": null,
    "durationMs": 240000
  },
  "state": "playing",
  "positionMs": 120000
}
```

### POST /control

```bash
curl -X POST http://localhost:8765/control \
  -H "X-Api-Key: your-api-key-here" \
  -H "Content-Type: application/json" \
  -d '{"action": "play"}'
```

**Desteklenen komutlar**: `play`, `pause`, `toggle`, `next`, `prev`, `stop`

### WebSocket /ws

```javascript
const ws = new WebSocket("ws://localhost:8765/ws");
ws.onmessage = (event) => {
  const status = JSON.parse(event.data);
  console.log(status);
};
```

## GitHub Copilot Custom Instructions

Bu proje [.github/copilot-instructions.md](.github/copilot-instructions.md) dosyası içerir:

- Clean architecture yönergeleri
- Riverpod state management kuralları
- .NET minimal API best practices
- Kalite standartları

VS Code'da Copilot Chat açıldığında bu kurallar otomatik olarak uygulanır.

## Geliştirme Notları

### Mock vs. Gerçek GSMTC Implementasyonu

Şu anda `MediaControllerService` mock mod'da çalışıyor (test amaçlı). Gerçek YouTube Music kontrolü için:

1. Windows NuGet paketlerine erişim sağla
2. [MediaControllerService.cs](MusicCompanion/Services/MediaControllerService.cs)'yi aşağıdakiyle güncelle:

   ```csharp
   using Windows.Media.Control;

   var sessionManager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
   var session = sessionManager.GetCurrentSession();
   ```

### Logging

- **Flutter**: `logger` paketi (`lib/data/services/music_api_service.dart`)
- **.NET**: Built-in `ILogger<T>` kullanıyor

### Test

```bash
# Flutter unit tests
flutter test

# .NET unit tests
cd MusicCompanion
dotnet test
```

## Troubleshooting

### Bağlantı bulunamıyor

- PC ve telefon aynı ağda mı?
- Firewall port 8765'i açıyor mu?
- Host IP adresi doğru mu? (`ipconfig` komutunda IPv4 adresini kontrol et)

### API Key'i yanlış

- `flutter` ve `.NET` projelerinde aynı `apiKey` kullanıyorsun?

### WebSocket bağlantısı kopuyor

- Flutter uygulaması otomatik olarak 2 saniye sonra yeniden bağlanır
- `.NET` service çalışıyor mu? (`http://host:8765/status` test et)

## Lisans

MIT

## Kaynaklar

- [Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd)
- [Riverpod Documentation](https://riverpod.dev)
- [ASP.NET Core Minimal APIs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis)
- [Windows GSMTC API](https://learn.microsoft.com/en-us/uwp/api/windows.media.control)
