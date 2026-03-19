import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/services/settings_service.dart';
import 'domain/entities/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'providers/music_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      if (!mounted) return;
      final settings = SettingsService(prefs);
      final savedTheme = settings.loadTheme();
      ref.read(themeProvider.notifier).state = savedTheme;
      final savedLocale = settings.loadLocale();
      if (savedLocale != null) {
        ref.read(localeProvider.notifier).state = savedLocale;
      }
    } catch (e) {
      debugPrint('Preferences loading failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);
    final isDark = currentTheme != AppTheme.light;

    final Color seedColor;
    switch (currentTheme) {
      case AppTheme.light:
        seedColor = const Color(0xFF5E35B1);
      case AppTheme.dark:
        seedColor = const Color(0xFF00E5FF);
      case AppTheme.cosmic:
        seedColor = const Color(0xFF00F5FF);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YT Music Control',
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
