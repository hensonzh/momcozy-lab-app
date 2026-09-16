import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_delivery_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/appointment_reminder_tile.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_coordinator.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_settings_page.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_scope.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_page.dart';
import '../../support/notification_fakes.dart'
    show FakePlatform, FakeGateway, FakeStore, FakeRepository;

void main() {
  testWidgets('first reminder uses education and denial leaves it off', (
    tester,
  ) async {
    final platform = FakePlatform()..next = NotificationPermission.denied;
    final repository = FakeRepository();
    final coordinator = _coordinator(platform);
    addTearDown(coordinator.dispose);
    await coordinator.setAccount(
      key: 'account',
      inboxRepository: repository,
      deliveryRepository: repository,
    );
    await tester.pumpWidget(
      NotificationScope(
        coordinator: coordinator,
        child: const MaterialApp(
          home: Scaffold(
            body: AppointmentReminderTile(appointmentId: 'appointment'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Receive reminders?'), findsOneWidget);
    expect(platform.requests, 0);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(platform.requests, 1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      repository.events.where((value) => value == 'reminder:true'),
      isEmpty,
    );
  });
  testWidgets('restored OS permission reloads the backend reminder state', (
    tester,
  ) async {
    final platform = FakePlatform()..value = NotificationPermission.denied;
    final repository = FakeRepository();
    final coordinator = _coordinator(platform);
    addTearDown(coordinator.dispose);
    await coordinator.setAccount(
      key: 'account',
      inboxRepository: repository,
      deliveryRepository: repository,
    );
    await tester.pumpWidget(
      NotificationScope(
        coordinator: coordinator,
        child: const MaterialApp(
          home: Scaffold(
            body: AppointmentReminderTile(appointmentId: 'appointment'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    platform.value = NotificationPermission.authorized;
    repository.reminderValue = const AppointmentReminder(
      enabled: true,
      status: 'scheduled',
    );
    await coordinator.refresh();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });
  testWidgets(
    'settings entry reads OS state without prompting and separates marketing',
    (tester) async {
      final platform = FakePlatform()..value = NotificationPermission.denied;
      final repository = FakeRepository();
      final coordinator = _coordinator(platform);
      addTearDown(coordinator.dispose);
      await coordinator.setAccount(
        key: 'account',
        inboxRepository: repository,
        deliveryRepository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(home: NotificationSettingsPage(coordinator: coordinator)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Off in system settings'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Marketing'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Marketing'), findsOneWidget);
      expect(platform.requests, 0);
      await tester.scrollUntilVisible(find.text('Settings'), -200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(platform.settings, 1);
      expect(platform.requests, 0);
    },
  );
  testWidgets('inbox load-more and read-all use the full server unread count', (
    tester,
  ) async {
    final repository = PagingRepository();
    final controller = NotificationsController(repository: repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationsPage(
            repository: repository,
            controller: controller,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('73 unread'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(controller.state.notifications.map((value) => value.id), ['1', '2']);
    expect(find.text('73 unread'), findsOneWidget);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });
}

NotificationCoordinator _coordinator(FakePlatform platform) =>
    NotificationCoordinator(
      permission: NotificationPermissionController(platform),
      gateway: FakeGateway(),
      store: FakeStore(),
      platformName: 'android',
      onNavigate: (_) {},
      onMessage: (_) {},
      onForeground: (_) {},
    );

class PagingRepository extends FakeRepository {
  bool read = false;
  MomCozyNotification item(String id) => MomCozyNotification(
    id: id,
    type: 'system',
    title: 'Update $id',
    body: '',
    status: read ? 'read' : 'unread',
    source: 'care',
    payload: const {},
  );
  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => NotificationPageData(
    items: cursor == null ? [item('1')] : [item('1'), item('2')],
    unreadCount: read ? 0 : 73,
    nextCursor: cursor == null ? 'next' : null,
  );
  @override
  Future<void> markAllRead() async {
    read = true;
  }
}
