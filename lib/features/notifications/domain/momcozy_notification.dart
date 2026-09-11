abstract interface class NotificationsRepository {
  Future<NotificationPageData> fetchPage({String? cursor, int limit = 30});
  Future<void> markAllRead();
  Future<NotificationOpenTarget> openNotification(String notificationId);
  Future<List<MomCozyNotification>> fetchNotifications({
    String? status,
    int limit = 100,
  });

  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  });

  Future<void> archive({required String notificationId});
}

class MomCozyNotification {
  const MomCozyNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.source,
    required this.payload,
    this.createdAt,
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String status;
  final String source;
  final Map<String, Object?> payload;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get isUnread => status.toLowerCase() == 'unread';
}

class NotificationPageData {
  const NotificationPageData({
    required this.items,
    required this.unreadCount,
    this.nextCursor,
  });
  final List<MomCozyNotification> items;
  final int unreadCount;
  final String? nextCursor;
}

class NotificationOpenTarget {
  const NotificationOpenTarget({required this.notification, this.route});
  final MomCozyNotification notification;
  final String? route;
}
