import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/modules/ibclc/auth/application/workbench_auth_controller.dart';
import 'workbench_auth_test_support.dart';

void main() {
  test(
    'password challenge never authenticates before OTP verification and identity check',
    () async {
      final gateway = TestWorkbenchAuthGateway(), store = TestTokenStore();
      final controller = WorkbenchAuthController(
        gateway: gateway,
        store: store,
        devices: TestDeviceStore(),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await controller.begin('expert@example.test', 'password');
      expect(controller.authenticated, isFalse);
      expect(store.saved, isNull);
      await controller.verify('12');
      expect(gateway.verifyCount, 0);
      await controller.verify('123456');
      expect(controller.authenticated, isTrue);
      expect(store.saved?.user.id, 'expert');
    },
  );

  test(
    'logout cannot be undone by a refresh that was already writing tokens',
    () async {
      final gateway = TestWorkbenchAuthGateway(),
          store = TestTokenStore()..saved = oldTokens;
      final controller = WorkbenchAuthController(
        gateway: gateway,
        store: store,
        devices: TestDeviceStore(),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      store.gate = Completer<void>();
      final refresh = controller.refresh(oldTokens.accessToken);
      await store.writeStarted.future;
      final logout = controller.logout();
      store.gate!.complete();
      await Future.wait([refresh, logout]);
      expect(controller.authenticated, isFalse);
      expect(controller.accessToken, isNull);
      expect(store.saved, isNull);
    },
  );

  test(
    'logout discards late OTP responses from an earlier login attempt',
    () async {
      final gateway = TestWorkbenchAuthGateway(), store = TestTokenStore();
      final controller = WorkbenchAuthController(
        gateway: gateway,
        store: store,
        devices: TestDeviceStore(),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await controller.begin('expert@example.test', 'password');
      gateway.verification = Completer<MomCozyAuthTokenResponse>();
      final verify = controller.verify('123456');
      await controller.logout();
      gateway.verification!.complete(newTokens);
      await verify;
      expect(controller.authenticated, isFalse);
      expect(store.saved, isNull);
    },
  );

  test(
    'logout invalidates a saved-session restore that has not finished reading storage',
    () async {
      final gateway = TestWorkbenchAuthGateway(),
          store = TestTokenStore()
            ..readGate = Completer<MomCozyAuthTokenResponse?>();
      final controller = WorkbenchAuthController(
        gateway: gateway,
        store: store,
        devices: TestDeviceStore(),
      );
      addTearDown(controller.dispose);
      final restoring = controller.restore();
      await store.readStarted.future;
      final logout = controller.logout();
      store.readGate!.complete(oldTokens);
      await Future.wait([restoring, logout]);
      expect(controller.authenticated, isFalse);
      expect(controller.accessToken, isNull);
      expect(store.saved, isNull);
    },
  );
  test(
    'simultaneous unauthorized requests share one refresh operation',
    () async {
      final gateway = TestWorkbenchAuthGateway(),
          store = TestTokenStore()..saved = oldTokens;
      final controller = WorkbenchAuthController(
        gateway: gateway,
        store: store,
        devices: TestDeviceStore(),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      gateway.refreshing = Completer<MomCozyAuthTokenResponse>();
      final first = controller.refresh(oldTokens.accessToken);
      final second = controller.refresh(oldTokens.accessToken);
      expect(gateway.refreshCount, 1);
      gateway.refreshing!.complete(newTokens);
      await Future.wait([first, second]);
      expect(controller.accessToken, newTokens.accessToken);
      expect(store.saved, newTokens);
      await controller.refresh(oldTokens.accessToken);
      expect(gateway.refreshCount, 1);
    },
  );
}
