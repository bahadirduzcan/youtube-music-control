/// Form validation utilities for connection settings
class ConnectionValidators {
  ConnectionValidators._();

  /// Validates IPv4 address or hostname
  /// Returns error message if invalid, null if valid
  static String? validateHost(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Host is required';
    }

    final trimmed = value.trim();

    // IPv4 validation: x.x.x.x where x is 0-255
    final ipv4Regex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

    if (ipv4Regex.hasMatch(trimmed)) {
      final parts = trimmed.split('.');
      for (final part in parts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) {
          return 'Invalid IP address (0-255 range)';
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

    return 'Enter a valid IP address or hostname';
  }

  /// Validates port number (1-65535)
  /// Returns error message if invalid, null if valid
  static String? validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Port is required';
    }

    final port = int.tryParse(value.trim());

    if (port == null) {
      return 'Port must be a number';
    }

    if (port < 1 || port > 65535) {
      return 'Port must be between 1-65535';
    }

    return null; // Valid port
  }

  /// Validates auth ID (non-empty, minimum 3 characters)
  /// Returns error message if invalid, null if valid
  static String? validateAuthId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Auth ID is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return 'Auth ID must be at least 3 characters';
    }

    return null; // Valid auth ID
  }
}
