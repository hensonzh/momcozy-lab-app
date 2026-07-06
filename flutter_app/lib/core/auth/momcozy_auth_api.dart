import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

const authSignupEndpoint = '/v1/auth/signup';
const authLoginEndpoint = '/v1/auth/login';
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
      final expired = current.copyWith(
        status: MomCozySessionStatus.expired,
        clearAccessToken: true,
        clearRefreshToken: true,
      );
      await store.writeSession(expired);
      return expired;
    }

    final tokens = await authRepository.refresh(refreshToken: refreshToken);
    final refreshed = tokens.toSession(
      babyId: current.babyId,
      locale: current.locale,
    );
    await store.writeSession(refreshed);
    return refreshed;
  }
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
