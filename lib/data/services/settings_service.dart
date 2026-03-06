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

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  /// Load connection configuration from SharedPreferences
  /// Returns default values if not yet saved
  Future<ConnectionConfig> loadConfig() async {
    final host = _prefs.getString(_keyHost) ?? ConnectionConfig.defaultHost;
    final port = _prefs.getInt(_keyPort) ?? ConnectionConfig.defaultPort;
    final authId =
        _prefs.getString(_keyAuthId) ?? ConnectionConfig.defaultAuthId;

    return ConnectionConfig(
      host: host,
      port: port,
      authId: authId,
    );
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
    final themeIndex = _prefs.getInt(_keyTheme) ?? AppTheme.cosmic.index;
    if (themeIndex < 0 || themeIndex >= AppTheme.values.length) {
      return AppTheme.cosmic;
    }
    return AppTheme.values[themeIndex];
  }

  /// Save app theme preference
  Future<void> saveTheme(AppTheme theme) async {
    await _prefs.setInt(_keyTheme, theme.index);
  }

  /// Clear all saved settings (for testing or reset)
  Future<void> clearConfig() async {
    await Future.wait([
      _prefs.remove(_keyHost),
      _prefs.remove(_keyPort),
      _prefs.remove(_keyAuthId),
    ]);
  }
}
