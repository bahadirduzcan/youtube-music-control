// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get connectionLost => 'Connection Lost';

  @override
  String get checkConnection => 'Check WiFi and API server';

  @override
  String get reconnect => 'RECONNECT';

  @override
  String get connecting => 'Connecting...';

  @override
  String get settings => 'Settings';

  @override
  String get volume => 'Volume';

  @override
  String get queue => 'Queue';

  @override
  String get queueEmpty => 'Queue is empty';

  @override
  String get queueError => 'Failed to load queue';

  @override
  String get retry => 'Retry';

  @override
  String get sleepTimer => 'Sleep Timer';

  @override
  String get sleepTimerActive => 'Music will pause automatically';

  @override
  String get cancelTimer => 'Cancel Timer';

  @override
  String get minutes => 'Minutes';

  @override
  String get start => 'Start';

  @override
  String get saveSettings => 'SAVE SETTINGS';

  @override
  String get settingsSaved => 'Settings saved successfully';

  @override
  String get host => 'Host / IP Address';

  @override
  String get port => 'Port';

  @override
  String get authId => 'Auth ID';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeCosmic => 'Cosmic';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Türkçe';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search for songs...';

  @override
  String get searchEmpty => 'No results found';

  @override
  String get addToQueue => 'Add to queue';

  @override
  String get addedToQueue => 'Added to queue';

  @override
  String get share => 'Share';

  @override
  String shareText(String title, String artist) {
    return 'Listening to $title by $artist 🎵';
  }

  @override
  String get shareStory => 'Share as Story';

  @override
  String get storyPreview => 'Story Preview';

  @override
  String get infoTip =>
      'Make sure YouTube Music Control server is running on your computer.';

  @override
  String get listeningOn => 'Listening on';

  @override
  String get invalidPort => 'Invalid port number';

  @override
  String get enterValidHost => 'Enter a valid IP address or hostname';

  @override
  String get enterValidPort => 'Enter a valid port (1-65535)';

  @override
  String get enterAuthId => 'Enter Auth ID';

  @override
  String get rawData => 'Raw Data';

  @override
  String get upNext => 'Up Next';

  @override
  String get playing => 'Playing';
}
