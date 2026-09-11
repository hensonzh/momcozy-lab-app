import 'package:flutter/foundation.dart';
import '../domain/notification_permission.dart';

class NotificationPermissionController extends ChangeNotifier {
  NotificationPermissionController(this.platform);
  final NotificationPlatform platform;
  NotificationPermission permission = NotificationPermission.unavailable;
  Future<bool>? _request;
  bool _disposed = false;

  Future<NotificationPermission> refresh() async {
    try {
      permission = await platform.currentPermission();
    } catch (_) {
      permission = NotificationPermission.unavailable;
    }
    if (!_disposed) notifyListeners();
    return permission;
  }

  Future<bool> ensureAllowed({
    required Future<bool> Function() explain,
    required Future<bool> Function() offerSettings,
  }) => _request ??= _ensure(
    explain,
    offerSettings,
  ).whenComplete(() => _request = null);

  Future<bool> _ensure(
    Future<bool> Function() explain,
    Future<bool> Function() offerSettings,
  ) async {
    final actual = await refresh();
    if (_disposed) return false;
    if (actual.canNotify) return true;
    if (actual == NotificationPermission.notDetermined) {
      if (!await explain() || _disposed) return false;
      try {
        await platform.requestPermission();
      } catch (_) {
        return false;
      }
      return (await refresh()).canNotify && !_disposed;
    }
    if (actual == NotificationPermission.denied &&
        await offerSettings() &&
        !_disposed) {
      await platform.openSettings();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
