import 'package:flutter/services.dart';
import '../domain/notification_permission.dart';

class NativeNotificationPlatform implements NotificationPlatform {
  const NativeNotificationPlatform({
    this.channel = const MethodChannel('momcozy/notifications_permission'),
  });
  final MethodChannel channel;

  @override
  Future<NotificationPermission> currentPermission() async =>
      NotificationPermission.fromWire(
        await channel.invokeMethod<String>('getPermission'),
      );
  @override
  Future<NotificationPermission> requestPermission() async =>
      NotificationPermission.fromWire(
        await channel.invokeMethod<String>('requestPermission'),
      );
  @override
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  @override
  Future<void> clearNotifications() =>
      channel.invokeMethod<void>('clearNotifications');
  @override
  Future<void> setBadge(int count) =>
      channel.invokeMethod<void>('setBadge', {'count': count});
}
