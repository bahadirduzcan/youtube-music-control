import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/connection_config.dart';
import '../../domain/entities/app_theme.dart';

/// Service for persisting and loading connection settings
class SettingsService {
  // SharedPreferences keys
  static const String _keyHost = 'connection_host';
  static const String _keyPort = 'connection_port';
  static const String _keyAuthId = 'connection_auth_id';
  static const String _keyTheme = 'app_theme';
  static const String _keyLocale = 'app_locale';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  /// Load connection configuration from SharedPreferences
  /// Returns default values if not yet saved or on any read error
  Future<ConnectionConfig> loadConfig() async {
    try {
      final host = _prefs.getString(_keyHost);
      final resolvedHost = (host != null && host.isNotEmpty) ? host : ConnectionConfig.defaultHost;

      int port;
      try {
        port = _prefs.getInt(_keyPort) ?? ConnectionConfig.defaultPort;
      } catch (_) {
        port = ConnectionConfig.defaultPort;
      }

      final authId = _prefs.getString(_keyAuthId);
      final resolvedAuthId = (authId != null && authId.isNotEmpty) ? authId : ConnectionConfig.defaultAuthId;

      return ConnectionConfig(
        host: resolvedHost,
        port: port,
        authId: resolvedAuthId,
      );
    } catch (_) {
      return ConnectionConfig.defaults();
    }
  }

  /// Save connection configuration to SharedPreferences
  Future<void> saveConfig(ConnectionConfig config) async {
    await Future.wait([
      _prefs.setString(_keyHost, config.host),
      _prefs.setInt(_keyPort, config.port),
      _prefs.setString(_keyAuthId, config.authId),
    ]);
  }

  /// Load app theme preference
  AppTheme loadTheme() {
    try {
      final themeIndex = _prefs.getInt(_keyTheme) ?? AppTheme.cosmic.index;
      if (themeIndex < 0 || themeIndex >= AppTheme.values.length) {
        return AppTheme.cosmic;
      }
      return AppTheme.values[themeIndex];
    } catch (_) {
      return AppTheme.cosmic;
    }
  }

  /// Save app theme preference
  Future<void> saveTheme(AppTheme theme) async {
    await _prefs.setInt(_keyTheme, theme.index);
  }

  /// Load locale preference
  Locale? loadLocale() {
    try {
      final code = _prefs.getString(_keyLocale);
      if (code != null && code.isNotEmpty) {
        return Locale(code);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Save locale preference
  Future<void> saveLocale(String languageCode) async {
    await _prefs.setString(_keyLocale, languageCode);
  }

  /// Clear all saved settings (for testing or reset)
  Future<void> clearConfig() async {
    await Future.wait([
      _prefs.remove(_keyHost),
      _prefs.remove(_keyPort),
      _prefs.remove(_keyAuthId),
      _prefs.remove(_keyTheme),
      _prefs.remove(_keyLocale),
    ]);
  }
}
