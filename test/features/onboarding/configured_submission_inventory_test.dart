@Tags(['golden'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

// Fixed G11 gaps only. Run with --dart-define=MOMCOZY_INTERNAL_INVITE_LOGIN=true.
void main() {
  setUpAll(loadMomCozyTestFonts);
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> mount(
    WidgetTester tester,
    MomCozyRuntimeController runtime,
    GoRouter router,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeRouteIntentPlatform();
    addTearDown(platform.dispose);
    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        runtimeController: runtime,
        routeIntentPlatform: platform,
        sessionStore: MemoryMomCozySessionStore(runtime.currentSession),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage(
          'assets/images/me_baby_overview/postpartum_avatar.png',
        ),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    GoRouter router,
    String name,
    String trigger, {
    String? previous,
  }) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/ui_inventory/$name-390.png'),
    );
    final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
    if (output != null) {
      final file = File('$output/journeys/$name.json');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode({
          'source': 'test/goldens/ui_inventory/$name-390.png',
          'previous_source': previous,
          'route': router.state.uri.path,
          'trigger': trigger,
          'root_entry': 'Configured App entry; real createMomCozyRouter',
          'evidence':
              'Production pages, repositories and router; fixture HTTP and image picker; not an OS picker screenshot',
          'test':
              'test/features/onboarding/configured_submission_inventory_test.dart',
        }),
      );
    }
  }

  testWidgets(
    'inventory configured invite submission pending',
    (tester) async {
      final transport = _PendingInvite();
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          supportsSessionAutoRefresh: false,
        ),
      );
      final store = MemoryMomCozySessionStore();
      final router = createMomCozyRouter(
        initialLocation: '/login?from=/more',
        runtimeController: runtime,
        sessionStore: store,
      );
      addTearDown(() {
        router.dispose();
        runtime.dispose();
      });
      await mount(tester, runtime, router);
      await tester.enterText(
        find.byKey(const ValueKey('auth-invite-code-field')),
        'INVENTORY-CODE',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-invite-login-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await capture(
        tester,
        router,
        'auth-invite-submit-pending',
        'Configured invitation login → enter code → submit; response pending',
      );
      transport.ready.complete();
      await tester.pumpAndSettle();
      expect(runtime.currentSession.isAuthenticated, isTrue);
      expect(router.state.uri.path, '/more');
      expect(transport.postedBodies, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('MOMCOZY_INTERNAL_INVITE_LOGIN'),
  );

  testWidgets(
    'inventory configured invitation failure outcomes',
    (tester) async {
      final transport = FixtureApiJsonTransport({
        'http_status': 403,
        'body': {
          'error': {
            'code': 'permission_denied',
            'message': 'Invite code is already bound to another device.',
          },
        },
      });
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          supportsSessionAutoRefresh: false,
        ),
      );
      final store = _RecoverableSessionStore();
      final router = createMomCozyRouter(
        initialLocation: '/login?from=/more',
        runtimeController: runtime,
        sessionStore: store,
      );
      addTearDown(() {
        router.dispose();
        runtime.dispose();
      });
      await mount(tester, runtime, router);
      await tester.enterText(
        find.byKey(const ValueKey('auth-invite-code-field')),
        'INVENTORY-CODE',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('auth-invite-login-button'));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This invitation code has already been used on another device.',
        ),
        findsOneWidget,
      );
      await capture(
        tester,
        router,
        'auth-invite-device-error',
        'Invite submit rejected → code retained and device message displayed',
      );
      transport.response
        ..clear()
        ..addAll(_PendingInvite().response);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your account was verified, but we could not save your sign-in on this device. Restart the app and try again.',
        ),
        findsOneWidget,
      );
      expect(runtime.currentSession.isAuthenticated, isFalse);
      await capture(
        tester,
        router,
        'auth-invite-storage-error',
        'Retry accepted by server → local session save fails; remains logged out',
        previous: 'test/goldens/ui_inventory/auth-invite-device-error-390.png',
      );
      store.failWrite = false;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(runtime.currentSession.isAuthenticated, isTrue);
      expect(router.state.uri.path, '/more');
      await tester.pumpWidget(const SizedBox());
    },
    skip: !const bool.fromEnvironment('MOMCOZY_INTERNAL_INVITE_LOGIN'),
  );
}

class _PendingInvite extends FixtureApiJsonTransport {
  _PendingInvite()
    : super({
        'access_token': 'fixture-access',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'token_type': 'bearer',
        'user': {'id': 'inventory-invite', 'display_name': 'Inventory'},
      });
  final ready = Completer<void>();
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await ready.future;
    return super.postJson(path, body: body, headers: headers);
  }
}

class _RecoverableSessionStore extends MemoryMomCozySessionStore {
  bool failWrite = true;
  @override
  Future<void> writeSession(MomCozySession session) async {
    if (failWrite) throw StateError('fixture session storage unavailable');
    await super.writeSession(session);
  }
}
