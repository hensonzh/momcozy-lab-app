@Tags(['golden'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

const _tokens = <String, Object?>{
  'access_token': 'inventory-access',
  'refresh_token': 'inventory-refresh',
  'expires_in': 900,
  'user': {'id': 'inventory-user'},
};
const _account = <String, Object?>{
  'id': 'inventory-user',
  'email': 'inventory@example.test',
  'email_verified': true,
  'account_status': 'active',
  'auth_providers': ['email'],
};
Map<String, Object?> _error(String code, [int status = 400]) => {
  'http_status': status,
  'body': {
    'error': {'code': code},
  },
};

class _DeviceId implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'inventory-device';
}

// Production session transitions rebuild the runtime. Preserve the isolated
// HTTP boundary across that rebuild, while retaining the real session/router
// flow. Never let a test's login success start requests to the default server.
class _FixtureRuntimeController extends MomCozyRuntimeController {
  _FixtureRuntimeController(this.transport)
    : super(MomCozyApiRuntime(jsonTransport: transport));
  final _Transport transport;

  @override
  void replaceRuntime(MomCozyApiRuntime runtime) => super.replaceRuntime(
    MomCozyApiRuntime.fromSession(runtime.session, jsonTransport: transport),
  );
}

class _Transport extends FixtureApiJsonTransportByPath {
  _Transport()
    : super({
        '/v1/auth/login': _tokens,
        '/v1/auth/verify-email': _tokens,
        '/v1/auth/me': _account,
        '/v1/auth/register': {'status': 'verification_required'},
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
        '/v1/auth/resend-verification': {'status': 'verification_if_required'},
        '/v1/auth/forgot-password': {'status': 'reset_if_available'},
        '/v1/auth/reset-password': {'status': 'reset'},
      }, writeResponsesByPath: <String, Map<String, Object?>>{});
  final gates = <String, Completer<void>>{};
  final disconnected = <String>{};
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await gates[path]?.future;
    if (disconnected.contains(path)) {
      throw const SocketException('Isolated offline');
    }
    return super.postJson(path, body: body, headers: headers);
  }
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  late _Transport transport;
  late MomCozyRuntimeController runtime;
  late GoRouter router;
  late FakeRouteIntentPlatform platform;
  late MemoryMomCozySessionStore store;
  String? previous;
  late String variant;
  final steps = <Map<String, Object?>>[];

  Future<void> mount(
    WidgetTester tester, {
    double width = 393,
    double scale = 1,
  }) async {
    previous = null;
    steps.clear();
    tester.view.physicalSize = Size(width, 844);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    variant = '${width.toInt()}-${scale.toInt()}x';
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    transport = _Transport();
    runtime = _FixtureRuntimeController(transport);
    store = MemoryMomCozySessionStore();
    platform = FakeRouteIntentPlatform();
    router = createMomCozyRouter(
      initialLocation: '/more',
      runtimeController: runtime,
      sessionStore: store,
      authDeviceIdStore: _DeviceId(),
    );
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        sessionStore: store,
        routeIntentPlatform: platform,
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      for (final asset in [
        'auth_mother_baby.png',
        'momcozy_logo.png',
        'navigation_figma/ArtworkSoftMe.png',
        'navigation_figma/ArtworkSoftBaby.png',
        'navigation_figma/AvatarCozymateNav.png',
      ]) {
        await precacheImage(AssetImage('assets/images/$asset'), context);
      }
    });
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    addTearDown(() async {
      // Do not leave pending fixture work or route subscriptions behind.
      for (final gate in transport.gates.values) {
        if (!gate.isCompleted) gate.complete();
      }
      router.dispose();
      runtime.dispose();
      await platform.dispose();
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'inventory@example.test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'Inventory123',
    );
  }

  Future<void> capture(
    WidgetTester tester,
    String state,
    String route,
    String action,
  ) async {
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final source =
        'test/goldens/ui_inventory/auth-followup-$state-$variant.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/ui_inventory/auth-followup-$state-$variant.png',
      ),
    );
    steps.add({
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Open More while signed out → real auth redirect',
      'evidence':
          'Actual MomCozyFlutterApp and createMomCozyRouter; only HTTP/session/native-intent dependencies replaced with isolated fixtures',
      'test': 'test/features/auth/auth_followup_inventory_test.dart',
    });
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/auth-followup-$state-$variant.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(steps.last)}\n',
      );
    }
  }

  final email = find.byKey(const ValueKey('auth-email-field'));
  final password = find.byKey(const ValueKey('auth-password-field'));
  final code = find.byKey(const ValueKey('auth-code-field'));
  final submit = find.byKey(const ValueKey('auth-submit-button'));
  Future<void> snap(WidgetTester tester, String state, String action) =>
      capture(tester, state, '/login', action);
  Future<void> submitWaiting(
    WidgetTester tester,
    String path,
    String state,
  ) async {
    transport.gates[path] = Completer<void>();
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await snap(tester, state, 'Submit → $path request pending, form disabled');
  }

  Future<void> release(WidgetTester tester, String path) async {
    transport.gates[path]!.complete();
    await tester.pumpAndSettle();
  }

  for (final size in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets('auth normal password recovery chain ${size.$1}/${size.$2}', (
      tester,
    ) async {
      await mount(tester, width: size.$1, scale: size.$2);
      await snap(tester, 'reset-entry', 'Signed out More redirect → login');
      // One shared password-visibility state; no form/size cross product.
      if (size.$1 == 393 && size.$2 == 1) {
        await tester.enterText(password, 'Sample123');
        await tester.pump();
        await tap(
          tester,
          find.byKey(const ValueKey('auth-password-visibility')),
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: password,
                  matching: find.byType(EditableText),
                ),
              )
              .obscureText,
          isFalse,
        );
        await snap(
          tester,
          'login-password-visible',
          'Login password eye → visible synthetic password; shared field behavior',
        );
        await tap(
          tester,
          find.byKey(const ValueKey('auth-password-visibility')),
        );
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: password,
                  matching: find.byType(EditableText),
                ),
              )
              .obscureText,
          isTrue,
        );
        await tester.enterText(password, '');
      }
      await tap(tester, find.byKey(const ValueKey('auth-forgot-button')));
      await snap(
        tester,
        'forgot-empty',
        'Login forgot password → email recovery form',
      );
      await tap(tester, submit);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await snap(
        tester,
        'forgot-validation',
        'Submit empty recovery email → validation',
      );
      await tester.enterText(email, 'invalid');
      await tap(tester, submit);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(transport.mutationPaths, isEmpty);
      await snap(
        tester,
        'forgot-email-validation',
        'Submit malformed recovery email → validation without network request',
      );
      await tester.enterText(email, 'inventory@example.test');
      transport.disconnected.add('/v1/auth/forgot-password');
      await tap(tester, submit);
      expect(
        find.text(
          'Unable to connect or save your session. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      await snap(
        tester,
        'forgot-offline',
        'Recovery request offline → form retained and retry possible',
      );
      transport.disconnected.clear();
      transport.responsesByPath['/v1/auth/forgot-password'] = _error(
        'auth_email_unavailable',
        503,
      );
      await tap(tester, submit);
      expect(
        find.text(
          'Email verification is temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      await snap(
        tester,
        'forgot-email-unavailable',
        'Retry recovery → email service unavailable',
      );
      transport.responsesByPath['/v1/auth/forgot-password'] = {
        'status': 'reset_if_available',
      };
      await submitWaiting(tester, '/v1/auth/forgot-password', 'forgot-pending');
      await release(tester, '/v1/auth/forgot-password');
      expect(find.text('Reset your password'), findsOneWidget);
      expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
      await snap(
        tester,
        'reset-code-form',
        'Recovery accepted → reset code and new password form',
      );
      expect(find.text('Request another code in 60s'), findsOneWidget);
      await snap(
        tester,
        'reset-resend-cooldown',
        'Immediate reset code resend → cooldown message',
      );
      await tap(tester, submit);
      expect(
        find.text('Enter the 8-digit code from your email.'),
        findsOneWidget,
      );
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text('Confirm your password.'), findsOneWidget);
      await snap(
        tester,
        'reset-empty-validation',
        'Submit empty code and new password → field errors',
      );
      await tester.enterText(code, '12345678');
      await tester.enterText(password, 'short');
      await tap(tester, submit);
      expect(
        find.text('Use 8–128 characters with a letter and a number.'),
        findsOneWidget,
      );
      await snap(
        tester,
        'reset-password-validation',
        'Eight digit code and weak new password → password rule error',
      );
      await tester.enterText(password, 'NewInventory123');
      await tester.enterText(
        find.byKey(const ValueKey('auth-confirm-password-field')),
        'NewInventory123',
      );
      transport.responsesByPath['/v1/auth/reset-password'] = _error(
        'invalid_or_expired_code',
      );
      await tap(tester, submit);
      expect(
        find.text(
          'This code is invalid or expired. Request a new code and try again.',
        ),
        findsOneWidget,
      );
      await snap(
        tester,
        'reset-expired-code',
        'Reset submission → expired code and values retained',
      );
      transport.responsesByPath['/v1/auth/reset-password'] = _error(
        'rate_limited',
        429,
      );
      await tap(tester, submit);
      await snap(
        tester,
        'reset-rate-limited',
        'Retry reset → server rate limit',
      );
      transport.responsesByPath['/v1/auth/reset-password'] = {
        'status': 'reset',
      };
      await submitWaiting(tester, '/v1/auth/reset-password', 'reset-pending');
      await release(tester, '/v1/auth/reset-password');
      expect(
        find.text('Password reset. Sign in with your new password.'),
        findsOneWidget,
      );
      expect(tester.widget<TextFormField>(password).controller!.text, isEmpty);
      expect(await store.readSession(), isNull);
      await snap(
        tester,
        'reset-complete',
        'Reset accepted → login with success message, password cleared, still signed out',
      );
      await tester.enterText(password, 'NewInventory123');
      await tap(tester, submit);
      expect(runtime.currentSession.isAuthenticated, isTrue);
      await capture(
        tester,
        'reset-login-more',
        '/more',
        'Sign in with new password → real session transition restores More',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('auth registration and verification visible submit states', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const ValueKey('auth-register-button')));
    await tester.enterText(email, 'inventory@example.test');
    transport.responsesByPath['/v1/auth/register'] = _error(
      'auth_email_unavailable',
      503,
    );
    await submitWaiting(tester, '/v1/auth/register', 'register-pending');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await release(tester, '/v1/auth/register');
    expect(find.text('Create your account'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(
      tester.widget<TextFormField>(email).controller!.text,
      'inventory@example.test',
    );
    await snap(
      tester,
      'register-email-unavailable',
      'Registration email service fails → form and draft retained → retry enabled',
    );
    transport.responsesByPath['/v1/auth/register'] = {
      'status': 'verification_required',
    };
    await tap(tester, submit);
    expect(find.text('Verify your email'), findsOneWidget);
    await tester.enterText(code, '12345678');
    await submitWaiting(
      tester,
      '/v1/auth/verify-registration-code',
      'registration-code-pending',
    );
    await release(tester, '/v1/auth/verify-registration-code');
    expect(find.text('Set your password'), findsOneWidget);
    await snap(
      tester,
      'registration-set-password',
      'Valid code → password form',
    );
    await tester.enterText(password, 'Inventory123');
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'Inventory123',
    );
    await submitWaiting(
      tester,
      '/v1/auth/verify-email',
      'verify-submit-pending',
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await release(tester, '/v1/auth/verify-email');
    expect(runtime.currentSession.isAuthenticated, isTrue);
    expect(router.routeInformationProvider.value.uri.path, '/more');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('auth unverified login and resend errors retry verify', (
    tester,
  ) async {
    await mount(tester);
    await snap(tester, 'verify-entry', 'Signed out More → login');
    await fill(tester);
    transport.responsesByPath['/v1/auth/login'] = _error(
      'email_unverified',
      403,
    );
    transport.responsesByPath['/v1/auth/resend-verification'] = _error(
      'auth_email_unavailable',
      503,
    );
    await tap(tester, submit);
    await snap(
      tester,
      'verify-initial-send-error',
      'Unverified login → resend fails, existing code may still be entered',
    );
    transport.responsesByPath['/v1/auth/resend-verification'] = {
      'status': 'verification_if_required',
    };
    await tap(tester, find.text('Request another code'));
    expect(find.text('Verify your email'), findsOneWidget);
    await snap(
      tester,
      'verify-from-login',
      'Retry code request → verification form remains usable',
    );
    await tap(tester, find.text('Back to sign in'));
    await tap(tester, find.byKey(const ValueKey('auth-register-button')));
    await tap(tester, submit);
    expect(find.text('Verify your email'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.enterText(email, '');
    await tap(tester, find.text('Request another code'));
    expect(find.text('Enter your email first.'), findsOneWidget);
    await snap(
      tester,
      'verify-resend-email-required',
      'Clear email and resend → required email feedback',
    );
    await tester.enterText(email, 'inventory@example.test');
    transport.responsesByPath['/v1/auth/resend-verification'] = _error(
      'rate_limited',
      429,
    );
    await tap(tester, find.text('Request another code'));
    await snap(
      tester,
      'verify-resend-rate-limited',
      'Resend code → server rate limit',
    );
    transport.responsesByPath['/v1/auth/resend-verification'] = {
      'status': 'verification_if_required',
    };
    final gate = transport.gates['/v1/auth/resend-verification'] =
        Completer<void>();
    await tester.tap(find.text('Request another code'));
    await tester.pump(const Duration(milliseconds: 100));
    await snap(
      tester,
      'verify-resend-pending',
      'Resend code → request pending and form disabled',
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Check your inbox and spam folder for an 8-digit code. Codes expire in 15 minutes.',
      ),
      findsOneWidget,
    );
    await snap(
      tester,
      'verify-resend-success',
      'Resend accepted → success message',
    );
    await tester.enterText(code, '12345678');
    await tap(tester, submit);
    expect(find.text('Set your password'), findsOneWidget);
    await tester.enterText(password, 'Sample123');
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'Sample123',
    );
    await tap(tester, submit);
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await capture(
      tester,
      'verify-more',
      '/more',
      'Verify email → authenticated intended More route',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('auth language dismissal legal failure and back navigation', (
    tester,
  ) async {
    await mount(tester);
    await fill(tester);
    await snap(
      tester,
      'language-entry',
      'Signed out login with synthetic form draft',
    );
    await tap(tester, find.byKey(const ValueKey('auth-language-button')));
    await snap(
      tester,
      'language-sheet',
      'Language button → English selection sheet',
    );
    await tap(tester, find.widgetWithText(ListTile, 'English'));
    expect(
      tester.widget<TextFormField>(email).controller!.text,
      'inventory@example.test',
    );
    await snap(
      tester,
      'language-selected',
      'Select English → close sheet and preserve email/password draft',
    );
    await tap(tester, find.byKey(const ValueKey('auth-language-button')));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsNothing);
    await snap(
      tester,
      'language-dismissed',
      'Reopen language sheet → tap outside → login retained',
    );
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final attempts = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            attempts.add((call.arguments as Map)['url'] as String);
            return false;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    for (final label in ['Terms of Use', 'Privacy Policy.']) {
      await tap(tester, find.text(label));
      expect(
        find.text('Unable to open this page. Please try again.'),
        findsOneWidget,
      );
      await snap(
        tester,
        label.startsWith('Terms') ? 'terms-open-error' : 'privacy-open-error',
        'Tap $label → external browser launch fails → Snackbar',
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
    expect(attempts, [
      'https://momcozy.com/pages/terms-conditions',
      'https://momcozy.com/pages/privacy-security',
    ]);
    await tap(tester, find.byKey(const ValueKey('auth-forgot-button')));
    await snap(
      tester,
      'forgot-back-entry',
      'Login → forgot form with existing email',
    );
    await tap(tester, find.text('Back to sign in'));
    await snap(
      tester,
      'forgot-back-login',
      'Forgot form Back to sign in → draft retained',
    );
    await tap(tester, find.byKey(const ValueKey('auth-register-button')));
    await snap(tester, 'register-back-entry', 'Login → registration form');
    await tap(tester, find.text('Back to sign in'));
    await snap(
      tester,
      'register-back-login',
      'Register Back to sign in → login',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
