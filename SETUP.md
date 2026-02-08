# Setup & Development Guide

## Hızlı Başlangıç

### 1. Windows Companion Service'i Başlat

```bash
cd MusicCompanion
dotnet run
```

- Servis `http://0.0.0.0:8765` adresinde dinler
- Mock playback verileri 500ms'de bir güncellenir

### 2. Flutter Uygulamasını Güncelle

İlk olarak, bilgisayarınızın IP adresini öğrenin:

```bash
ipconfig
```

Windows:

```dart
// lib/providers/music_providers.dart, line 10-15
final musicConfigProvider = StateProvider<({String host, int port, String apiKey})>((ref) {
  return (
    host: '192.168.1.YOUR_IP',  // ← Kendi IP'niz
    port: 8765,
    apiKey: 'test-key-123',  // ← Same in .NET and Flutter
  );
});
```

### 3. Flutter Uygulamasını Çalıştır

```bash
flutter pub get
flutter run
```

## Dosya Açıklamaları

### Flutter - Domain Layer

**Entities**: İş mantığı kurallarının ilgisi olmayan saf veri yapıları.

- [Track](lib/domain/entities/track.dart): Şarkı metadata
- [MediaStatus](lib/domain/entities/media_status.dart): Çalma durumu

### Flutter - Data Layer

**Models**: JSON serileştirmeyle ilişkili versiyonlar.

- [TrackModel](lib/data/models/track_model.dart): JSON ↔ Track dönüşümü
- [MediaStatusModel](lib/data/models/media_status_model.dart): JSON ↔ MediaStatus dönüşümü

**Services**: Dış kaynaklarla iletişim.

- [MusicApiService](lib/data/services/music_api_service.dart):
  - HTTP GET `/status` → `MediaStatusModel`
  - HTTP POST `/control` → action gönder
  - WebSocket bağlantısı ve stream yönetimi
  - Otomatik reconnect (exponential backoff)

### Flutter - Providers (State Management)

Riverpod providers yönetilen state'ler:

- `musicConfigProvider`: Host/port/API key ayarları
- `musicApiServiceProvider`: Singleton API service instance
- `statusStreamProvider`: Real-time status updates (WebSocket)
- `statusProvider`: One-time status fetch (HTTP)
- `controlProvider`: Control komutu gönderme (play/pause/next/etc)

### Flutter - Presentation

[HomeScreen](lib/presentation/screens/home_screen.dart):

- Track bilgisi (başlık, sanatçı, albüm)
- Progress bar (ilerleme / toplam süre)
- Playback durumu (PLAYING/PAUSED/STOPPED)
- Kontrol butonları (play/pause, next, previous, stop)

### .NET - Program.cs

Minimal API konfigürasyonu:

1. **CORS**: Localhost'tan tüm istekleri kabul et
2. **API Key Middleware**: Her isteği `X-Api-Key` header'ı kontrol et
3. **GET /status**: Mevcut çalma durumunu JSON olarak döndür
4. **POST /control**: Aksiyon komutu (`play`, `pause`, `next`, `prev`, `stop`, `toggle`)
5. **WebSocket /ws**: 500ms'de bir status bilgilerini akışla

### .NET - MediaControllerService

Playback kontrol mantığı:

- `GetCurrentStatus()`: Mevcut track, playback state, position bilgisi
- `SendControlAsync()`: Play/pause/next/prev/stop komutları
- `RegisterStatusListener()`: WebSocket callback'i kayıt et
- `UnregisterStatusListener()`: Cleanup

#### Mock vs. Gerçek Implementasyon

**Şu anda (Mock Mode)**:

```csharp
// Sabit veri döndürür
Track = "Example Song" by "Example Artist"
Duration: 4 dakika
Position: Otomatik artış
```

**Gerçek YouTube Music kontrolü (TODO)**:

```csharp
using Windows.Media.Control;

var sessionManager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
var session = sessionManager.GetCurrentSession();
var mediaInfo = await session.TryGetMediaPropertiesAsync();
```

## Bağlantı Akışı

```
Android Device (Flutter)
    ↓ (HTTP/WebSocket)
    ↓ GET /status, POST /control, ws://
    ↓
Windows PC (ASP.NET Core)
    ↓ (Windows Media API)
    ↓ GlobalSystemMediaTransportControls
    ↓
YouTube Music (Windows App)
```

## Security

### API Key'i Güvenli Tutun

> ⚠️ **Üretim ortamında**: API key'i `.env` dosyasında saklayın ya da environment variable olarak set edin.

```csharp
// .NET - Program.cs
var apiKey = Environment.GetEnvironmentVariable("MUSIC_API_KEY") ?? "default-key";
```

```dart
// Flutter - main.dart
const apiKey = String.fromEnvironment('API_KEY', defaultValue: 'default-key');
```

### TLS/HTTPS

Şu anda, HTTP sadece local development için. Gerçek kullanım için HTTPS ekleyin.

## Testing

### Manual Test - cURL

```bash
# 1. GET /status
curl -H "X-Api-Key: test-key-123" http://localhost:8765/status

# 2. POST /control (play)
curl -X POST http://localhost:8765/control \
  -H "X-Api-Key: test-key-123" \
  -H "Content-Type: application/json" \
  -d '{"action":"play"}'

# 3. WebSocket (Powershell)
$ws = New-Object System.Net.WebSockets.ClientWebSocket
$uri = New-Object System.Uri("ws://localhost:8765/ws")
$cts = New-Object System.Threading.CancellationTokenSource
$ws.ConnectAsync($uri, $cts.Token).Wait()

$buffer = New-Object byte[] 1024
while ($true) {
    $result = $ws.ReceiveAsync($buffer, 0, $buffer.Length, $cts.Token)
    $result.Wait()
    $message = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $result.Result.Count)
    $message
}
```

## Hata Ayıklama

### Flutter Logs

```bash
flutter logs
```

### .NET Logs

```csharp
// Program.cs
logger.LogInformation("Message", args...);
logger.LogError(exception, "Error message");
```

### WebSocket Bağlantısı Kontrolü

**Powershell**:

```powershell
Test-NetConnection -ComputerName 192.168.1.X -Port 8765
```

**Terminal (Linux/Mac)**:

```bash
nc -zv 192.168.1.X 8765
```

## GitHub Copilot ile Geliştirme

Bu proje `.github/copilot-instructions.md` içerir. VS Code'da:

1. Copilot Chat'i aç (Ctrl+Shift+I)
2. Kural dosyası otomatik olarak uygulanır
3. İstekler clean architecture + Riverpod şekline uyarlanır

Örnek:

```
/ask Şarkı seçme widgeti ekle
```

Copilot geliştirecek:

- Clean architecture (data/domain/presentation)
- Riverpod providers
- Proper error handling
- UI best practices

## Kaynaklar

- [Flutter Clean Architecture](https://resocoder.com/flutter-clean-architecture-tdd)
- [Riverpod Docs](https://docs.riverpod.dev)
- [ASP.NET Core Minimal APIs](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis)
- [WebSocket in .NET](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/websockets)
