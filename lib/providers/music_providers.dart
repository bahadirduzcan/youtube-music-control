import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/media_status_model.dart';
import '../data/services/music_api_service.dart';

// Configuration provider (can be updated dynamically)
final musicConfigProvider =
    StateProvider<({String host, int port, String authId})>((ref) {
  return (
    host: '192.168.1.48', // Update with your PC IP
    port: 8877,
    authId: 'bahadir', // Update with your auth id
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
final controlProvider =
    FutureProvider.family<void, String>((ref, action) async {
  final service = ref.watch(musicApiServiceProvider);
  await service.sendControl(action);
  // Refresh the status stream after sending control
  // This forces the stream to fetch latest data
  await Future.delayed(const Duration(milliseconds: 200));
});
