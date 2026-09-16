import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/google_sign_in_gateway.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
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

class _UnavailableGoogle implements GoogleSignInGateway {
  @override
  Future<String?> signIn() async => throw const GoogleSignInUnavailable();
}

void main() {
  Future<MomCozyRuntimeController> mount(
    WidgetTester tester,
    ApiJsonTransport transport,
    MomCozySessionStore store, {
    GoogleSignInGateway? googleSignIn,
  }) async {
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: transport),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAuthPage(
          runtimeController: controller,
          sessionStore: store,
          internalInviteOnly: false,
          authDeviceIdStore: _DeviceId(),
          googleSignIn: googleSignIn ?? _CancelledGoogle(),
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
    'language menu preserves the form and legal links open official pages',
    (tester) async {
      final transport = FixtureApiJsonTransport({});
      await mount(tester, transport, MemoryMomCozySessionStore());
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      final language = find.byKey(const ValueKey('auth-language-button'));
      await tester.ensureVisible(language);
      await tester.tap(language);
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'English'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('auth-email-field')),
            )
            .controller
            ?.text,
        'mia@example.com',
      );
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final opened = <String>[];
      var launchSucceeds = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'launch') {
              opened.add((call.arguments as Map)['url'] as String);
              return launchSucceeds;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      for (final label in ['Terms of Use', 'Privacy Policy.']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(opened, [
        'https://momcozy.com/pages/terms-conditions',
        'https://momcozy.com/pages/privacy-security',
      ]);
      launchSucceeds = false;
      await tester.tap(find.text('Terms of Use'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to open this page. Please try again.'),
        findsOneWidget,
      );
      expect(transport.postedBodies, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Google failure stays beside Google login and email remains usable',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 900,
        'user': {'id': 'mia'},
      });
      final store = MemoryMomCozySessionStore();
      await mount(tester, transport, store, googleSignIn: _UnavailableGoogle());
      final google = find.byKey(const ValueKey('auth-google-button'));
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      final error = find.byKey(const ValueKey('auth-error-text'));
      expect(error, findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThan(tester.getBottomLeft(google).dy),
      );
      expect(
        tester.getBottomLeft(error).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('auth-email-field'))).dy,
        ),
      );
      expect(transport.postedBodies, isEmpty);
      await fill(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(error, findsNothing);
      expect((await store.readSession())?.userId, 'mia');
    },
  );

  testWidgets('unverified login opens verification without a separate entry', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/login': {
        'http_status': 403,
        'body': {
          'error': {'code': 'email_unverified', 'message': 'Verify your email'},
        },
      },
      '/v1/auth/resend-verification': {'status': 'verification_if_required'},
      '/v1/auth/verify-email': {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 900,
        'user': {'id': 'mia'},
      },
    });
    final store = MemoryMomCozySessionStore();
    final controller = await mount(tester, transport, store);
    expect(find.text('Verify an existing account'), findsNothing);
    expect(find.byKey(const ValueKey('auth-code-field')), findsNothing);
    await fill(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    expect(transport.mutationPaths, [
      '/v1/auth/login',
      '/v1/auth/resend-verification',
    ]);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
    expect(controller.currentSession.isAuthenticated, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-email-field')))
          .controller
          ?.text,
      'mia@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    expect(transport.lastPath, '/v1/auth/verify-email');
    expect((await store.readSession())?.userId, 'mia');
  });

  testWidgets('password visibility can be toggled and resets on navigation', (
    tester,
  ) async {
    await mount(
      tester,
      FixtureApiJsonTransport({}),
      MemoryMomCozySessionStore(),
    );
    final password = find.byKey(const ValueKey('auth-password-field'));
    final passwordInput = find.descendant(
      of: password,
      matching: find.byType(TextField),
    );
    final visibility = find.byKey(const ValueKey('auth-password-visibility'));
    expect(visibility, findsNothing);
    await tester.enterText(password, 'secret123');
    await tester.pump();
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
    await tester.ensureVisible(visibility);
    await tester.tap(visibility);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordInput).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(password).controller?.text,
      'secret123',
    );
    await tester.tap(visibility);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
    await tester.tap(visibility);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(passwordInput).obscureText, isTrue);
  });

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
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies, isEmpty);
      await fill(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
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
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
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
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
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
