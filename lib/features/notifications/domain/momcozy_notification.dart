// Match only retired product copy, not user-authored names or records. The
// raw notification stays intact so its ID, target, and source are auditable.
final _unsupportedNotificationCopy = RegExp(
  r'[\u3400-\u9fff\u{20000}-\u{323af}\u3040-\u30ff\u31f0-\u31ff\uac00-\ud7af\u0400-\u052f\u0600-\u06ff\u0900-\u097f]|cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);

const _englishNotificationTemplates = <String, ({String title, String body})>{
  'appointment_created': (
    title: 'Appointment confirmed',
    body: 'Your appointment is confirmed. Open the details to prepare.',
  ),
  'appointment_reminder': (
    title: 'Your appointment is coming up',
    body: 'Open your appointment to review the details and get ready.',
  ),
  'consultation_started': (
    title: 'Your consultation has started',
    body: 'Open your consultation to join.',
  ),
  'consultation_ended': (
    title: 'Consultation update',
    body: 'Your consultation has ended. Open the summary for next steps.',
  ),
  'expert_feedback': (
    title: 'New expert feedback',
    body: 'Your expert has shared an update. Open the app to view it.',
  ),
  'service_progress_updated': (
    title: 'Service update',
    body: 'There is an update to your service. Open the details to view it.',
  ),
};

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

  String get displayTitle => _unsupportedNotificationCopy.hasMatch(title)
      ? (_englishNotificationTemplates[type]?.title ?? 'Momcozy AI update')
      : title.isEmpty
      ? 'Momcozy update'
      : title;

  String get displayBody => _unsupportedNotificationCopy.hasMatch(body)
      ? (_englishNotificationTemplates[type]?.body ??
            'Open the app to view the latest details.')
      : body;
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
