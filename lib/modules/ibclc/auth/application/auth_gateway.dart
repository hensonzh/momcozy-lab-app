import '../../../../core/auth/momcozy_auth_api.dart';
import '../../../../domain/ibclc/workbench.dart';

abstract interface class WorkbenchAuthGateway {
  Future<WorkbenchLoginChallenge> begin({
    required String email,
    required String password,
    required String deviceId,
  });
  Future<MomCozyAuthTokenResponse> verify({
    required String challenge,
    required String code,
  });
  Future<MomCozyAuthTokenResponse> refresh(String refreshToken);
  Future<WorkbenchIdentity> identity();
  Future<void> logout(String accessToken);
}
