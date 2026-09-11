class NotificationPushIntent {
  const NotificationPushIntent({
    required this.notificationId,
    required this.bindingId,
  });
  final String notificationId, bindingId;

  static NotificationPushIntent? fromData(Map<String, Object?> data) {
    final id = data['notification_id'], binding = data['binding_id'];
    final uuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (id is! String ||
        binding is! String ||
        !uuid.hasMatch(id) ||
        !uuid.hasMatch(binding)) {
      return null;
    }
    return NotificationPushIntent(notificationId: id, bindingId: binding);
  }

  Map<String, Object?> toJson() => {
    'notification_id': notificationId,
    'binding_id': bindingId,
  };
}

abstract interface class PushMessagingGateway {
  Future<bool> initialize();
  Future<String?> token();
  Future<NotificationPushIntent?> initialMessage();
  Future<void> pauseTokenRefresh();
  Stream<String> get tokenChanges;
  Stream<NotificationPushIntent> get foregroundMessages;
  Stream<NotificationPushIntent> get openedMessages;
  Future<void> dispose();
}
