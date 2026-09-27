import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import '../../support/fixture_api_transport.dart';

class _DeviceId implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'test-device';
}

class _GatedAuthTransport extends FixtureApiJsonTransportByPath {
  _GatedAuthTransport(super.responsesByPath);

  final codeGate = Completer<void>();

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/verify-registration-code') {
      await codeGate.future;
    }
    return super.postJson(path, body: body, headers: headers);
  }
}

class _AmbiguousRegistrationTransport extends FixtureApiJsonTransportByPath {
  _AmbiguousRegistrationTransport({required bool committed})
    : super({
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/verify-email': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 900,
          'user': {'id': 'mia'},
        },
        '/v1/auth/login': committed
            ? {
                'access_token': 'access',
                'refresh_token': 'refresh',
                'expires_in': 900,
                'user': {'id': 'mia'},
              }
            : {
                'http_status': 401,
                'body': {
                  'error': {'code': 'authentication_required'},
                },
              },
      });

  bool loseFirstResponse = true;
  int verificationRequests = 0;

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/verify-email') {
      verificationRequests++;
      final response = await super.postJson(path, body: body, headers: headers);
      if (loseFirstResponse) {
        loseFirstResponse = false;
        throw TimeoutException('Registration response lost');
      }
      return response;
    }
    return super.postJson(path, body: body, headers: headers);
  }
}

class _AmbiguousResetTransport extends FixtureApiJsonTransportByPath {
  _AmbiguousResetTransport()
    : super({
        '/v1/auth/forgot-password': {'status': 'reset_if_available'},
        '/v1/auth/reset-password': {
          'http_status': 401,
          'body': {
            'error': {'code': 'invalid_or_expired_code'},
          },
        },
      });
  bool loseFirstResponse = true;

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/reset-password' && loseFirstResponse) {
      loseFirstResponse = false;
      throw TimeoutException('Reset response lost');
    }
    return super.postJson(path, body: body, headers: headers);
  }
}

