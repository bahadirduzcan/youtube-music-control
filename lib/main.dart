import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/screens/home_screen.dart';
import 'providers/music_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Load theme from settings after app starts
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      // Wait for SharedPreferences to be ready
      await ref.read(sharedPreferencesProvider.future);

      // Load saved theme
      final settings = ref.read(settingsServiceProvider);
      final savedTheme = settings.loadTheme();

      // Update theme provider
      ref.read(themeProvider.notifier).state = savedTheme;
    } catch (e) {
      // If loading fails, keep default cosmic theme
      print('Failed to load theme: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YT Music Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
