import 'dart:async';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_permission.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/notification_delivery_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/push_messaging.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notification_installation_store.dart';

class FakePlatform implements NotificationPlatform {
  NotificationPermission value = NotificationPermission.notDetermined,
      next = NotificationPermission.authorized;
  int requests = 0, settings = 0, clears = 0;
  @override
  Future<NotificationPermission> currentPermission() async => value;
  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    return value = next;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }

  @override
  Future<void> clearNotifications() async {
    clears++;
  }

  @override
  Future<void> setBadge(int count) async {}
}

class FakeGateway implements PushMessagingGateway {
  bool available = true;
  int tokenCalls = 0, pauses = 0;
  NotificationPushIntent? initial;
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<NotificationPushIntent>.broadcast();
  final opened = StreamController<NotificationPushIntent>.broadcast();
  @override
  Future<bool> initialize() async => available;
  @override
  Future<String?> token() async {
    tokenCalls++;
    return 'test-device-token';
  }

  @override
  Future<NotificationPushIntent?> initialMessage() async => initial;
  @override
  Future<void> pauseTokenRefresh() async {
    pauses++;
  }

  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<NotificationPushIntent> get foregroundMessages => foreground.stream;
  @override
  Stream<NotificationPushIntent> get openedMessages => opened.stream;
  @override
  Future<void> dispose() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}

class FakeStore implements NotificationInstallationStore {
  NotificationPushIntent? pending;
  int revision = 0;
  @override
  Future<NotificationInstallationIdentity> identity() async =>
      const NotificationInstallationIdentity('installation', 'secret');
  @override
  Future<int> nextRevision() async => ++revision;
  @override
  Future<NotificationPushIntent?> readPending() async => pending;
  @override
  Future<void> writePending(NotificationPushIntent? intent) async {
    pending = intent;
  }
}

class FakeRepository
    implements NotificationsRepository, NotificationDeliveryRepository {
  final events = <String>[], opened = <String>[];
  Completer<PushRegistration>? registrationWait;
  int lastRevision = 0;
  String? lastLocale;
  bool serverPushAvailable = true;
  AppointmentReminder reminderValue = const AppointmentReminder(
    enabled: false,
    status: 'disabled',
  );
  Object? openError;
  String targetRoute =
      '/services/appointments/11111111-1111-1111-1111-111111111111';
  @override
  Future<PushRegistration> registerInstallation({
    required String id,
    required String secret,
    required int revision,
    required String platform,
    required NotificationPermission permission,
    required String locale,
    String? token,
  }) async {
    if (revision <= lastRevision) {
      throw StateError('stale installation revision');
    }
    lastRevision = revision;
    lastLocale = locale;
    events.add('register:${permission.wire}');
    return registrationWait?.future ??
        PushRegistration(
          bindingId: 'binding',
          tokenRegistered: true,
          pushAvailable: serverPushAvailable,
        );
  }

  @override
  Future<void> detachInstallation({
    required String id,
    required String secret,
  }) async {
    lastRevision++;
    events.add('detach');
  }

  @override
  Future<Map<String, bool>> preferences() async => {'appointments': true};
  @override
  Future<Map<String, bool>> setPreference(
    String category, {
    required bool enabled,
    String? installationId,
  }) async => {category: enabled};
  @override
  Future<AppointmentReminder> reminder(String appointmentId) async =>
      reminderValue;
  @override
  Future<AppointmentReminder> setReminder(
    String appointmentId, {
    required bool enabled,
    String? installationId,
  }) async {
    events.add('reminder:$enabled');
    return reminderValue = AppointmentReminder(
      enabled: enabled,
      status: enabled ? 'scheduled' : 'disabled',
    );
  }

  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async => const NotificationPageData(items: [], unreadCount: 0);
  @override
  Future<List<MomCozyNotification>> fetchNotifications({
    String? status,
    int limit = 100,
  }) async => [];
  @override
  Future<void> archive({required String notificationId}) async {}
  @override
  Future<void> markAllRead() async {}
  @override
  Future<NotificationOpenTarget> openNotification(String notificationId) async {
    if (openError != null) throw openError!;
    opened.add(notificationId);
    return NotificationOpenTarget(
      notification: await setReadState(
        notificationId: notificationId,
        read: true,
      ),
      route: targetRoute,
    );
  }

  @override
  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  }) async => MomCozyNotification(
    id: notificationId,
    type: 'appointment_created',
    title: 'Update',
    body: '',
    status: 'read',
    source: 'care',
    payload: const {},
  );
}
