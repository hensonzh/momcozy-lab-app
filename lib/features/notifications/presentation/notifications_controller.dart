import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';

enum NotificationsPhase { initial, loading, data, error }

class NotificationsState {
  const NotificationsState({
    this.phase = NotificationsPhase.initial,
    this.notifications = const <MomCozyNotification>[],
    this.busyIds = const <String>{},
    this.error,
  });

  final NotificationsPhase phase;
  final List<MomCozyNotification> notifications;
  final Set<String> busyIds;
  final Object? error;

  int get unreadCount =>
      notifications.where((notification) => notification.isUnread).length;
}

class NotificationsController extends ChangeNotifier {
  NotificationsController({required this.repository});

  final NotificationsRepository repository;

  NotificationsState _state = const NotificationsState();
  NotificationsState get state => _state;
  bool _disposed = false;

  Future<void> load() async {
    if (_disposed || _state.phase == NotificationsPhase.loading) return;
    _publish(
      NotificationsState(
        phase: NotificationsPhase.loading,
        notifications: _state.notifications,
        busyIds: _state.busyIds,
      ),
    );
    try {
      final notifications = List<MomCozyNotification>.of(
        await repository.fetchNotifications(),
      )..sort(_newestFirst);
      _publish(
        NotificationsState(
          phase: NotificationsPhase.data,
          notifications: List.unmodifiable(notifications),
        ),
      );
    } catch (error) {
      _publish(
        NotificationsState(
          phase: NotificationsPhase.error,
          notifications: _state.notifications,
          busyIds: _state.busyIds,
          error: error,
        ),
      );
    }
  }

  Future<void> markRead(String notificationId) async {
    final notification = _state.notifications
        .where((candidate) => candidate.id == notificationId)
        .firstOrNull;
    if (notification == null || !notification.isUnread) return;
    await _mutate(
      notificationId,
      () => repository.setReadState(notificationId: notificationId, read: true),
      onSuccess: (updated) {
        final notifications = [
          for (final candidate in _state.notifications)
            if (candidate.id == updated.id) updated else candidate,
        ];
        _publish(
          NotificationsState(
            phase: NotificationsPhase.data,
            notifications: List.unmodifiable(notifications),
            busyIds: _withoutBusy(notificationId),
          ),
        );
      },
    );
  }

  Future<void> archive(String notificationId) async {
    await _mutate<void>(
      notificationId,
      () => repository.archive(notificationId: notificationId),
      onSuccess: (_) {
        _publish(
          NotificationsState(
            phase: NotificationsPhase.data,
            notifications: List.unmodifiable(
              _state.notifications.where(
                (candidate) => candidate.id != notificationId,
              ),
            ),
            busyIds: _withoutBusy(notificationId),
          ),
        );
      },
    );
  }

  Future<void> _mutate<T>(
    String notificationId,
    Future<T> Function() action, {
    required ValueChanged<T> onSuccess,
  }) async {
    if (_disposed || _state.busyIds.contains(notificationId)) return;
    _publish(
      NotificationsState(
        phase: _state.phase,
        notifications: _state.notifications,
        busyIds: Set.unmodifiable({..._state.busyIds, notificationId}),
      ),
    );
    try {
      final result = await action();
      if (_disposed) return;
      onSuccess(result);
    } catch (error) {
      _publish(
        NotificationsState(
          phase: NotificationsPhase.error,
          notifications: _state.notifications,
          busyIds: _withoutBusy(notificationId),
          error: error,
        ),
      );
    }
  }

  Set<String> _withoutBusy(String notificationId) {
    return Set.unmodifiable(
      _state.busyIds.where((candidate) => candidate != notificationId),
    );
  }

  void _publish(NotificationsState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

int _newestFirst(MomCozyNotification left, MomCozyNotification right) {
  final leftTime = left.createdAt;
  final rightTime = right.createdAt;
  if (leftTime == null && rightTime == null) return 0;
  if (leftTime == null) return 1;
  if (rightTime == null) return -1;
  return rightTime.compareTo(leftTime);
}
