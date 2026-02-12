/// Form validation utilities for connection settings
class ConnectionValidators {
  ConnectionValidators._();

  /// Validates IPv4 address or hostname
  /// Returns error message if invalid, null if valid
  static String? validateHost(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Host gerekli';
    }

    final trimmed = value.trim();

    // IPv4 validation: x.x.x.x where x is 0-255
    final ipv4Regex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

    if (ipv4Regex.hasMatch(trimmed)) {
      final parts = trimmed.split('.');
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return 'Geçersiz IP adresi (0-255 arası)';
        }
      }
      return null; // Valid IPv4
    }

    // Hostname validation (basic)
    final hostnameRegex =
        RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]{0,61}[a-zA-Z0-9])?$');

    if (hostnameRegex.hasMatch(trimmed)) {
      return null; // Valid hostname
    }

    return 'Geçerli IP adresi veya hostname girin';
  }

  /// Validates port number (1-65535)
  /// Returns error message if invalid, null if valid
  static String? validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Port gerekli';
    }

    final port = int.tryParse(value.trim());

    if (port == null) {
      return 'Port sayı olmalı';
    }

    if (port < 1 || port > 65535) {
      return 'Port 1-65535 arası olmalı';
    }

    return null; // Valid port
  }

  /// Validates auth ID (non-empty, minimum 3 characters)
  /// Returns error message if invalid, null if valid
  static String? validateAuthId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Auth ID gerekli';
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return 'Auth ID en az 3 karakter olmalı';
    }

    return null; // Valid auth ID
  }
}
