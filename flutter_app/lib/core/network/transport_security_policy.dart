class TransportSecurityPolicy {
  const TransportSecurityPolicy._();

  static Uri requireSecureHttp(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw ArgumentError.value(uri, 'uri', 'Expected an HTTP(S) URI.');
    }
    return _requireSecureOrLocal(uri, secureSchemes: const {'https'});
  }

  static Uri requireSecureHttpOrWebSocket(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' &&
        scheme != 'https' &&
        scheme != 'ws' &&
        scheme != 'wss') {
      throw ArgumentError.value(
        uri,
        'uri',
        'Expected an HTTP(S) or WebSocket URI.',
      );
    }
    return _requireSecureOrLocal(uri, secureSchemes: const {'https', 'wss'});
  }

  static bool isLocalDevelopmentUri(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '10.0.2.2' ||
        _isPrivateIpv4Host(host);
  }

  static bool _isPrivateIpv4Host(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }

    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  static Uri _requireSecureOrLocal(
    Uri uri, {
    required Set<String> secureSchemes,
  }) {
    final scheme = uri.scheme.toLowerCase();
    if (secureSchemes.contains(scheme) || isLocalDevelopmentUri(uri)) {
      return uri;
    }
    throw ArgumentError.value(
      uri,
      'uri',
      'Insecure transport is only allowed for localhost or private LAN '
      'development.',
    );
  }
}
