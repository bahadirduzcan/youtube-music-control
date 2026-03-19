# YouTube Music Control

> **Android cihazınızdan YouTube Music'i yerel ağ üzerinden kontrol edin**

[![App Screenshot](https://i.hizliresim.com/5o9vwdk.jpeg)](https://hizliresim.com/5o9vwdk)

[Pear Desktop](https://github.com/pear-devs/pear-desktop) (HTTP API destekli YouTube Music masaüstü istemcisi) ile çalışan Flutter tabanlı uzaktan kumanda uygulaması. Telefonunuzdan şarkı değiştirin, arama yapın, sırayı görüntüleyin ve daha fazlasını yapın.

## Özellikler

- **Çalma Kontrolleri** – Oynat, duraklat, ileri, geri, karıştır, tekrarla
- **Ses Kontrolü** – Uzaktan ses seviyesi ayarlama
- **Şarkı Arama** – Debounce destekli arama ve doğrudan çalma
- **Sıra Yönetimi** – Çalma sırasını görüntüleme ve şarkı seçme
- **Beğen/Beğenme** – Şarkıları like/dislike yapma
- **Uyku Zamanlayıcısı** – Belirlenen süre sonunda müziği durdurma
- **Story Paylaşımı** – Dinlediğiniz şarkıyı görsel olarak paylaşma
- **Canlı Durum** – WebSocket ile anlık şarkı bilgisi ve ilerleme çubuğu
- **Temalar** – Açık, Koyu ve Kozmik tema desteği
- **Çoklu Dil** – Türkçe ve İngilizce dil desteği
- **Ayarlar** – Uygulama içinden bağlantı yapılandırması (IP, port, auth)
- **Otomatik Yeniden Bağlanma** – Bağlantı koptuğunda otomatik tekrar deneme

## Mimari

Proje **Clean Architecture** deseniyle yapılandırılmıştır:

```
lib/
├── main.dart
├── data/
│   ├── models/              # JSON serileştirme modelleri
│   │   ├── track_model.dart
│   │   └── media_status_model.dart
│   └── services/
│       ├── music_api_service.dart   # HTTP/WebSocket API istemcisi
│       └── settings_service.dart    # SharedPreferences yönetimi
├── domain/
│   └── entities/            # Saf domain nesneleri
│       ├── track.dart
│       ├── media_status.dart
│       ├── connection_config.dart
│       └── app_theme.dart
├── presentation/
│   ├── screens/
│   │   ├── home_screen.dart          # Ana çalma ekranı
│   │   ├── search_screen.dart        # Şarkı arama
│   │   ├── queue_screen.dart         # Çalma sırası
│   │   ├── settings_screen.dart      # Ayarlar
│   │   └── story_preview_screen.dart # Paylaşım story önizleme
│   ├── widgets/
│   │   ├── animated_gradient_background.dart
│   │   ├── audio_visualizer.dart
│   │   ├── floating_particles.dart
│   │   └── waveform_progress_bar.dart
│   └── utils/
│       ├── theme_config.dart
│       ├── share_helper.dart
│       └── validators.dart
└── providers/
    └── music_providers.dart  # Riverpod state yönetimi
```

## Kurulum

### Gereksinimler

- **Flutter** SDK 3.6.0+
- **Android** 8.0+ cihaz
- **[Pear Desktop](https://github.com/pear-devs/pear-desktop)** Windows'ta kurulu ve çalışır durumda
- Her iki cihaz **aynı Wi-Fi ağında**

### 1. Pear Desktop Kurulumu

1. [Pear Desktop](https://github.com/pear-devs/pear-desktop) uygulamasını indirip kurun
2. Uygulamayı başlatın (varsayılan API portu: `8877`)
3. API'nin çalıştığını doğrulayın:

```bash
curl http://localhost:8877/startPage -H "Authorization: Bearer {authId}"
```

### 2. Windows IP Adresini Bulun

```bash
ipconfig
# "IPv4 Address" satırını bulun (örn: 192.168.1.48)
```

### 3. Flutter Uygulamasını Çalıştırın

```bash
flutter pub get
flutter run
```

Uygulama içindeki **Ayarlar** ekranından IP adresi, port ve auth ID'yi yapılandırabilirsiniz.

## Teknoloji

- **Flutter** 3.6.0+ / Dart
- **Riverpod** – State management
- **WebSocket** – Gerçek zamanlı durum güncellemeleri
- **HTTP** – REST API iletişimi
- **SharedPreferences** – Yerel ayar saklama
- **Google Fonts** – Tipografi (Space Grotesk)
- **share_plus** – Story paylaşımı

## API

Uygulama, Pear Desktop'un REST API'si ile iletişim kurar:

| Endpoint | Yöntem | Açıklama |
|---|---|---|
| `/auth/{authId}` | POST | Token alma |
| `/api/v1/status` | GET | Çalma durumu |
| `/api/v1/control` | POST | Oynat/duraklat/ileri/geri/durdur |
| `/api/v1/volume` | POST | Ses seviyesi ayarlama |
| `/api/v1/search` | GET | Şarkı arama |
| `/api/v1/queue` | GET | Çalma sırası |
| `/api/v1/ws` | WS | Gerçek zamanlı durum |

Tüm istekler `Authorization: Bearer {token}` header'ı ile gönderilir.

## Sorun Giderme

### Bağlantı kurulamıyor

- PC ve telefon aynı ağda mı kontrol edin
- Windows Firewall'da port `8877`'nin açık olduğundan emin olun
- `ipconfig` ile IP adresini doğrulayın
- Pear Desktop'un çalışır durumda olduğunu kontrol edin

### API yanıt vermiyor

- Pear Desktop uygulamasını yeniden başlatın
- Port `8877`'nin başka bir uygulama tarafından kullanılmadığından emin olun

## Lisans

MIT
