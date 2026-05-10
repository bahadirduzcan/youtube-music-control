// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get nowPlaying => 'Şimdi Çalıyor';

  @override
  String get connectionLost => 'Bağlantı Kesildi';

  @override
  String get checkConnection => 'WiFi ve API sunucusunu kontrol edin';

  @override
  String get reconnect => 'YENİDEN BAĞLAN';

  @override
  String get connecting => 'Bağlanıyor...';

  @override
  String get settings => 'Ayarlar';

  @override
  String get volume => 'Ses';

  @override
  String get queue => 'Sıra';

  @override
  String get queueEmpty => 'Sıra boş';

  @override
  String get queueError => 'Sıra yüklenemedi';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get sleepTimer => 'Uyku Zamanlayıcısı';

  @override
  String get sleepTimerActive => 'Müzik otomatik olarak duracak';

  @override
  String get cancelTimer => 'Zamanlayıcıyı İptal Et';

  @override
  String get minutes => 'Dakika';

  @override
  String get start => 'Başlat';

  @override
  String get saveSettings => 'AYARLARI KAYDET';

  @override
  String get settingsSaved => 'Ayarlar başarıyla kaydedildi';

  @override
  String get host => 'Sunucu / IP Adresi';

  @override
  String get port => 'Port';

  @override
  String get authId => 'Auth ID';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Açık';

  @override
  String get themeDark => 'Koyu';

  @override
  String get themeCosmic => 'Kozmik';

  @override
  String get language => 'Dil';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Türkçe';

  @override
  String get search => 'Ara';

  @override
  String get searchHint => 'Şarkı ara...';

  @override
  String get searchEmpty => 'Sonuç bulunamadı';

  @override
  String get addToQueue => 'Sıraya ekle';

  @override
  String get addedToQueue => 'Sıraya eklendi';

  @override
  String get share => 'Paylaş';

  @override
  String shareText(String title, String artist) {
    return '$title - $artist dinliyorum 🎵';
  }

  @override
  String get shareStory => 'Story Olarak Paylaş';

  @override
  String get storyPreview => 'Story Önizleme';

  @override
  String get infoTip =>
      'Bilgisayarınızda YouTube Music Control sunucusunun çalıştığından emin olun.';

  @override
  String get listeningOn => 'Dinleniyor';

  @override
  String get invalidPort => 'Geçersiz port numarası';

  @override
  String get enterValidHost => 'Geçerli bir IP adresi veya hostname girin';

  @override
  String get enterValidPort => 'Geçerli bir port girin (1-65535)';

  @override
  String get enterAuthId => 'Auth ID girin';

  @override
  String get rawData => 'Ham Veri';

  @override
  String get upNext => 'Sıradaki';

  @override
  String get playing => 'Çalınıyor';
}
