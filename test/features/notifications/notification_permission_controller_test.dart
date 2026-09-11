import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/presentation/notification_permission_controller.dart';

void main() {
  test(
    'launch checks permission without requesting; first reminder explains before system prompt',
    () async {
      final platform = FakeNotificationPlatform();
      final controller = NotificationPermissionController(platform);
      await controller.refresh();
      expect(platform.requests, 0);
      final allowed = await controller.ensureAllowed(
        explain: () async {
          platform.calls.add('explain');
          return true;
        },
        offerSettings: () async => false,
      );
      expect(allowed, isTrue);
      expect(
        platform.calls.indexOf('explain'),
        lessThan(platform.calls.indexOf('request')),
      );
      expect(platform.requests, 1);
      expect(
        await controller.ensureAllowed(
          explain: () async => throw StateError('must not explain twice'),
          offerSettings: () async => false,
        ),
        isTrue,
      );
      expect(platform.requests, 1);
    },
  );

  test(
    'denial never schedules work or repeats the system prompt; settings recovery uses OS state',
    () async {
      final platform = FakeNotificationPlatform()
        ..next = NotificationPermission.denied;
      final controller = NotificationPermissionController(platform);
      expect(
        await controller.ensureAllowed(
          explain: () async => true,
          offerSettings: () async => false,
        ),
        isFalse,
      );
      expect(
        await controller.ensureAllowed(
          explain: () async => throw StateError('already asked'),
          offerSettings: () async => true,
        ),
        isFalse,
      );
      expect(platform.requests, 1);
      expect(platform.settingsOpened, 1);
      platform.permission = NotificationPermission.authorized;
      await controller.refresh();
      expect(
        await controller.ensureAllowed(
          explain: () async => false,
          offerSettings: () async => false,
        ),
        isTrue,
      );
      platform.permission = NotificationPermission.denied;
      expect(
        await controller.ensureAllowed(
          explain: () async => false,
          offerSettings: () async => false,
        ),
        isFalse,
      );
      expect(platform.requests, 1);
    },
  );

  test(
    'declining the product explanation does not request OS permission',
    () async {
      final platform = FakeNotificationPlatform();
      final controller = NotificationPermissionController(platform);
      expect(
        await controller.ensureAllowed(
          explain: () async => false,
          offerSettings: () async => false,
        ),
        isFalse,
      );
      expect(platform.requests, 0);
    },
  );

  test(
    'provisional permission is usable; unavailable platforms cannot enable tasks',
    () async {
      final platform = FakeNotificationPlatform()
        ..permission = NotificationPermission.provisional;
      final controller = NotificationPermissionController(platform);
      expect(
        await controller.ensureAllowed(
          explain: () async => false,
          offerSettings: () async => false,
        ),
        isTrue,
      );
      platform.permission = NotificationPermission.unavailable;
      expect(
        await controller.ensureAllowed(
          explain: () async => false,
          offerSettings: () async => false,
        ),
        isFalse,
      );
      expect(platform.requests, 0);
    },
  );
}

class FakeNotificationPlatform implements NotificationPlatform {
  NotificationPermission permission = NotificationPermission.notDetermined;
  NotificationPermission next = NotificationPermission.authorized;
  int requests = 0, settingsOpened = 0;
  final calls = <String>[];
  @override
  Future<NotificationPermission> currentPermission() async {
    calls.add('check');
    return permission;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    calls.add('request');
    return permission = next;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Future<void> clearNotifications() async {}
  @override
  Future<void> setBadge(int count) async {}
}
