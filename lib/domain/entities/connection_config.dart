class ConnectionConfig {
  final String host;
  final int port;
  final String authId;

  const ConnectionConfig({
    required this.host,
    required this.port,
    required this.authId,
  });

  // Default values (matching current hardcoded values)
  static const defaultHost = '192.168.1.48';
  static const defaultPort = 8877;
  static const defaultAuthId = 'bahadir';

  /// Factory constructor for default configuration
  factory ConnectionConfig.defaults() => const ConnectionConfig(
        host: defaultHost,
        port: defaultPort,
        authId: defaultAuthId,
      );

  /// Copy with method for immutable updates
  ConnectionConfig copyWith({
    String? host,
    int? port,
    String? authId,
  }) =>
      ConnectionConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        authId: authId ?? this.authId,
      );

  /// Convert to record type for compatibility with existing code
  ({String host, int port, String authId}) toRecord() => (
        host: host,
        port: port,
        authId: authId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectionConfig &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          authId == other.authId;

  @override
  int get hashCode => Object.hash(host, port, authId);

  @override
  String toString() =>
      'ConnectionConfig(host: $host, port: $port, authId: $authId)';
}
