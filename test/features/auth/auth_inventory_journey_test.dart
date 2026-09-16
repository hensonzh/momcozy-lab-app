import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
        '/v1/auth/resend-verification': {'status': 'verification_if_required'},
        '/v1/auth/forgot-password': {'status': 'reset_if_available'},
        '/v1/auth/reset-password': {'status': 'reset'},
      }, writeResponsesByPath: <String, Map<String, Object?>>{});
  Completer<void>? loginGate;
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path == '/v1/auth/login') await loginGate?.future;
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
  final steps = <Map<String, Object?>>[];

  Future<void> mount(WidgetTester tester) async {
    previous = null;
    steps.clear();
    tester.view.physicalSize = const Size(393, 844);
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
        'google_sign_in.png',
      ]) {
        await precacheImage(AssetImage('assets/images/$asset'), context);
      }
    });
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    addTearDown(() async {
      // Do not leave pending fixture work or route subscriptions behind.
      if (transport.loginGate case final gate? when !gate.isCompleted) {
        gate.complete();
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
    final source = 'test/goldens/ui_inventory/$state-393.png';
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/ui_inventory/$state-393.png'),
    );
    steps.add({
      'source': source,
      'previous_source': previous,
      'route': route,
      'trigger': action,
      'root_entry': 'Open More while signed out → real auth redirect',
      'evidence':
          'Actual MomCozyFlutterApp and createMomCozyRouter; only HTTP/session/native-intent dependencies replaced with isolated fixtures',
      'test': 'test/features/auth/auth_inventory_journey_test.dart',
    });
    previous = source;
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/$state.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(steps.last)}\n',
      );
    }
  }

  testWidgets('inventory real login → More → account → deletion → login', (
    tester,
  ) async {
    await mount(tester);
    await capture(
      tester,
      'auth-journey-login',
      '/login',
      'Anonymous open /more; guard redirects to login with return location',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await capture(
      tester,
      'auth-journey-empty-validation',
      '/login',
      'Submit empty email and password',
    );
    await tap(tester, find.byKey(const ValueKey('auth-google-button')));
    expect(
      find.text('Google sign-in is unavailable. Try again or use email.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'auth-journey-google-unavailable',
      '/login',
      'Continue with Google; current build has no client ID',
    );
    await fill(tester);
    await tap(tester, find.byKey(const ValueKey('auth-password-visibility')));
    await capture(
      tester,
      'auth-journey-password-visible',
      '/login',
      'Tap password eye; synthetic password is visible',
    );
    await tester.longPress(
      find.byKey(const ValueKey('auth-password-visibility')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hide password'), findsOneWidget);
    await capture(
      tester,
      'auth-journey-password-tooltip',
      '/login',
      'Long press password eye → native Flutter Tooltip',
    );
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    transport.responsesByPath['/v1/auth/login'] = _error(
      'authentication_required',
      401,
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    await capture(
      tester,
      'auth-journey-invalid-credentials',
      '/login',
      'Sign in; backend returns authentication_required',
    );
    transport.responsesByPath['/v1/auth/login'] = _error('rate_limited', 429);
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(
      find.text('Too many attempts. Please wait and try again.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'auth-journey-rate-limit',
      '/login',
      'Retry sign in; backend returns HTTP 429',
    );
    transport.responsesByPath['/v1/auth/login'] = _tokens;
    transport.loginGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await capture(
      tester,
      'auth-journey-login-busy',
      '/login',
      'Sign in; HTTP response is still pending',
    );
    transport.loginGate!.complete();
    await tester.pumpAndSettle();
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await capture(
      tester,
      'account-journey-more',
      '/more',
      'Successful login saves session; guard restores More',
    );
    transport.responsesByPath['/v1/auth/me'] = _error('unavailable', 503);
    await tap(tester, find.text('账号设置'));
    expect(find.text('Retry'), findsOneWidget);
    await capture(
      tester,
      'account-journey-load-error',
      '/account',
      'More → Account settings; account request fails',
    );
    transport.responsesByPath['/v1/auth/me'] = _account;
    await tap(tester, find.text('Retry'));
    await capture(
      tester,
      'account-journey-loaded',
      '/account',
      'Retry → actual account details',
    );
    await tap(tester, find.byKey(const ValueKey('account-link-google')));
    await capture(
      tester,
      'account-journey-link-confirm',
      '/account',
      'Link Google account → password confirmation dialog',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-link-password')),
      'Inventory123',
    );
    await tap(tester, find.text('Continue'));
    expect(
      find.text('Google sign-in is unavailable. Try again or use email.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'account-journey-link-unavailable',
      '/account',
      'Confirm password → Google unavailable in current build',
    );
    await tap(tester, find.byKey(const ValueKey('account-delete')));
    await capture(
      tester,
      'account-journey-delete-confirm',
      '/account',
      'Request account deletion → confirmation',
    );
    await tap(tester, find.text('Cancel'));
    await capture(
      tester,
      'account-journey-delete-cancelled',
      '/account',
      'Cancel → account remains available',
    );
    await tap(tester, find.byKey(const ValueKey('account-delete')));
    transport.writeResponsesByPath['/v1/auth/me'] = _error('unavailable', 503);
    await tap(tester, find.byKey(const ValueKey('account-confirm-delete')));
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await capture(
      tester,
      'account-journey-delete-error',
      '/account',
      'Confirm delete → isolated HTTP failure, session retained',
    );
    await tap(tester, find.byKey(const ValueKey('account-delete')));
    transport.writeResponsesByPath['/v1/auth/me'] = {
      'status': 'deletion_pending',
    };
    await tap(tester, find.byKey(const ValueKey('account-confirm-delete')));
    expect(await store.readSession(), isNull);
    expect(
      find.text(
        'Account access removed. Your data erasure request is pending.',
      ),
      findsOneWidget,
    );
    await capture(
      tester,
      'auth-journey-deleted',
      '/login',
      'Confirm delete → fixture success → session cleared → login plus deletion Snackbar',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory registration verification resend and real sign out', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.text('Create an account'));
    await capture(
      tester,
      'auth-journey-register',
      '/login',
      'Login → Create an account',
    );
    await fill(tester);
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Verify your email'), findsOneWidget);
    await capture(
      tester,
      'auth-journey-verify',
      '/login',
      'Submit registration → backend verification_required → verify form',
    );
    await tap(tester, find.text('Resend code'));
    expect(
      find.text('Please wait 60 seconds before requesting another code.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'auth-journey-resend-cooldown',
      '/login',
      'Immediately resend → cooldown message',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(
      find.text('Enter the 8-digit code from your email.'),
      findsOneWidget,
    );
    await capture(
      tester,
      'auth-journey-code-validation',
      '/login',
      'Submit without eight-digit code → field validation',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    transport.responsesByPath['/v1/auth/verify-email'] = _error(
      'invalid_or_expired_code',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    await capture(
      tester,
      'auth-journey-code-expired',
      '/login',
      'Verify email → invalid_or_expired_code',
    );
    transport.responsesByPath['/v1/auth/verify-email'] = _tokens;
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await capture(
      tester,
      'account-journey-verified-more',
      '/more',
      'Valid verification → session saved → intended More route',
    );
    await tap(tester, find.text('账号设置'));
    await tap(tester, find.byKey(const ValueKey('account-sign-out')));
    expect(await store.readSession(), isNull);
    await capture(
      tester,
      'auth-journey-signed-out',
      '/login',
      'More → Account settings → Sign out → anonymous login',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
