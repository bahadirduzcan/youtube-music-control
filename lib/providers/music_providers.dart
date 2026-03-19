import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/media_status_model.dart';
import '../data/services/music_api_service.dart';
import '../data/services/settings_service.dart';
import '../domain/entities/connection_config.dart';
import '../domain/entities/app_theme.dart';

// Locale provider
final localeProvider = StateProvider<Locale?>((ref) => null);

// SharedPreferences provider (async initialization)
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Settings service provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.when(
    data: (prefs) => SettingsService(prefs),
    loading: () => throw StateError('SharedPreferences not yet initialized'),
    error: (err, stack) => throw StateError('SharedPreferences failed: $err'),
  );
});

// Theme provider (with initial value from shared preferences)
final themeProvider = StateProvider<AppTheme>((ref) {
  // Default to cosmic theme, will be updated after SharedPreferences loads
  return AppTheme.cosmic;
});

// Persisted config provider (loads from SharedPreferences)
final persistedConfigProvider = FutureProvider<ConnectionConfig>((ref) async {
  final service = ref.watch(settingsServiceProvider);
  return await service.loadConfig();
});

// Runtime mutable config provider (for live updates)
final runtimeConfigProvider = StateProvider<ConnectionConfig?>((ref) => null);

// Configuration provider (can be updated dynamically)
// Now uses persistent storage instead of hardcoded values
final musicConfigProvider =
    Provider<({String host, int port, String authId})>((ref) {
  // First check runtime config (updated when user saves settings)
  final runtimeConfig = ref.watch(runtimeConfigProvider);
  if (runtimeConfig != null) {
    return runtimeConfig.toRecord();
  }

  // Otherwise use persisted config from SharedPreferences
  final persistedAsync = ref.watch(persistedConfigProvider);
  return persistedAsync.when(
    data: (config) => config.toRecord(),
    loading: () => ConnectionConfig.defaults().toRecord(),
    error: (_, __) => ConnectionConfig.defaults().toRecord(),
  );
});

// API Service instance provider
final musicApiServiceProvider = Provider<MusicApiService>((ref) {
  final config = ref.watch(musicConfigProvider);
  final service = MusicApiService(
    host: config.host,
    port: config.port,
    authId: config.authId,
  );

  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// Real-time status stream provider
final statusStreamProvider = StreamProvider<MediaStatusModel>((ref) {
  final service = ref.watch(musicApiServiceProvider);
  return service.statusStream();
});

// One-time status fetch provider
final statusProvider = FutureProvider<MediaStatusModel>((ref) async {
  final service = ref.watch(musicApiServiceProvider);
  return service.getStatus();
});

// Local volume state (0-100)
final volumeProvider = StateProvider<double>((ref) => 25);

// Control command provider - executes command and refreshes status
// Uses ref.read to prevent phantom re-execution on provider rebuild
final controlProvider =
    FutureProvider.family<void, String>((ref, action) async {
  final service = ref.read(musicApiServiceProvider);
  await service.sendControl(action);
});

// Sleep timer state
class SleepTimerState {
  final DateTime? endTime;
  const SleepTimerState({this.endTime});

  bool get isActive => endTime != null && DateTime.now().isBefore(endTime!);

  Duration get remaining {
    if (!isActive) return Duration.zero;
    final diff = endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final Ref ref;
  Timer? _fireTimer;
  Timer? _tickTimer;

  SleepTimerNotifier(this.ref) : super(const SleepTimerState());

  void start(Duration duration) {
    cancel();
    final end = DateTime.now().add(duration);
    state = SleepTimerState(endTime: end);

    _fireTimer = Timer(duration, _onTimerFired);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_fireTimer == null) return; // already cancelled/fired
      state = SleepTimerState(endTime: end);
    });
  }

  void cancel() {
    _fireTimer?.cancel();
    _fireTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
    state = const SleepTimerState();
  }

  void _onTimerFired() async {
    // Retry up to 3 times to ensure pause is delivered
    for (int i = 0; i < 3; i++) {
      try {
        await ref.read(musicApiServiceProvider).sendControl('pause');
        break;
      } catch (_) {
        if (i < 2) await Future.delayed(const Duration(seconds: 1));
      }
    }
    cancel();
  }

  @override
  void dispose() {
    _fireTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});
