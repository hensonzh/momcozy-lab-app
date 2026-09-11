import 'dart:convert';
import 'flutter_secure_momcozy_session_store.dart';
import 'momcozy_auth_api.dart';

abstract interface class AuthTokenStore {
  Future<MomCozyAuthTokenResponse?> read();
  Future<void> write(MomCozyAuthTokenResponse tokens);
  Future<void> clear();
}

/// Stores only issued identity credentials; selected babies belong to product state.
class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore({
    required this.key,
    this.storage = const FlutterSecureMomCozySessionStorage(),
  });
  final String key;
  final MomCozySessionStorage storage;
  @override
  Future<MomCozyAuthTokenResponse?> read() async {
    final raw = await storage.read(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map || json['schema_version'] != 1) {
        throw const FormatException('Unsupported token schema.');
      }
      return MomCozyAuthTokenResponse.fromMap(Map<String, Object?>.from(json));
    } on FormatException {
      await clear();
      return null;
    } on MomCozyAuthResponseFormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(MomCozyAuthTokenResponse tokens) async {
    final raw = jsonEncode({
      'schema_version': 1,
      'access_token': tokens.accessToken,
      'refresh_token': tokens.refreshToken,
      'expires_in': tokens.expiresIn,
      'token_type': tokens.tokenType,
      'user': {'id': tokens.user.id},
    });
    await storage.write(key, raw);
    if (await storage.read(key) != raw) {
      await clear();
      throw const FormatException(
        'Could not persist the authenticated session.',
      );
    }
  }

  @override
  Future<void> clear() => storage.delete(key);
}
