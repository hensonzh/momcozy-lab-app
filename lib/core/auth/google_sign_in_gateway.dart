import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleSignInGateway {
  Future<String?> signIn();
}

class NativeGoogleSignInGateway implements GoogleSignInGateway {
  const NativeGoogleSignInGateway();
  static Future<void>? _initialization;

  @override
  Future<String?> signIn() async {
    const serverId = String.fromEnvironment('MOMCOZY_GOOGLE_SERVER_CLIENT_ID');
    const clientId = String.fromEnvironment('MOMCOZY_GOOGLE_IOS_CLIENT_ID');
    if (kIsWeb || serverId.isEmpty) throw const GoogleSignInUnavailable();
    final google = GoogleSignIn.instance;
    try {
      await (_initialization ??= google
          .initialize(
            serverClientId: serverId,
            clientId: clientId.isEmpty ? null : clientId,
          )
          .catchError((Object error) {
            _initialization = null;
            throw error;
          }));
      if (!google.supportsAuthenticate()) throw const GoogleSignInUnavailable();
      // Always let the user choose/confirm the Google account for this operation.
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) throw const GoogleSignInUnavailable();
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleSignInUnavailable();
    }
  }
}

class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable();
}
