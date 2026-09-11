import 'package:flutter/widgets.dart';
import 'notification_coordinator.dart';

class NotificationScope extends InheritedNotifier<NotificationCoordinator> {
  const NotificationScope({
    super.key,
    required NotificationCoordinator coordinator,
    required super.child,
  }) : super(notifier: coordinator);
  static NotificationCoordinator? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationScope>()?.notifier;
}
