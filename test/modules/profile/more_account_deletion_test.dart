import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import '../../support/fixture_api_transport.dart';

void main() {
  for (final (width, scale) in [(393.0, 1.0), (320.0, 2.0)]) {
    testWidgets('More owns account deletion at $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'mia',
        babyId: 'baby',
        locale: 'en-US',
        accessToken: 'access',
        refreshToken: 'refresh',
      );
      final transport = _DeletionTransport({
        'id': 'mia',
        'display_name': 'Mia Chen',
        'email': 'mia@example.com',
        'email_verified': true,
        'account_status': 'active',
        'auth_providers': ['email'],
        'status': 'deletion_pending',
      });
      final controller = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(session, jsonTransport: transport),
      );
      final store = MemoryMomCozySessionStore(session);
      final router = createMomCozyRouter(
        runtimeController: controller,
        sessionStore: store,
        initialLocation: '/more',
      );
      addTearDown(() {
        router.dispose();
        controller.dispose();
      });
      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          runtimeController: controller,
          sessionStore: store,
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/more');
      for (final removed in [
        'Account settings',
        'Notifications',
        'Expert support',
        'Everyday settings',
        'Expert care',
      ]) {
        expect(find.text(removed), findsNothing);
      }
      expect(find.text('Delete account'), findsOneWidget);
      final delete = find.byKey(const ValueKey('account-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      expect(find.text('Request account deletion'), findsOneWidget);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(transport.mutationPaths, isEmpty);
      expect(controller.currentSession.isAuthenticated, isTrue);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      transport.failDelete = true;
      transport.deleteGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('account-confirm-delete')));
      await tester.pump();
      expect(tester.widget<TextButton>(delete).onPressed, isNull);
      transport.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-message')), findsOneWidget);
      expect(controller.currentSession.isAuthenticated, isTrue);
      expect(await store.readSession(), isNotNull);
      expect(tester.widget<TextButton>(delete).onPressed, isNotNull);

      transport.failDelete = false;
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-confirm-delete')));
      await tester.pumpAndSettle();
      expect(transport.mutationPaths, ['/v1/auth/me', '/v1/auth/me']);
      expect(transport.lastMethod, 'DELETE');
      expect(await store.readSession(), isNull);
      expect(controller.currentSession.isAuthenticated, isFalse);
      expect(router.state.uri.path, '/login');
      expect(
        find.text(
          'Account access removed. Your data erasure request is pending.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}

class _DeletionTransport extends FixtureApiJsonTransport {
  _DeletionTransport(super.response);

  Completer<void>? deleteGate;
  bool failDelete = false;

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    await deleteGate?.future;
    deleteGate = null;
    if (failDelete) {
      mutationPaths.add(path);
      throw ApiHttpException.fromBody({
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable'},
        },
      });
    }
    return super.deleteJson(path, headers: headers);
  }
}
