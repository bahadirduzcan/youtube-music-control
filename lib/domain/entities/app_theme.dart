/// App theme options
enum AppTheme {
  light,
  dark,
  cosmic, // Current beautiful cosmic theme
}

extension AppThemeExtension on AppTheme {
  String get displayName {
    switch (this) {
      case AppTheme.light:
        return 'Aydınlık';
      case AppTheme.dark:
        return 'Koyu';
      case AppTheme.cosmic:
        return 'Kozmik';
    }
  }

  String get description {
    switch (this) {
      case AppTheme.light:
        return 'Açık renkli tema';
      case AppTheme.dark:
        return 'Koyu renkli tema';
      case AppTheme.cosmic:
        return 'Orijinal kozmik tema';
    }
  }
}
