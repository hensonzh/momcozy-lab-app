import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_delivery_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import '../support/notification_fakes.dart';

void main() {
  testWidgets(
    'baby changes and token refresh preserve notification login identity',
    (tester) async {
      const session = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'account-one',
        babyId: 'baby-one',
        locale: 'en',
        accessToken: 'access-one',
        refreshToken: 'refresh-one',
      );
      final store = MemoryMomCozySessionStore(session);
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime.fromSession(session),
      );
      final notifications = _RecordingCoordinator();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
        ],
      );
      addTearDown(runtime.dispose);
      addTearDown(notifications.dispose);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MomCozyFlutterApp(
          runtimeController: runtime,
          notificationCoordinator: notifications,
          sessionStore: store,
          router: router,
        ),
      );
      await tester.pumpAndSettle();
      final originalKey = notifications.keys.last;
      final originalRepository = notifications.repositories.last;
      expect(originalKey, isNotNull);

      await runtime.selectBaby('baby-two');
      await tester.pumpAndSettle();
      expect(runtime.currentSession.babyId, 'baby-two');
      expect(notifications.keys.last, originalKey);
      expect(notifications.backend.events, isNot(contains('detach')));
      expect(notifications.repositories.last, isNot(same(originalRepository)));

      runtime.replaceSession(
        runtime.currentSession.copyWith(
          accessToken: 'access-rotated',
          refreshToken: 'refresh-rotated',
        ),
      );
      // Rebuilding again must use the same identity even after secret rotation.
      await runtime.selectBaby('baby-three');
      await tester.pumpAndSettle();
      expect(notifications.keys.last, originalKey);
      expect(notifications.backend.events, isNot(contains('detach')));
      expect(notifications.pushReady, isTrue);

      // A new login to the same user is a different device session.
      await runtime.saveAuthenticatedSession(
        session.copyWith(accessToken: 'new-login', refreshToken: 'new-refresh'),
        sessionStore: store,
      );
      await tester.pumpAndSettle();
      final nextKey = notifications.keys.last;
      expect(nextKey, isNot(originalKey));
      expect(
        notifications.backend.events.where((e) => e == 'detach'),
        hasLength(1),
      );

      runtime.replaceSession(runtime.currentSession.loggedOut());
      await tester.pumpAndSettle();
      expect(notifications.keys.last, isNull);
      expect(notifications.inbox, isNull);
      expect(
        notifications.backend.events.where((e) => e == 'detach'),
        hasLength(2),
      );
      await runtime.saveAuthenticatedSession(
        session.copyWith(userId: 'account-two'),
        sessionStore: store,
      );
      await tester.pumpAndSettle();
      expect(
        notifications.keys.last,
        isNot(anyOf(originalKey, nextKey, isNull)),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _RecordingCoordinator extends NotificationCoordinator {
  _RecordingCoordinator()
    : super(
        permission: NotificationPermissionController(
          FakePlatform()..value = NotificationPermission.authorized,
        ),
        gateway: FakeGateway(),
        store: FakeStore(),
        platformName: 'ios',
        onNavigate: (_) {},
        onMessage: (_) {},
        onForeground: (_) {},
      );
  final keys = <String?>[];
  final repositories = <NotificationsRepository?>[];
  final backend = FakeRepository();

  @override
  Future<void> setAccount({
    required String? key,
    NotificationsRepository? inboxRepository,
    NotificationDeliveryRepository? deliveryRepository,
    String locale = 'en',
  }) async {
    keys.add(key);
    repositories.add(inboxRepository);
    await super.setAccount(
      key: key,
      inboxRepository: backend,
      deliveryRepository: backend,
      locale: locale,
    );
  }
}
