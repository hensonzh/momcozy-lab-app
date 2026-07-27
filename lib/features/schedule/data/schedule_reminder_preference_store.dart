import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/core/storage/user_scoped_storage_key.dart';
import 'package:app/features/schedule/domain/schedule_reminder.dart';

class FlutterSecureScheduleReminderPreferenceStore
    implements ScheduleReminderPreferenceStore {
  const FlutterSecureScheduleReminderPreferenceStore({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
  });

  final String userId;
  final FlutterSecureStorage storage;

  @override
  Future<bool> readEnabled() async {
    return await storage.read(key: storageKey) == 'true';
  }

  @override
  Future<void> writeEnabled(bool enabled) {
    return storage.write(key: storageKey, value: enabled.toString());
  }

  String get storageKey {
    final scopedUserId = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return userScopedStorageKey(
      scopedUserId,
      'notifications.scheduleReminderOn',
    );
  }
}