void main() {
  Future<MomCozyRuntimeController> mount(
    WidgetTester tester,
    ApiJsonTransport transport,
    MomCozySessionStore store,
  ) async {
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

  testWidgets('Google entry is absent and email login remains usable', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'expires_in': 900,
      'user': {'id': 'mia'},
    });
    final store = MemoryMomCozySessionStore();
    await mount(tester, transport, store);
    expect(find.byKey(const ValueKey('auth-google-button')), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(transport.postedBodies, isEmpty);
    await fill(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    expect((await store.readSession())?.userId, 'mia');
  });

  testWidgets('login validation stays below its corresponding field', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({});
    await mount(tester, transport, MemoryMomCozySessionStore());
    final email = find.byKey(const ValueKey('auth-email-field'));
    final password = find.byKey(const ValueKey('auth-password-field'));
    final submit = find.byKey(const ValueKey('auth-submit-button'));

    await tester.tap(submit);
    await tester.pumpAndSettle();
    final emailError = find.text('Enter a valid email address.');
    final passwordError = find.text('Enter your password.');
    expect(
      tester.getTopLeft(emailError).dy,
      greaterThan(tester.getTopLeft(email).dy),
    );
    expect(
      tester.getBottomLeft(emailError).dy,
      lessThan(tester.getTopLeft(password).dy),
    );
    expect(
      tester.getTopLeft(passwordError).dy,
      greaterThan(tester.getTopLeft(password).dy),
    );
    expect(
      tester.getBottomLeft(passwordError).dy,
      lessThan(tester.getTopLeft(submit).dy),
    );

    await tester.enterText(email, 'not-an-email');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(transport.postedBodies, isEmpty);
  });

  for (final (code, status, message) in [
    ('authentication_required', 401, 'Email or password is incorrect.'),
    ('rate_limited', 429, 'Too many attempts. Please wait and try again.'),
  ]) {
    testWidgets('login $code notice is below Sign in', (tester) async {
      final transport = FixtureApiJsonTransport({
        'http_status': status,
        'body': {
          'error': {'code': code},
        },
      });
      await mount(tester, transport, MemoryMomCozySessionStore());
      await fill(tester);
      final submit = find.byKey(const ValueKey('auth-submit-button'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final notice = find.byKey(const ValueKey('auth-error-text'));
      expect(find.text(message), findsOneWidget);
      expect(
        tester.getTopLeft(notice).dy,
        greaterThan(tester.getBottomLeft(submit).dy),
      );
      expect(
        tester.getBottomLeft(notice).dy,
        lessThan(tester.getTopLeft(find.text("Don't have an account?")).dy),
      );
      expect(transport.lastPath, '/v1/auth/login');
    });
  }

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
      '/v1/auth/verify-registration-code': {'status': 'code_valid'},
      '/v1/auth/verify-email': {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 900,
        'user': {'id': 'mia'},
      },
    });
    final store = MemoryMomCozySessionStore();
    final controller = await mount(tester, transport, store);
    expect(
      find.byKey(const ValueKey('auth-resume-verification')),
      findsNothing,
    );
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
    expect(find.text('Request another code in 60s'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('auth-verify-forgot-button')),
      findsNothing,
    );
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
    expect(transport.lastPath, '/v1/auth/verify-registration-code');
    expect(find.text('Set your password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'secret123',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    expect(transport.lastPath, '/v1/auth/verify-email');
    expect((await store.readSession())?.userId, 'mia');
  });

  testWidgets(
    'returning user can resume verification without a saved password',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/verify-email': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 900,
          'user': {'id': 'mia'},
        },
      });
      final store = MemoryMomCozySessionStore();
      await mount(tester, transport, store);
      expect(
        find.byKey(const ValueKey('auth-resume-verification')),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('auth-resume-verification')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
      expect(transport.mutationPaths, ['/v1/auth/register']);
      expect(find.text('Request another code in 60s'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/verify-registration-code');
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'secret123',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect((await store.readSession())?.userId, 'mia');
    },
  );

  testWidgets('registration verification only offers sign in as an exit', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'status': 'verification_required',
    });
    await mount(tester, transport, MemoryMomCozySessionStore());
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-register-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-register-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Check your inbox and spam folder'),
      findsOneWidget,
    );
    expect(find.text('Already registered? Reset password'), findsNothing);
    expect(find.text('Change email'), findsNothing);
    expect(find.text('Back to sign in'), findsOneWidget);
    await tester.ensureVisible(find.text('Back to sign in'));
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Momcozy'), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-forgot-button')), findsOneWidget);
  });

  testWidgets('invalid registration code hides the initial inbox notice', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/register': {'status': 'verification_required'},
      '/v1/auth/verify-registration-code': {
        'http_status': 400,
        'body': {
          'error': {'code': 'invalid_or_expired_code'},
        },
      },
    });
    await mount(tester, transport, MemoryMomCozySessionStore());
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-register-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-register-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    await tester.pump();
    final submit = find.byKey(const ValueKey('auth-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Check your inbox and spam folder'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(transport.lastPath, '/v1/auth/verify-registration-code');
    expect(
      find.text(
        'This code is invalid or expired. Request a new code and try again.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Check your inbox and spam folder'),
      findsNothing,
    );
    expect(find.text('Already registered? Reset password'), findsNothing);
    expect(find.text('Change email'), findsNothing);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets(
    'registration verification notices are exclusive across submit and resend',
    (tester) async {
      final transport = _GatedAuthTransport({
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/resend-verification': {'status': 'verification_if_required'},
      });
      addTearDown(() {
        if (!transport.codeGate.isCompleted) transport.codeGate.complete();
      });
      await mount(tester, transport, MemoryMomCozySessionStore());
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.pump();
      final submit = find.byKey(const ValueKey('auth-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      const inbox =
          'Check your inbox and spam folder for an 8-digit code. Codes expire in 15 minutes.';
      expect(transport.mutationPaths, ['/v1/auth/register']);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text(inbox), findsOneWidget);
      expect(find.textContaining('Already registered?'), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        '',
      );
      await tester.ensureVisible(find.text('Request another code'));
      await tester.tap(find.text('Request another code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email first.'), findsOneWidget);
      expect(find.text(inbox), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      transport.responsesByPath['/v1/auth/resend-verification'] = {
        'http_status': 429,
        'body': {
          'error': {'code': 'rate_limited'},
        },
      };
      await tester.ensureVisible(find.text('Request another code'));
      await tester.tap(find.text('Request another code'));
      await tester.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please wait and try again.'),
        findsOneWidget,
      );
      expect(find.text(inbox), findsNothing);
      transport.responsesByPath['/v1/auth/resend-verification'] = {
        'status': 'verification_if_required',
      };
      await tester.ensureVisible(find.text('Request another code'));
      await tester.tap(find.text('Request another code'));
      await tester.pumpAndSettle();
      expect(find.text(inbox), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-error-text')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text(inbox), findsNothing);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      transport.codeGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Set your password'), findsOneWidget);
    },
  );

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
    expect(find.byKey(const ValueKey('auth-remember-me')), findsNothing);
    expect(find.text('Save password'), findsNothing);
    expect(
      tester.widget<AutofillGroup>(find.byType(AutofillGroup)).onDisposeAction,
      AutofillContextAction.cancel,
    );
    final visibility = find.byKey(const ValueKey('auth-password-visibility'));
    expect(visibility, findsOneWidget);
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
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-register-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-register-button')));
    await tester.pumpAndSettle();
    expect(password, findsNothing);
    expect(find.byKey(const ValueKey('auth-code-field')), findsNothing);
  });

  testWidgets(
    'registration proves email before choosing and confirming password',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/verify-email': {
          'access_token': 'access',
          'refresh_token': 'refresh',
          'expires_in': 900,
          'user': {'id': 'mia'},
        },
      });
      final store = MemoryMomCozySessionStore();
      await mount(tester, transport, store);
      Future<void> tapAction(String key) async {
        final action = find.byKey(ValueKey(key));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      await tapAction('auth-register-button');
      expect(find.byKey(const ValueKey('auth-password-field')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tapAction('auth-submit-button');
      expect(transport.mutationPaths, ['/v1/auth/register']);
      expect(transport.lastBody, {'email': 'mia@example.com'});
      expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-password-field')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tapAction('auth-submit-button');
      expect(transport.mutationPaths, [
        '/v1/auth/register',
        '/v1/auth/verify-registration-code',
      ]);
      expect(find.byKey(const ValueKey('auth-code-field')), findsNothing);
      expect(find.byKey(const ValueKey('auth-password-field')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'different123',
      );
      await tapAction('auth-submit-button');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(transport.mutationPaths.length, 2);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'secret123',
      );
      await tapAction('auth-submit-button');
      expect(transport.lastPath, '/v1/auth/verify-email');
      expect(transport.lastBody, {
        'email': 'mia@example.com',
        'token': '12345678',
        'password': 'secret123',
        'confirm_password': 'secret123',
        'device_id': 'test-device',
      });
      expect((await store.readSession())?.userId, 'mia');
    },
  );

  testWidgets('email login saves a session without Google entry', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'expires_in': 900,
      'user': {'id': 'mia'},
    });
    final store = MemoryMomCozySessionStore();
    final controller = await mount(tester, transport, store);
    expect(find.byKey(const ValueKey('auth-google-button')), findsNothing);
    expect(controller.currentSession.isAuthenticated, isFalse);
    await fill(tester);
    final autofillSaveRequests = <Object?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
      if (call.method == 'TextInput.finishAutofillContext') {
        autofillSaveRequests.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.textInput, null),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-submit-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(autofillSaveRequests, isNot(contains(true)));
    expect(transport.lastPath, '/v1/auth/login');
    expect((await store.readSession())?.userId, 'mia');
    expect(controller.currentSession.locale, 'en-US');
  });
  testWidgets(
    'expired code after password entry returns to verification without a session',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/verify-email': {
          'http_status': 401,
          'body': {
            'error': {'code': 'invalid_or_expired_code'},
          },
        },
      });
      final store = MemoryMomCozySessionStore();
      final runtime = await mount(tester, transport, store);
      Future<void> submit() async {
        final button = find.byKey(const ValueKey('auth-submit-button'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.pump();
      await submit();
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await submit();
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'secret123',
      );
      await submit();
      expect(transport.lastPath, '/v1/auth/verify-email');
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.textContaining('Code expired or invalid'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-password-field')), findsNothing);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('auth-code-field')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(runtime.currentSession.isAuthenticated, isFalse);
      expect(await store.readSession(), isNull);
    },
  );

  testWidgets('registration submit is disabled until email is entered', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransport({
      'status': 'verification_required',
    });
    await mount(tester, transport, MemoryMomCozySessionStore());
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-register-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-register-button')));
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('auth-submit-button'));
    final email = find.byKey(const ValueKey('auth-email-field'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.text('Continue email verification'), findsNothing);
    expect(transport.postedBodies, isEmpty);

    await tester.enterText(email, '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(email, 'mia@example.com');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.enterText(email, '');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(transport.postedBodies, isEmpty);
  });

  testWidgets(
    'register requires email proof and invalid input sends no request',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'status': 'verification_required',
      });
      final store = MemoryMomCozySessionStore();
      final controller = await mount(tester, transport, store);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'invalid',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.postedBodies, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
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

  testWidgets('unverified login retains code entry when resend fails', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/login': {
        'http_status': 403,
        'body': {
          'error': {'code': 'email_unverified'},
        },
      },
      '/v1/auth/resend-verification': {
        'http_status': 503,
        'body': {
          'error': {'code': 'auth_email_unavailable'},
        },
      },
      '/v1/auth/verify-registration-code': {'status': 'code_valid'},
    });
    await mount(tester, transport, MemoryMomCozySessionStore());
    await fill(tester);
    final submit = find.byKey(const ValueKey('auth-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
    expect(find.textContaining('already have a valid code'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(transport.lastPath, '/v1/auth/verify-registration-code');
    expect(find.text('Set your password'), findsOneWidget);
  });

  testWidgets('navigating away from a password draft clears it', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/auth/register': {'status': 'verification_required'},
      '/v1/auth/verify-registration-code': {'status': 'code_valid'},
    });
    await mount(tester, transport, MemoryMomCozySessionStore());
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-register-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-register-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    await tester.pump();
    final submit = find.byKey(const ValueKey('auth-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-code-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'unsubmitted123',
    );
    await tester.ensureVisible(find.text('Back to sign in'));
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('auth-password-field')),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });
  testWidgets(
    'registration response loss recovers an already-created account',
    (tester) async {
      final transport = _AmbiguousRegistrationTransport(committed: true);
      final store = MemoryMomCozySessionStore();
      final controller = await mount(tester, transport, store);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.pump();
      final submit = find.byKey(const ValueKey('auth-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'secret123',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(transport.mutationPaths, [
        '/v1/auth/register',
        '/v1/auth/verify-registration-code',
        '/v1/auth/verify-email',
        '/v1/auth/login',
      ]);
      expect(transport.verificationRequests, 1);
      expect(controller.currentSession.isAuthenticated, isTrue);
      expect((await store.readSession())?.userId, 'mia');
    },
  );

  testWidgets(
    'registration response loss keeps draft until result can be checked',
    (tester) async {
      final transport = _AmbiguousRegistrationTransport(committed: false);
      final store = MemoryMomCozySessionStore();
      final controller = await mount(tester, transport, store);
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-register-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'mia@example.com',
      );
      await tester.pump();
      final submit = find.byKey(const ValueKey('auth-submit-button'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-code-field')),
        '12345678',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'secret123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'secret123',
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(
        find.textContaining('could not confirm whether your account'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('auth-password-field')),
            )
            .controller
            ?.text,
        'secret123',
      );
      transport.responsesByPath['/v1/auth/verify-email'] = {
        'http_status': 401,
        'body': {
          'error': {'code': 'invalid_or_expired_code'},
        },
      };
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Set your password'), findsOneWidget);
      expect(
        find.textContaining('could not confirm whether your account'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('auth-password-field')),
            )
            .controller
            ?.text,
        'secret123',
      );
      transport.responsesByPath['/v1/auth/login'] = {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'expires_in': 900,
        'user': {'id': 'mia'},
      };
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(transport.verificationRequests, 2);
      expect(controller.currentSession.isAuthenticated, isTrue);
    },
  );

  testWidgets('reset response loss preserves new password and code', (
    tester,
  ) async {
    final transport = _AmbiguousResetTransport();
    await mount(tester, transport, MemoryMomCozySessionStore());
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth-forgot-button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth-forgot-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    final submit = find.byKey(const ValueKey('auth-submit-button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'new-secret123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'new-secret123',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not confirm whether your password was reset'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('auth-password-field')),
          )
          .controller
          ?.text,
      'new-secret123',
    );
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('could not confirm whether your password was reset'),
      findsOneWidget,
    );
    expect(find.text('Reset your password'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('auth-code-field')))
          .controller
          ?.text,
      '12345678',
    );
  });

  testWidgets(
    'forgot password gives generic confirmation and submits new password',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'status': 'reset_if_available',
      });
      await mount(tester, transport, MemoryMomCozySessionStore());
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-forgot-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-forgot-button')));
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
      expect(find.text('verification code'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        findsOneWidget,
      );
      final resetPosts = transport.postedBodies.length;
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm your password.'), findsOneWidget);
      expect(transport.postedBodies.length, resetPosts);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'different123',
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(transport.postedBodies.length, resetPosts);
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'new-secret123',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('auth-submit-button')),
      );
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();
      expect(transport.lastPath, '/v1/auth/reset-password');
      expect(transport.lastBody?['new_password'], 'new-secret123');
      expect(transport.lastBody?['confirm_password'], 'new-secret123');
      expect(
        find.text('Password reset. Sign in with your new password.'),
        findsOneWidget,
      );
    },
  );
}
