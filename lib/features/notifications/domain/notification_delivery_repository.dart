import 'notification_permission.dart';

class PushRegistration {
  const PushRegistration({
    required this.bindingId,
    required this.tokenRegistered,
    required this.pushAvailable,
  });
  final String bindingId;
  final bool tokenRegistered;
  final bool pushAvailable;
}

class AppointmentReminder {
  const AppointmentReminder({
    required this.enabled,
    required this.status,
    this.triggerAt,
  });
  final bool enabled;
  final String status;
  final DateTime? triggerAt;
}

abstract interface class NotificationDeliveryRepository {
  Future<PushRegistration> registerInstallation({
    required String id,
    required String secret,
    required int revision,
    required String platform,
    required NotificationPermission permission,
    required String locale,
    String? token,
  });
  Future<void> detachInstallation({required String id, required String secret});
  Future<Map<String, bool>> preferences();
  Future<Map<String, bool>> setPreference(
    String category, {
    required bool enabled,
    String? installationId,
  });
  Future<AppointmentReminder> reminder(String appointmentId);
  Future<AppointmentReminder> setReminder(
    String appointmentId, {
    required bool enabled,
    String? installationId,
  });
}
