class SafeLinkTarget {
  const SafeLinkTarget._({
    this.internalPath,
    this.internalLocation,
    this.externalUri,
  });

  final String? internalPath;
  final String? internalLocation;
  final Uri? externalUri;

  bool get isInternal => internalPath != null;

  bool get isExternal => externalUri != null;

  static SafeLinkTarget? tryParse(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (_containsUnsafeCharacters(normalized)) return null;

    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;
    if (uri.hasScheme) return _externalTarget(uri);
    final rawPath = normalized.split(RegExp(r'[?#]')).first;
    if (uri.hasAuthority ||
        !normalized.startsWith('/') ||
        normalized.startsWith('//') ||
        rawPath.split('/').contains('..') ||
        uri.pathSegments.contains('..')) {
      return null;
    }
    return SafeLinkTarget._(
      internalPath: uri.path,
      internalLocation: uri.toString(),
    );
  }

  static SafeLinkTarget? _externalTarget(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    if (uri.host.trim().isEmpty || uri.userInfo.isNotEmpty) return null;
    return SafeLinkTarget._(externalUri: uri);
  }
}

bool _containsUnsafeCharacters(String value) {
  if (value.contains('\\')) return true;
  return value.codeUnits.any(
    (unit) => unit <= 0x1f || unit == 0x7f || unit == 0x20,
  );
}
