import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_json_transport.dart';
import '../data/notification_installation_store.dart';
import '../domain/momcozy_notification.dart';
import '../domain/notification_delivery_repository.dart';
import '../domain/push_messaging.dart';
import 'notification_permission_controller.dart';
import 'notifications_controller.dart';

class NotificationCoordinator extends ChangeNotifier {
  NotificationCoordinator({
    required this.permission,
    required this.gateway,
    required this.store,
    required this.platformName,
    required this.onNavigate,
    required this.onMessage,
    required this.onForeground,
  });
  final NotificationPermissionController permission;
  final PushMessagingGateway gateway;
  final NotificationInstallationStore store;
  final String platformName;
  final void Function(String) onNavigate, onMessage;
  final void Function(NotificationPushIntent) onForeground;
  NotificationsController? inbox;
  NotificationDeliveryRepository? _delivery;
  String? _account, _bindingId, _installationId;
  String _locale = 'en';
  int _generation = 0;
  bool _disposed = false, _started = false, pushReady = false;
  bool _accountInitialized = false;
  String? error;
  int permissionSyncVersion = 0;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<void> _operations = Future<void>.value();
  Future<void>? _starting;

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _operations.then((_) async {
      if (!_disposed) await operation();
    });
    _operations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> idle() => _operations;
  bool _current(int generation) => !_disposed && generation == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() => _starting ??= _start();
  Future<void> _start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscriptions.add(
      gateway.tokenChanges.listen(
        (_) => unawaited(refresh()),
        onError: (Object _) {},
      ),
    );
    _subscriptions.add(
      gateway.foregroundMessages.listen((intent) {
        if (!_disposed && _account != null && intent.bindingId == _bindingId) {
          unawaited(refresh());
          onForeground(intent);
        }
      }),
    );
    _subscriptions.add(
      gateway.openedMessages.listen((intent) => unawaited(openPush(intent))),
    );
    await permission.refresh(); // Startup never requests permission or a token.
    try {
      if (await gateway.initialize()) {
        final initial = await gateway.initialMessage();
        if (initial != null) await store.writePending(initial);
      }
      await _resolvePending(_generation);
    } catch (_) {
      error = 'Could not restore the notification. Please try again.';
    }
    _notify();
  }

  Future<void> setAccount({
    required String? key,
    NotificationsRepository? inboxRepository,
    NotificationDeliveryRepository? deliveryRepository,
    String locale = 'en',
  }) async {
    if (_disposed) return;
    if (_accountInitialized && key == _account) {
      // Baby/locale/runtime changes replace clients, not the login binding.
      // Preserve pending delivery, inbox state and any in-flight registration.
      _locale = locale;
      _delivery = key == null ? null : deliveryRepository;
      if (key != null) inbox?.replaceRepository(inboxRepository!);
      return;
    }
    _accountInitialized = true;
    final generation = ++_generation;
    final previous = _delivery;
    _account = key;
    _bindingId = null;
    pushReady = false;
    _locale = locale;
    inbox?.removeListener(_inboxChanged);
    inbox?.dispose();
    inbox = key == null
        ? null
        : NotificationsController(repository: inboxRepository!);
    inbox?.addListener(_inboxChanged);
    _delivery = key == null ? null : deliveryRepository;
    _notify();
    // Clear system UI before waiting for any in-flight network operation.
    await _clearNative();
    await _serialize(() async {
      await gateway.pauseTokenRefresh();
      if (previous != null) {
        try {
          final identity = await store.identity();
          // Detach also advances the server revision; reserve that revision locally.
          await store.nextRevision();
          await previous.detachInstallation(
            id: identity.id,
            secret: identity.secret,
          );
        } catch (_) {
          /* Session revocation also removes eligibility on the server. */
        }
      }
      if (!_current(generation)) return;
      await start();
      if (!_current(generation)) return;
      await _sync(generation);
      if (_current(generation)) await inbox?.load();
      if (_current(generation)) await _resolvePending(generation);
    });
  }

  Future<void> refresh() {
    final generation = _generation;
    return _serialize(() async {
      if (!_current(generation)) return;
      await start();
      await _sync(generation);
      if (_current(generation)) await inbox?.load();
      if (_current(generation)) await _resolvePending(generation);
    });
  }

  Future<void> _sync(int generation) async {
    pushReady = false;
    error = null;
    final actual = await permission.refresh();
    if (!_current(generation)) return;
    final repository = _delivery;
    if (repository == null) {
      _notify();
      return;
    }
    try {
      final available = await gateway.initialize();
      if (!available) {
        error =
            'Background notifications are not available yet. Updates remain in your notification center.';
      }
      String? token;
      if (available && actual.canNotify) {
        try {
          token = await gateway.token();
        } catch (_) {
          error = 'Could not register this device. Try again when connected.';
        }
      } else {
        await gateway.pauseTokenRefresh();
      }
      if (!_current(generation)) return;
      final identity = await store.identity();
      final revision = await store.nextRevision();
      if (!_current(generation)) return;
      final registration = await repository.registerInstallation(
        id: identity.id,
        secret: identity.secret,
        revision: revision,
        platform: platformName,
        permission: actual,
        locale: _locale,
        token: token,
      );
      if (!_current(generation)) return;
      _bindingId = registration.bindingId;
      _installationId = identity.id;
      pushReady =
          available &&
          actual.canNotify &&
          token != null &&
          registration.tokenRegistered &&
          registration.pushAvailable;
      if (!available || !registration.pushAvailable) {
        error =
            'Background notifications are not available yet. Updates remain in your notification center.';
      } else if (actual.canNotify && !pushReady) {
        error ??= 'Device registration is pending. Please try again.';
      }
    } catch (_) {
      if (_current(generation)) {
        error ??= 'Could not sync notification settings. Please try again.';
      }
    }
    if (_current(generation)) {
      permissionSyncVersion++;
      _notify();
    }
  }

  Future<bool> _prepare({
    required int generation,
    required Future<bool> Function() explain,
    required Future<bool> Function() offerSettings,
  }) async {
    if (_delivery == null) {
      onNavigate('/login');
      return false;
    }
    final allowed = await permission.ensureAllowed(
      explain: explain,
      offerSettings: offerSettings,
    );
    if (!_current(generation)) return false;
    await _serialize(() async {
      if (_current(generation)) await _sync(generation);
    });
    if (!_current(generation)) return false;
    if (!allowed || !pushReady) {
      onMessage(
        error ??
            'Notifications are off. Open system settings to receive background reminders.',
      );
      return false;
    }
    return true;
  }

  Future<Map<String, bool>> preferences() async {
    final generation = _generation;
    final result = await _delivery?.preferences() ?? <String, bool>{};
    return _current(generation) ? result : {};
  }

  Future<bool> setPreference(
    String category, {
    required bool enabled,
    required Future<bool> Function() explain,
    required Future<bool> Function() offerSettings,
  }) async {
    final generation = _generation;
    if (enabled &&
        !await _prepare(
          generation: generation,
          explain: explain,
          offerSettings: offerSettings,
        )) {
      return false;
    }
    if (!enabled) await refresh();
    if (!_current(generation) || _delivery == null) return false;
    try {
      await _delivery!.setPreference(
        category,
        enabled: enabled,
        installationId: enabled ? _installationId : null,
      );
      return _current(generation);
    } catch (failure) {
      if (_current(generation)) {
        onMessage(
          'Could not update notification preferences. Please try again.',
        );
      }
      return false;
    }
  }

  Future<void> openSettings() async {
    await refresh();
    try {
      await permission.platform.openSettings();
    } catch (_) {
      onMessage('System settings are unavailable on this device.');
    }
  }

  Future<void> openPush(NotificationPushIntent intent) async {
    try {
      await store.writePending(intent);
    } catch (_) {
      onMessage('Could not save the notification. Please try again.');
      return;
    }
    final generation = _generation;
    await _serialize(() => _resolvePending(generation));
  }

  Future<void> _resolvePending(int generation) async {
    NotificationPushIntent? pending;
    try {
      pending = await store.readPending();
    } catch (_) {
      if (_current(generation)) {
        error = 'Could not restore the notification. Please try again.';
      }
      return;
    }
    if (pending == null || !_current(generation)) return;
    if (_account == null) {
      onNavigate('/login');
      return;
    }
    await _open(pending.notificationId, generation, pending: true);
  }

  Future<void> openInboxNotification(String id) => openPush(
    NotificationPushIntent(
      notificationId: id,
      bindingId: _bindingId ?? '00000000-0000-0000-0000-000000000000',
    ),
  );

  Future<void> _open(String id, int generation, {bool pending = false}) async {
    if (!_current(generation) || inbox == null) return;
    try {
      final target = await inbox!.repository.openNotification(id);
      if (!_current(generation)) return;
      if (pending) await _clearPending(id);
      if (!_current(generation)) return;
      final route = target.route;
      if (route != null && _safeRoute(route)) {
        onNavigate(route);
      } else {
        onMessage('This update is no longer available.');
      }
      await inbox?.load();
    } catch (failure) {
      if (!_current(generation)) return;
      if (failure is ApiHttpException && failure.statusCode == 401) {
        if (!pending) {
          await store.writePending(
            NotificationPushIntent(
              notificationId: id,
              bindingId: _bindingId ?? '',
            ),
          );
        }
        onNavigate('/login');
      } else {
        if (pending &&
            failure is ApiHttpException &&
            {403, 404}.contains(failure.statusCode)) {
          await _clearPending(id);
        }
        onMessage(
          'Could not open this update. Check your connection or try from the notification center.',
        );
      }
    }
  }

  Future<void> _clearPending(String id) async {
    if ((await store.readPending())?.notificationId == id) {
      await store.writePending(null);
    }
  }

  static bool _safeRoute(String route) {
    const uuid =
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
    return RegExp('^/\\?conversationId=$uuid\$').hasMatch(route);
  }

  void _inboxChanged() {
    final count = inbox?.state.unreadCount ?? 0;
    unawaited(_badge(count));
    _notify();
  }

  Future<void> _badge(int count) async {
    try {
      await permission.platform.setBadge(count);
    } catch (_) {}
  }

  Future<void> _clearNative() async {
    try {
      await permission.platform.clearNotifications();
      await permission.platform.setBadge(0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    inbox?.removeListener(_inboxChanged);
    inbox?.dispose();
    permission.dispose();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(gateway.dispose());
    super.dispose();
  }
}
