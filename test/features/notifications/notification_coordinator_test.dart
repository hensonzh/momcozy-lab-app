import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_delivery_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/push_messaging.dart';
import '../../support/notification_fakes.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';

void main() {
  late FakePlatform platform;
  late FakeGateway gateway;
  late FakeStore store;
  late FakeRepository repository;
  late NotificationCoordinator coordinator;
  late List<String> routes;
  setUp(() {
    platform = FakePlatform();
    gateway = FakeGateway();
    store = FakeStore();
    repository = FakeRepository();
    routes = [];
    coordinator = NotificationCoordinator(
      permission: NotificationPermissionController(platform),
      gateway: gateway,
      store: store,
      platformName: 'android',
      onNavigate: routes.add,
      onMessage: (_) {},
      onForeground: (_) {},
    );
  });
  tearDown(() => coordinator.dispose());
  Future<void> login() => coordinator.setAccount(
    key: 'user-session',
    inboxRepository: repository,
    deliveryRepository: repository,
  );
  test('same-session runtime rebuild during startup does not detach', () async {
    platform.value = NotificationPermission.authorized;
    final starting = login();
    final replacement = FakeRepository();
    await coordinator.setAccount(
      key: 'user-session',
      inboxRepository: replacement,
      deliveryRepository: replacement,
    );
    await starting;

    expect(repository.events, isEmpty);
    expect(replacement.events, ['register:authorized']);
    expect(coordinator.pushReady, isTrue);
    expect(gateway.pauses, 1);
    expect(coordinator.inbox!.repository, same(replacement));
  });
  test(
    'same-session dependencies update without detaching or clearing inbox',
    () async {
      platform.value = NotificationPermission.authorized;
      await login();
      final inbox = coordinator.inbox;
      final pauses = gateway.pauses;
      final revision = store.revision;
      final replacement = FakeRepository()
        ..reminderValue = const AppointmentReminder(
          enabled: true,
          status: 'scheduled',
        );

      await coordinator.setAccount(
        key: 'user-session',
        inboxRepository: replacement,
        deliveryRepository: replacement,
        locale: 'fr',
      );

      expect(repository.events, isNot(contains('detach')));
      expect(gateway.pauses, pauses);
      expect(store.revision, revision);
      expect(coordinator.pushReady, isTrue);
      expect(coordinator.inbox, same(inbox));
      expect(coordinator.inbox!.repository, same(replacement));
      expect((await coordinator.reminder('appointment'))!.enabled, isTrue);
      await coordinator.refresh();
      expect(replacement.events, ['register:authorized']);
      expect(replacement.lastLocale, 'fr');
    },
  );
  test(
    'server provider disabled cannot look like an enabled push channel',
    () async {
      platform.value = NotificationPermission.authorized;
      repository.serverPushAvailable = false;
      await login();
      expect(coordinator.pushReady, isFalse);
      expect(coordinator.error, contains('not available'));
    },
  );
  test(
    're-login reserves the detach revision and binds on the first attempt',
    () async {
      platform.value = NotificationPermission.authorized;
      await login();
      await coordinator.setAccount(key: null);
      await coordinator.setAccount(
        key: 'new-session',
        inboxRepository: repository,
        deliveryRepository: repository,
      );
      expect(coordinator.pushReady, isTrue);
      expect(repository.lastRevision, store.revision);
    },
  );
  test('an expired session preserves an inbox click until login', () async {
    await login();
    repository.openError = const ApiHttpException(
      statusCode: 401,
      statusText: 'Unauthorized',
      body: null,
    );
    await coordinator.openInboxNotification(
      '11111111-1111-1111-1111-111111111111',
    );
    expect(
      store.pending?.notificationId,
      '11111111-1111-1111-1111-111111111111',
    );
    expect(routes.last, '/login');
    repository.openError = null;
    await coordinator.setAccount(
      key: 'renewed-session',
      inboxRepository: repository,
      deliveryRepository: repository,
    );
    expect(store.pending, isNull);
    expect(routes.last, startsWith('/services/appointments/'));
  });
  test(
    'offline click survives retry and payload cannot supply an external route',
    () async {
      await login();
      repository.openError = StateError('offline');
      await coordinator.openInboxNotification('n1');
      expect(store.pending, isNotNull);
      repository.openError = null;
      repository.targetRoute = 'https://attacker.invalid';
      await coordinator.refresh();
      expect(routes, isEmpty);
      expect(store.pending, isNull);
    },
  );
  test('foreground banner requires the current account binding', () async {
    final foreground = <NotificationPushIntent>[];
    coordinator.dispose();
    coordinator = NotificationCoordinator(
      permission: NotificationPermissionController(platform),
      gateway: gateway = FakeGateway(),
      store: store,
      platformName: 'android',
      onNavigate: routes.add,
      onMessage: (_) {},
      onForeground: foreground.add,
    );
    platform.value = NotificationPermission.authorized;
    await login();
    gateway.foreground.add(
      const NotificationPushIntent(notificationId: 'n1', bindingId: 'foreign'),
    );
    gateway.foreground.add(
      const NotificationPushIntent(notificationId: 'n2', bindingId: 'binding'),
    );
    await Future<void>.delayed(Duration.zero);
    await coordinator.idle();
    expect(foreground.map((value) => value.notificationId), ['n2']);
  });
  test(
    'startup checks only; consent and token registration precede executable reminder',
    () async {
      await login();
      expect(platform.requests, 0);
      expect(gateway.tokenCalls, 0);
      expect(
        await coordinator.setReminder(
          'appointment',
          enabled: true,
          explain: () async => true,
          offerSettings: () async => false,
        ),
        isTrue,
      );
      expect(platform.requests, 1);
      expect(
        repository.events,
        containsAllInOrder(['register:authorized', 'reminder:true']),
      );
      await coordinator.setReminder(
        'appointment',
        enabled: true,
        explain: () => throw StateError('repeat education'),
        offerSettings: () async => false,
      );
      expect(platform.requests, 1);
    },
  );
  test(
    'denial prevents tasks; settings recovery enables only after fresh OS check',
    () async {
      platform.next = NotificationPermission.denied;
      await login();
      expect(
        await coordinator.setReminder(
          'a',
          enabled: true,
          explain: () async => true,
          offerSettings: () async => false,
        ),
        isFalse,
      );
      expect(
        repository.events.where((e) => e.startsWith('reminder:')),
        isEmpty,
      );
      await coordinator.setReminder(
        'a',
        enabled: true,
        explain: () async => true,
        offerSettings: () async => true,
      );
      expect(platform.requests, 1);
      expect(platform.settings, 1);
      platform.value = NotificationPermission.authorized;
      await coordinator.refresh();
      expect(coordinator.pushReady, isTrue);
      platform.value = NotificationPermission.denied;
      await coordinator.refresh();
      expect(coordinator.pushReady, isFalse);
      expect(repository.events.last, 'register:denied');
    },
  );
  test('missing provider or token never creates a sendable task', () async {
    platform.value = NotificationPermission.authorized;
    gateway.available = false;
    await login();
    expect(
      await coordinator.setReminder(
        'a',
        enabled: true,
        explain: () async => true,
        offerSettings: () async => false,
      ),
      isFalse,
    );
    expect(repository.events.where((e) => e.startsWith('reminder:')), isEmpty);
  });
  test(
    'cold click persists through login; route comes from authenticated API',
    () async {
      const intent = NotificationPushIntent(
        notificationId: 'n1',
        bindingId: 'old-binding',
      );
      gateway.initial = intent;
      await coordinator.start();
      expect(store.pending, intent);
      expect(routes, ['/login']);
      await login();
      expect(
        routes.last,
        '/services/appointments/11111111-1111-1111-1111-111111111111',
      );
      expect(repository.opened, ['n1']);
      expect(store.pending, isNull);
    },
  );
  test(
    'logout clears inbox and system alerts; a late registration cannot restore account',
    () async {
      platform.value = NotificationPermission.authorized;
      repository.registrationWait = Completer<PushRegistration>();
      final signingIn = login();
      await Future<void>.delayed(Duration.zero);
      final signingOut = coordinator.setAccount(key: null);
      repository.registrationWait!.complete(
        const PushRegistration(
          bindingId: 'old',
          tokenRegistered: true,
          pushAvailable: true,
        ),
      );
      await signingIn;
      await signingOut;
      expect(coordinator.inbox, isNull);
      expect(coordinator.pushReady, isFalse);
      expect(platform.clears, greaterThan(0));
      expect(gateway.pauses, greaterThan(0));
    },
  );
  test(
    'token refresh rechecks permission; stale foreground push is ignored',
    () async {
      platform.value = NotificationPermission.authorized;
      await login();
      platform.value = NotificationPermission.denied;
      gateway.tokens.add('rotated-token');
      await coordinator.idle();
      await Future<void>.delayed(Duration.zero);
      await coordinator.idle();
      expect(repository.events.last, 'register:denied');
      expect(coordinator.pushReady, isFalse);
    },
  );
}
