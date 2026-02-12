import 'package:flutter/material.dart';
import '../../domain/entities/app_theme.dart';

/// Theme configuration helper
class ThemeConfig {
  final AppTheme theme;

  const ThemeConfig(this.theme);

  /// Background gradient colors
  List<Color> get backgroundGradient {
    switch (theme) {
      case AppTheme.light:
        return [
          Color(0xFFF5F7FA),
          Color(0xFFE8EAF6),
          Color(0xFFD1C4E9),
          Color(0xFFB39DDB),
        ];
      case AppTheme.dark:
        return [
          Color(0xFF121212),
          Color(0xFF1E1E1E),
          Color(0xFF2C2C2C),
          Color(0xFF1A1A1A),
        ];
      case AppTheme.cosmic:
        return [
          Color(0xFF0A0E27),
          Color(0xFF1A1535),
          Color(0xFF2D1B4E),
          Color(0xFF1A0B2E),
        ];
    }
  }

  /// Primary accent color
  Color get primaryColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFF5E35B1); // Deep Purple
      case AppTheme.dark:
        return Color(0xFF00E5FF); // Cyan
      case AppTheme.cosmic:
        return Color(0xFF00F5FF); // Bright Cyan
    }
  }

  /// Secondary accent color
  Color get secondaryColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFFAB47BC); // Purple
      case AppTheme.dark:
        return Color(0xFFB388FF); // Light Purple
      case AppTheme.cosmic:
        return Color(0xFF7B2BFF); // Purple
    }
  }

  /// Tertiary accent color
  Color get tertiaryColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFFEC407A); // Pink
      case AppTheme.dark:
        return Color(0xFFFF4081); // Light Pink
      case AppTheme.cosmic:
        return Color(0xFFFF0080); // Hot Pink
    }
  }

  /// Text primary color
  Color get textPrimaryColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFF212121); // Almost Black
      case AppTheme.dark:
        return Color(0xFFFFFFFF); // White
      case AppTheme.cosmic:
        return Color(0xFFFFFFFF); // White
    }
  }

  /// Text secondary color
  Color get textSecondaryColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFF757575); // Gray
      case AppTheme.dark:
        return Color(0xFFB0B0B0); // Light Gray
      case AppTheme.cosmic:
        return Colors.white.withValues(alpha: 0.7);
    }
  }

  /// Card/Container background
  Color get cardColor {
    switch (theme) {
      case AppTheme.light:
        return Colors.white.withValues(alpha: 0.9);
      case AppTheme.dark:
        return Colors.white.withValues(alpha: 0.05);
      case AppTheme.cosmic:
        return Colors.white.withValues(alpha: 0.05);
    }
  }

  /// Card border color
  Color get cardBorderColor {
    switch (theme) {
      case AppTheme.light:
        return Color(0xFF5E35B1).withValues(alpha: 0.2);
      case AppTheme.dark:
        return Color(0xFF00E5FF).withValues(alpha: 0.3);
      case AppTheme.cosmic:
        return Color(0xFF00F5FF).withValues(alpha: 0.2);
    }
  }

  /// Whether to use album art blur background
  bool get useAlbumArtBlur {
    switch (theme) {
      case AppTheme.light:
        return false; // Light theme looks better without blur
      case AppTheme.dark:
        return true;
      case AppTheme.cosmic:
        return true;
    }
  }

  /// Cosmic orbs visibility
  bool get showCosmicOrbs {
    return theme == AppTheme.cosmic;
  }

  /// Progress bar gradient
  List<Color> get progressGradient {
    switch (theme) {
      case AppTheme.light:
        return [
          Color(0xFF5E35B1),
          Color(0xFFAB47BC),
          Color(0xFFEC407A),
        ];
      case AppTheme.dark:
        return [
          Color(0xFF00E5FF),
          Color(0xFFB388FF),
          Color(0xFFFF4081),
        ];
      case AppTheme.cosmic:
        return [
          Color(0xFF00F5FF),
          Color(0xFF7B2BFF),
          Color(0xFFFF0080),
        ];
    }
  }
}
