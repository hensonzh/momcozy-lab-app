import 'dart:async';
import 'package:momcozy_flutter_app/core/auth/auth_token_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench.dart';
import 'package:momcozy_flutter_app/modules/ibclc/auth/application/auth_gateway.dart';

const oldTokens = MomCozyAuthTokenResponse(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  expiresIn: 900,
  user: MomCozyAuthUser(id: 'expert', displayName: ''),
);
const newTokens = MomCozyAuthTokenResponse(
  accessToken: 'new-access',
  refreshToken: 'new-refresh',
  expiresIn: 900,
  user: MomCozyAuthUser(id: 'expert', displayName: ''),
);

class TestTokenStore implements AuthTokenStore {
  MomCozyAuthTokenResponse? saved;
  Completer<void>? gate;
  Completer<MomCozyAuthTokenResponse?>? readGate;
  final readStarted = Completer<void>();
  final writeStarted = Completer<void>();
  @override
  Future<MomCozyAuthTokenResponse?> read() async {
    if (!readStarted.isCompleted) readStarted.complete();
    return readGate == null ? saved : readGate!.future;
  }

  @override
  Future<void> write(MomCozyAuthTokenResponse tokens) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await gate?.future;
    saved = tokens;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }
}

class TestDeviceStore implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'test-browser';
}

class TestWorkbenchAuthGateway implements WorkbenchAuthGateway {
  int refreshCount = 0, verifyCount = 0, loginCount = 0;
  final signedOut = <String>[];
  Completer<MomCozyAuthTokenResponse>? verification;
  Completer<MomCozyAuthTokenResponse>? refreshing;
  @override
  Future<WorkbenchLoginChallenge> begin({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    loginCount++;
    return WorkbenchLoginChallenge(
      value: 'test-challenge',
      expiresAt: DateTime.utc(2026, 9, 8, 12, 5),
    );
  }

  @override
  Future<MomCozyAuthTokenResponse> verify({
    required String challenge,
    required String code,
  }) async {
    verifyCount++;
    return verification == null ? newTokens : verification!.future;
  }

  @override
  Future<MomCozyAuthTokenResponse> refresh(String refreshToken) async {
    refreshCount++;
    return refreshing == null ? newTokens : refreshing!.future;
  }

  @override
  Future<WorkbenchIdentity> identity() async => WorkbenchIdentity(
    provider: const CareProvider(
      id: 'expert',
      displayName: 'Test IBCLC',
      timezone: 'UTC',
      regions: ['CA'],
      languages: ['en'],
      bio: '',
      sandbox: true,
    ),
    email: 'expert@example.test',
    mfaExpiresAt: DateTime.utc(2026, 9, 9),
    serverTime: DateTime.utc(2026, 9, 8, 12),
  );
  @override
  Future<void> logout(String accessToken) async {
    signedOut.add(accessToken);
  }
}
