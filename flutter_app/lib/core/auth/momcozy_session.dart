import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum MomCozySessionStatus { anonymous, authenticated, expired, revoked }

class MomCozySession {
  const MomCozySession({
    required this.status,
    required this.userId,
    required this.babyId,
    required this.locale,
    this.accessToken,
    this.refreshToken,
  });

  factory MomCozySession.fromEnvironment({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String babyId,
    required String locale,
  }) {
    final normalizedAccessToken = _trimmedOrNull(accessToken);
    final normalizedRefreshToken = _trimmedOrNull(refreshToken);
    return MomCozySession(
      status: normalizedAccessToken == null && normalizedRefreshToken == null
          ? MomCozySessionStatus.anonymous
          : MomCozySessionStatus.authenticated,
      accessToken: normalizedAccessToken,
      refreshToken: normalizedRefreshToken,
      userId: _trimmedOrDefault(userId, 'demo-user'),
      babyId: _trimmedOrDefault(babyId, 'demo-baby'),
      locale: _trimmedOrDefault(locale, 'zh-CN'),
    );
  }

  final MomCozySessionStatus status;
  final String userId;
  final String babyId;
  final String locale;
  final String? accessToken;
  final String? refreshToken;

  bool get isAuthenticated =>
      status == MomCozySessionStatus.authenticated && hasAccessToken;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;

  MomCozySession copyWith({
    MomCozySessionStatus? status,
    String? userId,
    String? babyId,
    String? locale,
    String? accessToken,
    String? refreshToken,
    bool clearAccessToken = false,
    bool clearRefreshToken = false,
  }) {
    return MomCozySession(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      babyId: babyId ?? this.babyId,
      locale: locale ?? this.locale,
      accessToken: clearAccessToken ? null : accessToken ?? this.accessToken,
      refreshToken: clearRefreshToken
          ? null
          : refreshToken ?? this.refreshToken,
    );
  }

  MomCozySession loggedOut() {
    return MomCozySession(
      status: MomCozySessionStatus.anonymous,
      userId: userId,
      babyId: babyId,
      locale: locale,
    );
  }
}

abstract interface class MomCozySessionStore {
  Future<MomCozySession?> readSession();

  Future<void> writeSession(MomCozySession session);

  Future<void> clearSession();
}

class FlutterSecureMomCozySessionStore implements MomCozySessionStore {
  const FlutterSecureMomCozySessionStore({
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.session.v1',
  });

  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<MomCozySession?> readSession() async {
    final values = await Future.wait([
      storage.read(key: _key('status')),
      storage.read(key: _key('userId')),
      storage.read(key: _key('babyId')),
      storage.read(key: _key('locale')),
      storage.read(key: _key('accessToken')),
      storage.read(key: _key('refreshToken')),
    ]);

    final userId = _trimmedOrNull(values[1]);
    final babyId = _trimmedOrNull(values[2]);
    final locale = _trimmedOrNull(values[3]);
    final accessToken = _trimmedOrNull(values[4]);
    final refreshToken = _trimmedOrNull(values[5]);
    if (userId == null &&
        babyId == null &&
        locale == null &&
        accessToken == null &&
        refreshToken == null) {
      return null;
    }

    return MomCozySession(
      status: _parseStatus(values[0]) ?? _statusFor(accessToken, refreshToken),
      userId: userId ?? 'demo-user',
      babyId: babyId ?? 'demo-baby',
      locale: locale ?? 'zh-CN',
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> writeSession(MomCozySession session) async {
    await Future.wait([
      _write('status', session.status.name),
      _write('userId', session.userId),
      _write('babyId', session.babyId),
      _write('locale', session.locale),
      _write('accessToken', session.accessToken),
      _write('refreshToken', session.refreshToken),
    ]);
  }

  @override
  Future<void> clearSession() async {
    await Future.wait([
      storage.delete(key: _key('status')),
      storage.delete(key: _key('userId')),
      storage.delete(key: _key('babyId')),
      storage.delete(key: _key('locale')),
      storage.delete(key: _key('accessToken')),
      storage.delete(key: _key('refreshToken')),
    ]);
  }

  Future<void> _write(String key, String? value) {
    return storage.write(key: _key(key), value: _trimmedOrNull(value));
  }

  String _key(String key) => '$namespace.$key';
}

class MemoryMomCozySessionStore implements MomCozySessionStore {
  MemoryMomCozySessionStore([MomCozySession? session]) : _session = session;

  MomCozySession? _session;

  @override
  Future<MomCozySession?> readSession() async => _session;

  @override
  Future<void> writeSession(MomCozySession session) async {
    _session = session;
  }

  @override
  Future<void> clearSession() async {
    _session = null;
  }
}

class MomCozySessionManager {
  const MomCozySessionManager({
    required this.store,
    required this.environmentSession,
  });

  final MomCozySessionStore store;
  final MomCozySession environmentSession;

  Future<MomCozySession> bootstrap() async {
    final stored = await store.readSession();
    if (stored == null) return environmentSession;
    return stored.copyWith(
      userId: _trimmedOrDefault(stored.userId, environmentSession.userId),
      babyId: _trimmedOrDefault(stored.babyId, environmentSession.babyId),
      locale: _trimmedOrDefault(stored.locale, environmentSession.locale),
    );
  }

  Future<MomCozySession> authenticate(MomCozySession session) async {
    final authenticated = session.copyWith(
      status: MomCozySessionStatus.authenticated,
    );
    await store.writeSession(authenticated);
    return authenticated;
  }

  Future<MomCozySession> logout(MomCozySession current) async {
    await store.clearSession();
    return current.loggedOut();
  }

  Future<MomCozySession> switchAccount(MomCozySession next) async {
    await store.clearSession();
    return authenticate(next);
  }
}

MomCozySessionStatus _statusFor(String? accessToken, String? refreshToken) {
  if (accessToken == null && refreshToken == null) {
    return MomCozySessionStatus.anonymous;
  }
  return MomCozySessionStatus.authenticated;
}

MomCozySessionStatus? _parseStatus(String? value) {
  final normalized = _trimmedOrNull(value);
  if (normalized == null) return null;
  for (final status in MomCozySessionStatus.values) {
    if (status.name == normalized) return status;
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _trimmedOrDefault(String value, String fallback) {
  return _trimmedOrNull(value) ?? fallback;
}
