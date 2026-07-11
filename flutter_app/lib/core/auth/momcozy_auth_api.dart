import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

const authSignupEndpoint = '/v1/auth/signup';
const authLoginEndpoint = '/v1/auth/login';
const authInviteLoginEndpoint = '/v1/auth/invite-login';
const authRefreshEndpoint = '/v1/auth/refresh';
const authLogoutEndpoint = '/v1/auth/logout';

class MomCozyAuthApiRepository {
  const MomCozyAuthApiRepository({required this.transport});

  final ApiJsonTransport transport;

  Future<MomCozyAuthTokenResponse> signup({
    required String email,
    required String password,
    String displayName = '',
    String deviceId = '',
  }) async {
    final response = await transport.postJson(
      authSignupEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
        if (displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
        if (deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
      },
    );
    return MomCozyAuthTokenResponse.fromMap(response);
  }

  Future<MomCozyAuthTokenResponse> login({
    required String email,
    required String password,
    String deviceId = '',
  }) async {
    final response = await transport.postJson(
      authLoginEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
        if (deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
      },
    );
    return MomCozyAuthTokenResponse.fromMap(response);
  }

  Future<MomCozyAuthTokenResponse> inviteLogin({
    required String inviteCode,
    required String deviceId,
  }) async {
    final response = await transport.postJson(
      authInviteLoginEndpoint,
      body: {'invite_code': inviteCode.trim(), 'device_id': deviceId.trim()},
    );
    return MomCozyAuthTokenResponse.fromMap(response);
  }

  Future<MomCozyAuthTokenResponse> refresh({
    required String refreshToken,
  }) async {
    final response = await transport.postJson(
      authRefreshEndpoint,
      body: {'refresh_token': refreshToken.trim()},
    );
    return MomCozyAuthTokenResponse.fromMap(response);
  }

  Future<void> logout() async {
    await transport.postJson(authLogoutEndpoint);
  }
}

class MomCozyAuthTokenResponse {
  const MomCozyAuthTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    this.tokenType = 'bearer',
  });

  factory MomCozyAuthTokenResponse.fromMap(Map<String, Object?> map) {
    final user = map['user'];
    return MomCozyAuthTokenResponse(
      accessToken: _requiredString(map, 'access_token'),
      refreshToken: _requiredString(map, 'refresh_token'),
      expiresIn: _requiredInt(map, 'expires_in'),
      tokenType: _optionalString(map, 'token_type') ?? 'bearer',
      user: MomCozyAuthUser.fromMap(
        user is Map ? Map<String, Object?>.from(user) : const {},
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final MomCozyAuthUser user;

  MomCozySession toSession({required String babyId, required String locale}) {
    return MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: user.id,
      babyId: trimmedSessionValue(babyId) ?? 'demo-baby',
      locale: trimmedSessionValue(locale) ?? 'zh-CN',
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class MomCozyAuthUser {
  const MomCozyAuthUser({required this.id, required this.displayName});

  factory MomCozyAuthUser.fromMap(Map<String, Object?> map) {
    return MomCozyAuthUser(
      id: _requiredString(map, 'id'),
      displayName: _requiredString(map, 'display_name'),
    );
  }

  final String id;
  final String displayName;
}

class MomCozySessionRefreshCoordinator {
  MomCozySessionRefreshCoordinator({
    required this.authRepository,
    required this.store,
  });

  final MomCozyAuthApiRepository authRepository;
  final MomCozySessionStore store;
  Future<MomCozySession>? _inFlightRefresh;

  Future<MomCozySession> refresh(MomCozySession current) {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;
    final next = _refresh(current);
    _inFlightRefresh = next.whenComplete(() {
      _inFlightRefresh = null;
    });
    return _inFlightRefresh!;
  }

  Future<MomCozySession> _refresh(MomCozySession current) async {
    final refreshToken = trimmedSessionValue(current.refreshToken);
    if (refreshToken == null) {
      return _expire(current);
    }

    late final MomCozyAuthTokenResponse tokens;
    try {
      tokens = await authRepository.refresh(refreshToken: refreshToken);
    } catch (error) {
      if (_isTerminalRefreshError(error)) {
        return _expire(current);
      }
      rethrow;
    }
    final refreshed = tokens.toSession(
      babyId: current.babyId,
      locale: current.locale,
    );
    await store.writeSession(refreshed);
    return refreshed;
  }

  Future<MomCozySession> _expire(MomCozySession current) async {
    final expired = current.copyWith(
      status: MomCozySessionStatus.expired,
      clearAccessToken: true,
      clearRefreshToken: true,
    );
    await store.writeSession(expired);
    return expired;
  }
}

typedef AuthenticatedTransportFactory =
    ApiJsonTransport Function(String? accessToken);

typedef AuthenticatedMultipartTransportFactory =
    ApiMultipartTransport Function(String? accessToken);

typedef MomCozySessionProvider = MomCozySession Function();

typedef MomCozySessionChanged = Future<void> Function(MomCozySession session);

class AuthenticatedApiJsonTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  const AuthenticatedApiJsonTransport({
    required this.transportFactory,
    required this.sessionProvider,
    required this.refreshCoordinator,
    required this.onSessionChanged,
  });

  final AuthenticatedTransportFactory transportFactory;
  final MomCozySessionProvider sessionProvider;
  final MomCozySessionRefreshCoordinator refreshCoordinator;
  final MomCozySessionChanged onSessionChanged;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    return _send((transport) => transport.getJson(path, query: query));
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _send(
      (transport) => transport.postJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _sendMutation(
      (transport) => transport.putJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    return _sendMutation(
      (transport) => transport.patchJson(path, body: body, headers: headers),
    );
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) {
    return _sendMutation(
      (transport) => transport.deleteJson(path, headers: headers),
    );
  }

  Future<Map<String, Object?>> _send(
    Future<Map<String, Object?>> Function(ApiJsonTransport transport) send,
  ) async {
    final initialSession = sessionProvider();
    try {
      return await send(transportFactory(initialSession.accessToken));
    } catch (error) {
      if (!_shouldRefresh(error)) rethrow;
      final refreshed = await refreshCoordinator.refresh(initialSession);
      await onSessionChanged(refreshed);
      if (!refreshed.isAuthenticated) {
        rethrow;
      }
      return send(transportFactory(refreshed.accessToken));
    }
  }

  Future<Map<String, Object?>> _sendMutation(
    Future<Map<String, Object?>> Function(ApiJsonMutationTransport transport)
    send,
  ) {
    return _send((transport) {
      if (transport is! ApiJsonMutationTransport) {
        throw UnsupportedError('JSON mutation transport is not available.');
      }
      return send(transport as ApiJsonMutationTransport);
    });
  }
}

class AuthenticatedApiMultipartTransport implements ApiMultipartTransport {
  const AuthenticatedApiMultipartTransport({
    required this.transportFactory,
    required this.sessionProvider,
    required this.refreshCoordinator,
    required this.onSessionChanged,
  });

  final AuthenticatedMultipartTransportFactory transportFactory;
  final MomCozySessionProvider sessionProvider;
  final MomCozySessionRefreshCoordinator refreshCoordinator;
  final MomCozySessionChanged onSessionChanged;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    final initialSession = sessionProvider();
    try {
      return await transportFactory(
        initialSession.accessToken,
      ).uploadMultipart(path, fields: fields, headers: headers, file: file);
    } catch (error) {
      if (!_shouldRefresh(error)) rethrow;
      final refreshed = await refreshCoordinator.refresh(initialSession);
      await onSessionChanged(refreshed);
      if (!refreshed.isAuthenticated) {
        rethrow;
      }
      return transportFactory(
        refreshed.accessToken,
      ).uploadMultipart(path, fields: fields, headers: headers, file: file);
    }
  }
}

bool _shouldRefresh(Object error) {
  if (error is! ApiHttpException) return false;
  return error.statusCode == 401 ||
      error.errorCode == 'authentication_required' ||
      error.errorCode == 'token_expired';
}

bool _isTerminalRefreshError(Object error) {
  if (error is! ApiHttpException) return false;
  return error.statusCode == 401 || error.statusCode == 403;
}

class MomCozyAuthResponseFormatException implements Exception {
  const MomCozyAuthResponseFormatException(this.message);

  final String message;

  @override
  String toString() => 'MomCozyAuthResponseFormatException($message)';
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key);
  if (value == null) {
    throw MomCozyAuthResponseFormatException('Missing string field: $key');
  }
  return value;
}

String? _optionalString(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _requiredInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is int) return value;
  throw MomCozyAuthResponseFormatException('Missing integer field: $key');
}
