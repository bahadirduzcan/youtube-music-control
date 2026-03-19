import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/entities/connection_config.dart';
import '../../domain/entities/app_theme.dart';
import '../../providers/music_providers.dart';
import '../utils/theme_config.dart';
import '../utils/validators.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _authIdController;
  final _customMinutesController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current config
    final config = ref.read(musicConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _authIdController = TextEditingController(text: config.authId);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _authIdController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final port = int.tryParse(_portController.text.trim());
      if (port == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid port number'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
      final newConfig = ConnectionConfig(
        host: _hostController.text.trim(),
        port: port,
        authId: _authIdController.text.trim(),
      );

      // Save to storage
      await ref.read(settingsServiceProvider).saveConfig(newConfig);

      // Update runtime config
      ref.read(runtimeConfigProvider.notifier).state = newConfig;

      // Force reconnection by invalidating providers
      ref.invalidate(musicApiServiceProvider);
      ref.invalidate(statusStreamProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Color(0xFF00F5FF),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final theme = ThemeConfig(currentTheme);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.backgroundGradient,
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(theme),
              Expanded(child: _buildForm(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeConfig theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: theme.textPrimaryColor.withValues(alpha: 0.9)),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 8),
          Icon(Icons.settings, color: theme.primaryColor, size: 24),
          SizedBox(width: 8),
          Text(
            'Settings',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeConfig theme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildGlassCard(theme),
          const SizedBox(height: 24),
          _buildThemePickerCard(theme),
          const SizedBox(height: 24),
          _buildLanguagePickerCard(theme),
          const SizedBox(height: 24),
          _buildSleepTimerCard(theme),
          const SizedBox(height: 24),
          _buildInfoTip(theme),
        ],
      ),
    );
  }

  Widget _buildGlassCard(ThemeConfig theme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor,
                  theme.cardColor.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _hostController,
                  label: 'Host / IP Address',
                  hint: '192.168.1.48',
                  icon: Icons.dns,
                  validator: ConnectionValidators.validateHost,
                  theme: theme,
                ),
                SizedBox(height: 20),
                _buildTextField(
                  controller: _portController,
                  label: 'Port',
                  hint: '8877',
                  icon: Icons.settings_ethernet,
                  keyboardType: TextInputType.number,
                  validator: ConnectionValidators.validatePort,
                  theme: theme,
                ),
                SizedBox(height: 20),
                _buildTextField(
                  controller: _authIdController,
                  label: 'Auth ID',
                  hint: 'bahadir',
                  icon: Icons.key,
                  validator: ConnectionValidators.validateAuthId,
                  theme: theme,
                ),
                SizedBox(height: 32),
                _buildSaveButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemePickerCard(ThemeConfig theme) {
    final currentTheme = ref.watch(themeProvider);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor,
                  theme.cardColor.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_rounded, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Theme',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: AppTheme.values.map((appTheme) {
                    final isSelected = appTheme == currentTheme;
                    final themeConfig = ThemeConfig(appTheme);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () async {
                            ref.read(themeProvider.notifier).state = appTheme;
                            try {
                              await ref.read(settingsServiceProvider).saveTheme(appTheme);
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        themeConfig.primaryColor.withValues(alpha: 0.3),
                                        themeConfig.primaryColor.withValues(alpha: 0.1),
                                      ],
                                    )
                                  : null,
                              color: isSelected ? null : theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? themeConfig.primaryColor
                                    : theme.cardBorderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: themeConfig.progressGradient,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  appTheme.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? themeConfig.primaryColor
                                        : theme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeConfig theme,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.primaryColor, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textPrimaryColor.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.poppins(
            color: theme.textPrimaryColor,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.red.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            errorStyle: GoogleFonts.poppins(
              color: Colors.red.shade300,
              fontSize: 12,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ThemeConfig theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'SAVE SETTINGS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerCard(ThemeConfig theme) {
    final timerState = ref.watch(sleepTimerProvider);
    final isActive = timerState.isActive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.cardColor,
                  theme.cardColor.withValues(alpha: 0.5),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bedtime_rounded,
                        color: theme.primaryColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Sleep Timer',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                    if (isActive) ...[
                      Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 16),
                if (isActive)
                  _buildActiveTimer(timerState, theme)
                else
                  _buildTimerOptions(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTimer(SleepTimerState timerState, ThemeConfig theme) {
    final remaining = timerState.remaining;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final timeStr = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Text(
          timeStr,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Music will pause automatically',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: theme.textSecondaryColor,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ref.read(sleepTimerProvider.notifier).cancel();
            },
            icon: Icon(Icons.close, size: 18),
            label: Text('Cancel Timer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.tertiaryColor,
              side: BorderSide(color: theme.tertiaryColor.withValues(alpha: 0.5)),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerOptions(ThemeConfig theme) {
    const presets = [
      (label: '15m', minutes: 15),
      (label: '30m', minutes: 30),
      (label: '45m', minutes: 45),
      (label: '1h', minutes: 60),
    ];

    return Column(
      children: [
        Row(
          children: presets.map((preset) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(sleepTimerProvider.notifier)
                        .start(Duration(minutes: preset.minutes));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      preset.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.textPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customMinutesController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(
                  color: theme.textPrimaryColor,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Minutes',
                  hintStyle: GoogleFonts.poppins(
                    color: theme.textSecondaryColor,
                  ),
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.primaryColor,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final minutes =
                    int.tryParse(_customMinutesController.text.trim());
                if (minutes != null && minutes > 0) {
                  ref
                      .read(sleepTimerProvider.notifier)
                      .start(Duration(minutes: minutes));
                  _customMinutesController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Start',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguagePickerCard(ThemeConfig theme) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final selectedCode = currentLocale?.languageCode ?? Localizations.localeOf(context).languageCode;

    final languages = [
      (code: 'en', label: l10n.english, flag: '🇬🇧'),
      (code: 'tr', label: l10n.turkish, flag: '🇹🇷'),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.cardColor, theme.cardColor.withValues(alpha: 0.5)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.language, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.language,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: languages.map((lang) {
                    final isSelected = lang.code == selectedCode;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () async {
                            ref.read(localeProvider.notifier).state = Locale(lang.code);
                            try {
                              await ref.read(settingsServiceProvider).saveLocale(lang.code);
                            } catch (_) {}
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.primaryColor.withValues(alpha: 0.2) : theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? theme.primaryColor : theme.cardBorderColor,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(lang.flag, style: TextStyle(fontSize: 24)),
                                const SizedBox(height: 8),
                                Text(
                                  lang.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? theme.primaryColor : theme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTip(ThemeConfig theme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.primaryColor.withValues(alpha: 0.1),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.primaryColor, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Make sure YouTube Music Control server is running on your computer.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
