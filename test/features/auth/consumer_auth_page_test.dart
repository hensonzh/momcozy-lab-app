import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import '../../support/fixture_api_transport.dart';

class _DeviceId implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'test-device';
}

class _CancelledGoogle implements GoogleSignInGateway {
  @override
  Future<String?> signIn() async => null;
}

void main() {
  Future<MomCozyRuntimeController> mount(
    WidgetTester tester,
    FixtureApiJsonTransport transport,
    MomCozySessionStore store,
  ) async {
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAuthPage(
          runtimeController: controller,
          sessionStore: store,
          internalInviteOnly: false,
          authDeviceIdStore: _DeviceId(),
          googleSignIn: _CancelledGoogle(),
        ),
      ),
    );
    return controller;
  }

  Future<void> fill(
    WidgetTester tester, {
    String password = 'secret123',
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      password,
    );
  }

  testWidgets(
    'email login saves a session and Google cancellation does not sign in',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 900,
        'user': {'id': 'mia'},
      });
      final store = MemoryMomCozySessionStore();
      final controller = await mount(tester, transport, store);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-google-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-google-button')));
      await tester.pumpAndSettle();
      expect(find.text('Google sign-in was canceled.'), findsOneWidget);
      expect(controller.currentSession.isAuthenticated, isFalse);
      await fill(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/login');
      expect((await store.readSession())?.userId, 'mia');
      expect(controller.currentSession.locale, 'en-US');
    },
  );
  testWidgets(
    'register requires email proof and invalid input sends no request',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'status': 'verification_required',
      });
      final store = MemoryMomCozySessionStore();
      final controller = await mount(tester, transport, store);
      await tester.ensureVisible(find.text('Create an account'));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await fill(tester, password: 'weak');
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies, isEmpty);
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/register');
      expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(await store.readSession(), isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('auth-email-field')),
            )
            .controller
            ?.text,
        'mia@example.com',
      );
    },
  );
  testWidgets(
    'forgot password gives generic confirmation and submits new password',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'status': 'reset_if_available',
      });
      await mount(tester, transport, MemoryMomCozySessionStore());
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/forgot-password');
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'new-secret123',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/reset-password');
      expect(transport.lastBody?['new_password'], 'new-secret123');
      expect(
        find.text('Password reset. Sign in with your new password.'),
        findsOneWidget,
      );
    },
  );
}
