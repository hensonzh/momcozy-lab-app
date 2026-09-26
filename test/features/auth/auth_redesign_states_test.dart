import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_device_id.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';

const _tokens = <String, Object?>{
  'access_token': 'access',
  'refresh_token': 'refresh',
  'expires_in': 900,
  'user': {'id': 'mia'},
};
ApiHttpException _error(String code) => ApiHttpException(
  statusCode: 400,
  statusText: '',
  body: {
    'error': {'code': code, 'message': 'fixture'},
  },
);

class _Transport implements ApiJsonTransport {
  Future<Map<String, Object?>> Function(String) respond = (_) async => _tokens;
  final paths = <String>[];
  final bodies = <Map<String, Object?>>[];
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async => {};
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    paths.add(path);
    bodies.add(body);
    return respond(path);
  }
}

class _Device implements MomCozyAuthDeviceIdStore {
  @override
  Future<String> readOrCreateDeviceId() async => 'device';
}

class _FailStore extends MemoryMomCozySessionStore {
  @override
  Future<void> writeSession(MomCozySession session) async =>
      throw StateError('disk');
}

void main() {
  setUpAll(loadMomCozyTestFonts);
  Future<MomCozyRuntimeController> mount(
    WidgetTester t,
    _Transport api, {
    MomCozySessionStore? store,
  }) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: api),
    );
    addTearDown(runtime.dispose);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: MomCozyAuthPage(
          runtimeController: runtime,
          sessionStore: store ?? MemoryMomCozySessionStore(),
          authDeviceIdStore: _Device(),
          internalInviteOnly: false,
        ),
      ),
    );
    await t.runAsync(() async {
      final c = t.element(find.byType(MaterialApp));
      await Future.wait([
        precacheImage(
          const AssetImage('assets/images/auth_mother_baby.png'),
          c,
        ),
      ]);
    });
    await t.pumpAndSettle();
    return runtime;
  }

  Finder key(String name) => find.byKey(ValueKey('auth-$name'));
  Future<void> tap(WidgetTester t, Finder f, {bool settle = true}) async {
    await t.pumpAndSettle();
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump();
    }
    expect(t.takeException(), isNull);
  }

  Future<void> fill(WidgetTester t) async {
    await t.enterText(key('email-field'), 'mia@example.com');
    await t.enterText(key('password-field'), 'secret123');
  }

  Future<void> capture(
    WidgetTester t,
    String name,
    Finder f, {
    bool busy = false,
  }) async {
    await t.ensureVisible(f);
    if (busy) {
      await t.pump(const Duration(milliseconds: 300));
    } else {
      await t.pumpAndSettle();
    }
    expect(t.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/auth-$name-320-2x-short.png',
      ),
    );
  }

  void locked(WidgetTester t) {
    expect(t.widget<FilledButton>(key('submit-button')).onPressed, isNull);
    expect(t.widget<TextFormField>(key('email-field')).enabled, isFalse);
    expect(t.widget<TextFormField>(key('password-field')).enabled, isFalse);
    expect(t.widget<IconButton>(key('password-visibility')).onPressed, isNull);
  }

  testWidgets(
    'short large login locks pending request then retries retained fields',
    (t) async {
      final api = _Transport(), pending = Completer<Map<String, Object?>>();
      api.respond = (_) => pending.future;
      final store = MemoryMomCozySessionStore();
      await mount(t, api, store: store);
      await fill(t);
      await tap(t, key('submit-button'), settle: false);
      locked(t);
      expect(api.paths, ['/v1/auth/login']);
      await capture(t, 'busy', key('submit-button'), busy: true);
      pending.completeError(_error('authentication_required'));
      await t.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(
        t.widget<TextFormField>(key('password-field')).controller!.text,
        'secret123',
      );
      await capture(t, 'login-error', key('error-text'));
      api.respond = (_) async => _tokens;
      await tap(t, key('submit-button'));
      expect(api.paths.length, 2);
      expect((await store.readSession())?.userId, 'mia');
    },
  );
  testWidgets(
    'short large verification rejects invalid code and preserves cooldown and expired state',
    (t) async {
      final api = _Transport();
      api.respond = (p) async {
        if (p.endsWith('verify-registration-code')) {
          throw _error('invalid_or_expired_code');
        }
        return {'status': 'verification_required'};
      };
      final runtime = await mount(t, api);
      await tap(t, find.byKey(const ValueKey('auth-register-button')));
      await t.enterText(key('email-field'), 'mia@example.com');
      await tap(t, key('submit-button'));
      await t.enterText(key('code-field'), '123');
      await tap(t, key('submit-button'));
      expect(api.paths, ['/v1/auth/register']);
      await capture(
        t,
        'code-validation',
        find.text('Enter the 8-digit code from your email.'),
      );
      expect(find.text('Request another code in 60s'), findsOneWidget);
      expect(api.paths.length, 1);
      await capture(t, 'resend-cooldown', key('success-text'));
      await t.enterText(key('code-field'), '12345678');
      await tap(t, key('submit-button'));
      expect(api.paths.last, '/v1/auth/verify-registration-code');
      expect(runtime.currentSession.isAuthenticated, isFalse);
      await capture(t, 'code-expired', key('error-text'));
      await tap(t, find.text('Back to sign in'));
      expect(find.text('Momcozy'), findsOneWidget);
    },
  );
  testWidgets(
    'short large resend keeps missing email guard and disables actions while pending',
    (t) async {
      final api = _Transport();
      api.respond = (p) async {
        if (p.endsWith('/login')) throw _error('email_unverified');
        return {'status': 'verification_if_required'};
      };
      await mount(t, api);
      await tap(t, key('register-button'));
      await t.enterText(key('email-field'), 'mia@example.com');
      await tap(t, key('submit-button'));
      expect(api.paths, ['/v1/auth/register']);
      await t.pump(const Duration(seconds: 61));
      await t.enterText(key('email-field'), '');
      await tap(t, find.text('Request another code'));
      expect(api.paths, ['/v1/auth/register']);
      expect(find.text('Enter your email first.'), findsOneWidget);
      await t.enterText(key('email-field'), 'mia@example.com');
      final pending = Completer<Map<String, Object?>>();
      api.respond = (_) => pending.future;
      await tap(t, find.text('Request another code'), settle: false);
      expect(t.widget<FilledButton>(key('submit-button')).onPressed, isNull);
      expect(t.widget<TextFormField>(key('email-field')).enabled, isFalse);
      expect(t.widget<TextFormField>(key('code-field')).enabled, isFalse);
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Back to sign in'),
            )
            .onPressed,
        isNull,
      );
      await capture(t, 'resend-busy', key('submit-button'), busy: true);
      pending.complete({'status': 'verification_if_required'});
      await t.pumpAndSettle();
      expect(
        find.text(
          'If this email is eligible, check your inbox and spam folder. A request within 60 seconds may not send another code.',
        ),
        findsOneWidget,
      );
      expect(api.paths, ['/v1/auth/register', '/v1/auth/resend-verification']);
      expect(find.text('Request another code in 60s'), findsOneWidget);
    },
  );
  testWidgets(
    'short large login omits Google and keeps email recovery available',
    (t) async {
      final api = _Transport();
      await mount(t, api);
      expect(key('google-button'), findsNothing);
      expect(find.text('OR'), findsNothing);
      expect(api.paths, isEmpty);
      await fill(t);
      await tap(t, key('submit-button'));
      expect(api.paths, ['/v1/auth/login']);
    },
  );
  testWidgets(
    'session persistence failure revokes issued token and keeps retry form',
    (t) async {
      final api = _Transport();
      final runtime = await mount(t, api, store: _FailStore());
      await fill(t);
      await tap(t, key('submit-button'));
      expect(api.paths, ['/v1/auth/login', '/v1/auth/logout-session']);
      expect(api.bodies.last['refresh_token'], 'refresh');
      expect(runtime.currentSession.isAuthenticated, isFalse);
      await capture(t, 'storage-error', key('error-text'));
      expect(t.widget<FilledButton>(key('submit-button')).onPressed, isNotNull);
    },
  );
}
