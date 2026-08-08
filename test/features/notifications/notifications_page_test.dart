import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notifications_page.dart';

void main() {
  testWidgets('shows the real inbox and supports read and archive actions', (
    tester,
  ) async {
    final repository = _FakeNotificationsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: momCozyTheme(),
        home: NotificationsPage(
          repository: repository,
          now: () => DateTime.utc(2026, 7, 3, 9),
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Feeding reminder'), findsOneWidget);
    expect(find.text('Bottle is due'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notification-item-notification-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.readNotificationId, 'notification-1');
    expect(find.text('All caught up'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('notification-archive-notification-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.archivedNotificationId, 'notification-1');
    expect(find.text('Feeding reminder'), findsNothing);
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}

class _FakeNotificationsRepository implements NotificationsRepository {
  String? readNotificationId;
  String? archivedNotificationId;

  @override
  Future<List<MomCozyNotification>> fetchNotifications({
    String? status,
    int limit = 100,
  }) async {
    return const [
      MomCozyNotification(
        id: 'notification-1',
        type: 'feeding_due',
        title: 'Feeding reminder',
        body: 'Bottle is due',
        status: 'unread',
        source: 'system',
        payload: {},
        createdAt: null,
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
