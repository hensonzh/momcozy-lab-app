import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_controller.dart';

void main() {
  test('loads notifications, marks one read, and archives it', () async {
    final repository = _FakeNotificationsRepository();
    final controller = NotificationsController(repository: repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state.notifications.single.isUnread, isTrue);
    expect(controller.state.phase, NotificationsPhase.data);

    await controller.markRead('notification-1');

    expect(repository.readNotificationId, 'notification-1');
    expect(controller.state.notifications.single.isUnread, isFalse);

    await controller.archive('notification-1');

    expect(repository.archivedNotificationId, 'notification-1');
    expect(controller.state.notifications, isEmpty);
  });

  test('keeps loaded notifications visible when refresh fails', () async {
    final repository = _FakeNotificationsRepository();
    final controller = NotificationsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    repository.error = StateError('offline');

    await controller.load();

    expect(controller.state.phase, NotificationsPhase.error);
    expect(controller.state.notifications, hasLength(1));
    expect(controller.state.error, isNotNull);
  });
}

class _FakeNotificationsRepository implements NotificationsRepository {
  Object? error;
  String? readNotificationId;
  String? archivedNotificationId;
  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => NotificationPageData(
    items: await fetchNotifications(),
    unreadCount: readNotificationId == null && archivedNotificationId == null
        ? 1
        : 0,
  );
  @override
  Future<void> markAllRead() async {
    readNotificationId = 'notification-1';
  }

  @override
  Future<NotificationOpenTarget> openNotification(
    String notificationId,
  ) async => NotificationOpenTarget(
    notification: await setReadState(
      notificationId: notificationId,
      read: true,
    ),
  );

  @override
  Future<List<MomCozyNotification>> fetchNotifications({
    String? status,
    int limit = 100,
  }) async {
    if (error case final failure?) throw failure;
    return const [
      MomCozyNotification(
        id: 'notification-1',
        type: 'feeding_due',
        title: 'Feeding reminder',
        body: 'Bottle is due',
        status: 'unread',
        source: 'system',
        payload: {},
      ),
    ];
  }

  @override
  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  }) async {
    readNotificationId = notificationId;
    return MomCozyNotification(
      id: notificationId,
      type: 'feeding_due',
      title: 'Feeding reminder',
      body: 'Bottle is due',
      status: read ? 'read' : 'unread',
      source: 'system',
      payload: const {},
    );
  }

  @override
  Future<void> archive({required String notificationId}) async {
    archivedNotificationId = notificationId;
  }
}
