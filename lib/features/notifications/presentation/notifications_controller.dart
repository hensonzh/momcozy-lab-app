import 'package:flutter/foundation.dart';
import '../domain/momcozy_notification.dart';

enum NotificationsPhase { initial, loading, data, error }

class NotificationsState {
  const NotificationsState({
    this.phase = NotificationsPhase.initial,
    this.notifications = const [],
    this.busyIds = const {},
    this.error,
    this.unreadCount = 0,
    this.nextCursor,
    this.loadingMore = false,
  });
  final NotificationsPhase phase;
  final List<MomCozyNotification> notifications;
  final Set<String> busyIds;
  final Object? error;
  final int unreadCount;
  final String? nextCursor;
  final bool loadingMore;
}

class NotificationsController extends ChangeNotifier {
  NotificationsController({required this._repository});
  NotificationsRepository _repository;
  NotificationsRepository get repository => _repository;

  // Same account/session only; preserve the account-wide inbox during a runtime
  // rebuild. Account changes dispose this controller instead.
  void replaceRepository(NotificationsRepository repository) {
    _repository = repository;
  }

  NotificationsState _state = const NotificationsState();
  NotificationsState get state => _state;
  bool _disposed = false;
  Future<void> _operations = Future<void>.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _operations.then((_) async {
      if (!_disposed) await operation();
    });
    _operations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> load() => _serialize(() => _load());
  Future<void> loadMore() => _serialize(() async {
    if (_state.nextCursor != null) await _load(more: true);
  });
  Future<void> _load({bool more = false}) async {
    _publish(
      phase: more ? _state.phase : NotificationsPhase.loading,
      loadingMore: more,
    );
    try {
      final page = await repository.fetchPage(
        cursor: more ? _state.nextCursor : null,
      );
      final items = <String, MomCozyNotification>{
        if (more)
          for (final item in _state.notifications) item.id: item,
        for (final item in page.items) item.id: item,
      };
      _emit(
        NotificationsState(
          phase: NotificationsPhase.data,
          notifications: List.unmodifiable(items.values),
          unreadCount: page.unreadCount,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      _publish(phase: NotificationsPhase.error, error: error);
    }
  }

  Future<void> markRead(String id) => _serialize(() async {
    if (!_state.notifications.any((item) => item.id == id && item.isUnread)) {
      return;
    }
    await _mutate(id, () async {
      final updated = await repository.setReadState(
        notificationId: id,
        read: true,
      );
      _publish(
        items: [
          for (final item in _state.notifications)
            if (item.id == id) updated else item,
        ],
      );
    });
  });

  Future<void> archive(String id) => _serialize(
    () => _mutate(id, () async {
      await repository.archive(notificationId: id);
      _publish(
        items: _state.notifications.where((item) => item.id != id).toList(),
      );
    }),
  );

  Future<void> markAllRead() => _serialize(() async {
    _publish(busy: {'all'});
    try {
      await repository.markAllRead();
      await _load();
    } catch (error) {
      _publish(phase: NotificationsPhase.error, error: error);
    }
  });

  Future<void> _mutate(String id, Future<void> Function() mutation) async {
    _publish(busy: {id});
    try {
      await mutation();
      final count = (await repository.fetchPage(limit: 1)).unreadCount;
      _publish(phase: NotificationsPhase.data, count: count);
    } catch (error) {
      _publish(phase: NotificationsPhase.error, error: error);
    }
  }

  void _publish({
    NotificationsPhase? phase,
    List<MomCozyNotification>? items,
    Set<String> busy = const {},
    int? count,
    Object? error,
    bool loadingMore = false,
  }) => _emit(
    NotificationsState(
      phase: phase ?? _state.phase,
      notifications: List.unmodifiable(items ?? _state.notifications),
      busyIds: busy,
      unreadCount: count ?? _state.unreadCount,
      nextCursor: _state.nextCursor,
      error: error,
      loadingMore: loadingMore,
    ),
  );
  void _emit(NotificationsState next) {
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
