import 'dart:async';

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
        '/v1/auth/verify-registration-code': {'status': 'code_valid'},
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

  Future<void> mount(WidgetTester tester) async {
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
      for (final asset in ['auth_mother_baby.png', 'momcozy_logo.png']) {
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

  Future<void> verifyState(WidgetTester tester, String route) async {
    expect(router.state.uri.path, route);
    expect(tester.takeException(), isNull);
  }

  testWidgets('inventory real login → More → account → deletion → login', (
    tester,
  ) async {
    await mount(tester);
    await verifyState(tester, '/login');
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await verifyState(tester, '/login');
    expect(find.byKey(const ValueKey('auth-google-button')), findsNothing);
    await fill(tester);
    await tester.pump();
    await tap(tester, find.byKey(const ValueKey('auth-password-visibility')));
    await verifyState(tester, '/login');
    await tester.longPress(
      find.byKey(const ValueKey('auth-password-visibility')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hide password'), findsOneWidget);
    await verifyState(tester, '/login');
    Tooltip.dismissAllToolTips();
    await tester.pumpAndSettle();
    transport.responsesByPath['/v1/auth/login'] = _error(
      'authentication_required',
      401,
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    await verifyState(tester, '/login');
    transport.responsesByPath['/v1/auth/login'] = _error('rate_limited', 429);
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(
      find.text('Too many attempts. Please wait and try again.'),
      findsOneWidget,
    );
    await verifyState(tester, '/login');
    transport.responsesByPath['/v1/auth/login'] = _tokens;
    transport.loginGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await verifyState(tester, '/login');
    transport.loginGate!.complete();
    await tester.pumpAndSettle();
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await verifyState(tester, '/more');
    transport.responsesByPath['/v1/auth/me'] = _error('unavailable', 503);
    router.push('/account');
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await verifyState(tester, '/account');
    transport.responsesByPath['/v1/auth/me'] = _account;
    await tap(tester, find.text('Retry'));
    await verifyState(tester, '/account');
    expect(find.byKey(const ValueKey('account-delete')), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('account-delete')));
    await verifyState(tester, '/more');
    await tap(tester, find.text('Cancel'));
    await verifyState(tester, '/more');
    await tap(tester, find.byKey(const ValueKey('account-delete')));
    transport.writeResponsesByPath['/v1/auth/me'] = _error('unavailable', 503);
    await tap(tester, find.byKey(const ValueKey('account-confirm-delete')));
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await verifyState(tester, '/more');
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
    await verifyState(tester, '/login');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inventory registration verification resend and real sign out', (
    tester,
  ) async {
    await mount(tester);
    await tap(tester, find.byKey(const ValueKey('auth-register-button')));
    await verifyState(tester, '/login');
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'inventory@example.test',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Verify your email'), findsOneWidget);
    await verifyState(tester, '/login');
    expect(find.text('Request another code in 60s'), findsOneWidget);
    await verifyState(tester, '/login');
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(
      find.text('Enter the 8-digit code from your email.'),
      findsOneWidget,
    );
    await verifyState(tester, '/login');
    await tester.enterText(
      find.byKey(const ValueKey('auth-code-field')),
      '12345678',
    );
    transport.responsesByPath['/v1/auth/verify-registration-code'] = _error(
      'invalid_or_expired_code',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    await verifyState(tester, '/login');
    transport.responsesByPath['/v1/auth/verify-registration-code'] = {
      'status': 'code_valid',
    };
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Set your password'), findsOneWidget);
    await verifyState(tester, '/login');
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'Inventory123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'different123',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(find.text('Passwords do not match.'), findsOneWidget);
    await verifyState(tester, '/login');
    await tester.enterText(
      find.byKey(const ValueKey('auth-confirm-password-field')),
      'Inventory123',
    );
    await tap(tester, find.byKey(const ValueKey('auth-submit-button')));
    expect(runtime.currentSession.isAuthenticated, isTrue);
    await verifyState(tester, '/more');
    await tap(tester, find.byKey(const ValueKey('more-logout')));
    expect(await store.readSession(), isNull);
    await verifyState(tester, '/login');
    await tester.pumpWidget(const SizedBox());
  });
}
