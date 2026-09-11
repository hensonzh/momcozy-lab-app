enum NotificationPermission {
  notDetermined,
  authorized,
  denied,
  provisional,
  unavailable;

  bool get canNotify => this == authorized || this == provisional;
  String get wire => this == notDetermined ? 'not_determined' : name;
  static NotificationPermission fromWire(Object? value) =>
      values.where((item) => item.wire == value).firstOrNull ?? unavailable;
}

abstract interface class NotificationPlatform {
  Future<NotificationPermission> currentPermission();
  Future<NotificationPermission> requestPermission();
  Future<void> openSettings();
  Future<void> clearNotifications();
  Future<void> setBadge(int count);
}
