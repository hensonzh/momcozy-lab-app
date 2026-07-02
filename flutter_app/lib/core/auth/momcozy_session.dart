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

abstract interface class MomCozyScopedCacheStore {
  Future<void> clearUserScope(String userId);

  Future<void> clearNativePendingState();
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

class NoopMomCozyScopedCacheStore implements MomCozyScopedCacheStore {
  const NoopMomCozyScopedCacheStore();

  @override
  Future<void> clearNativePendingState() async {}

  @override
  Future<void> clearUserScope(String userId) async {}
}

class MomCozySessionManager {
  const MomCozySessionManager({
    required this.store,
    required this.environmentSession,
    this.scopedCacheStore = const NoopMomCozyScopedCacheStore(),
  });

  final MomCozySessionStore store;
  final MomCozySession environmentSession;
  final MomCozyScopedCacheStore scopedCacheStore;

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
    await scopedCacheStore.clearUserScope(current.userId);
    await scopedCacheStore.clearNativePendingState();
    await store.clearSession();
    return current.loggedOut();
  }

  Future<MomCozySession> switchAccount(MomCozySession next) async {
    final current = await store.readSession();
    await scopedCacheStore.clearUserScope(
      current?.userId ?? environmentSession.userId,
    );
    await scopedCacheStore.clearNativePendingState();
    await store.clearSession();
    return authenticate(next);
  }
}

MomCozySessionStatus statusForSessionSecrets(
  String? accessToken,
  String? refreshToken,
) {
  if (accessToken == null && refreshToken == null) {
    return MomCozySessionStatus.anonymous;
  }
  return MomCozySessionStatus.authenticated;
}

MomCozySessionStatus? parseMomCozySessionStatus(String? value) {
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

String? trimmedSessionValue(String? value) => _trimmedOrNull(value);

String _trimmedOrDefault(String value, String fallback) {
  return _trimmedOrNull(value) ?? fallback;
}
