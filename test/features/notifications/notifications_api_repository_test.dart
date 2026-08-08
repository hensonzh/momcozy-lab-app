import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notifications_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('NotificationsApiRepository', () {
    test(
      'maps the owner inbox and preserves the public query contract',
      () async {
        final transport = FixtureApiJsonTransport({
          'items': [
            {
              'id': 'notification-1',
              'notification_type': 'feeding_due',
              'title': 'Feeding reminder',
              'body': 'Bottle is due',
              'status': 'unread',
              'source': 'system',
              'payload': {'infant_id': 'baby-1'},
              'created_at': '2026-07-03T08:00:00Z',
            },
          ],
        });

        final notifications = await NotificationsApiRepository(
          transport: transport,
        ).fetchNotifications(status: 'unread');

        expect(transport.lastPath, notificationsEndpoint);
        expect(transport.lastQuery, {'status': 'unread', 'limit': 100});
        expect(notifications.single.id, 'notification-1');
        expect(notifications.single.isUnread, isTrue);
        expect(
          notifications.single.createdAt,
          DateTime.parse('2026-07-03T08:00:00Z'),
        );
        expect(notifications.single.payload['infant_id'], 'baby-1');
      },
    );

    test('marks read and archives through mutation endpoints', () async {
      final transport = FixtureApiJsonTransport({
        'id': 'notification-1',
        'notification_type': 'feeding_due',
        'title': 'Feeding reminder',
        'body': 'Bottle is due',
        'status': 'read',
        'source': 'system',
        'payload': <String, Object?>{},
        'created_at': '2026-07-03T08:00:00Z',
        'read_at': '2026-07-03T08:02:00Z',
      });
      final repository = NotificationsApiRepository(transport: transport);

      final updated = await repository.setReadState(
        notificationId: 'notification-1',
        read: true,
      );

      expect(updated.isUnread, isFalse);
      expect(transport.lastMethod, 'PATCH');
      expect(transport.lastPath, '/v1/notifications/notification-1/read');
      expect(transport.lastBody, {'read': true});

      await repository.archive(notificationId: 'notification-1');

      expect(transport.lastMethod, 'DELETE');
      expect(transport.lastPath, '/v1/notifications/notification-1');
    });
  });
}
