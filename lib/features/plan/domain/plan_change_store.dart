import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';

const _planChangedEventType = 'milk_plan.changed';
const _maxSeenEventIds = 64;

@immutable
class PlanChange {
  const PlanChange({required this.eventId});

  factory PlanChange.fromEvent(AgentStreamEvent event) {
    return PlanChange(eventId: event.eventId?.trim() ?? '');
  }

  static PlanChange? tryFromEvent(AgentStreamEvent event) {
    if (event.type != _planChangedEventType || event.isTransient) return null;
    final eventId = event.eventId?.trim() ?? '';
    final operation = event.payload['operation']?.toString().trim();
    final source = event.payload['source']?.toString().trim();
    if (eventId.isEmpty ||
        !const {
          'created',
          'updated',
          'rescheduled',
          'deleted',
        }.contains(operation) ||
        source != 'agent_action') {
      return null;
    }
    return PlanChange(eventId: eventId);
  }

  final String eventId;
}

@immutable
class PlanChangeSnapshot {
  const PlanChangeSnapshot({
    required this.hasUnread,
    required this.revision,
    required this.seenEventIds,
  });

  factory PlanChangeSnapshot.fromMap(Object? value) {
    if (value is! Map) return empty;
    final map = Map<Object?, Object?>.from(value);
    final seen = <String>[];
    final rawSeen = map['seen_event_ids'];
    if (rawSeen is List) {
      for (final item in rawSeen) {
        final id = item?.toString().trim() ?? '';
        if (id.isNotEmpty && !seen.contains(id)) seen.add(id);
      }
    }
    final revision = int.tryParse(map['revision']?.toString() ?? '') ?? 0;
    return PlanChangeSnapshot(
      hasUnread: map['has_unread'] == true,
      revision: revision < 0 ? 0 : revision,
      seenEventIds: seen.length <= _maxSeenEventIds
          ? List.unmodifiable(seen)
          : List.unmodifiable(seen.sublist(seen.length - _maxSeenEventIds)),
    );
  }

  static const empty = PlanChangeSnapshot(
    hasUnread: false,
    revision: 0,
    seenEventIds: <String>[],
  );

  final bool hasUnread;
  final int revision;
  final List<String> seenEventIds;

  Map<String, Object?> toMap() => {
    'has_unread': hasUnread,
    'revision': revision,
    'seen_event_ids': seenEventIds,
  };
}

abstract interface class PlanChangePersistence {
  Future<PlanChangeSnapshot?> read();

  Future<void> write(PlanChangeSnapshot state);
}

class PlanChangeStore extends ChangeNotifier {
  PlanChangeStore({this.persistence}) : _restored = persistence == null;

  final PlanChangePersistence? persistence;
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  bool _hasUnread = false;
  int _revision = 0;
  bool _restored;
  Future<void>? _restoreFuture;
  Future<void> _writeTail = Future<void>.value();

  bool get hasUnread => _hasUnread;
  int get revision => _revision;

  Future<void> restore() {
    if (_restored) return Future<void>.value();
    return _restoreFuture ??= _restore();
  }

  Future<void> _restore() async {
    try {
      final snapshot = await persistence?.read();
      if (snapshot != null) {
        _hasUnread = snapshot.hasUnread;
        _revision = snapshot.revision;
        _seenEventIds.addAll(snapshot.seenEventIds);
      }
    } catch (_) {
      // The in-memory notification remains usable when secure storage fails.
    }
    _restored = true;
    notifyListeners();
  }

  bool record(PlanChange change) {
    if (!_seenEventIds.add(change.eventId)) return false;
    while (_seenEventIds.length > _maxSeenEventIds) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    _revision += 1;
    _hasUnread = true;
    notifyListeners();
    _persist();
    return true;
  }

  void markViewed() {
    if (!_hasUnread) return;
    _hasUnread = false;
    notifyListeners();
    _persist();
  }

  Future<void> flushPersistence() async {
    await restore();
    await _writeTail;
  }

  void _persist() {
    final target = persistence;
    if (target == null) return;
    final snapshot = PlanChangeSnapshot(
      hasUnread: _hasUnread,
      revision: _revision,
      seenEventIds: List.unmodifiable(_seenEventIds),
    );
    _writeTail = _writeTail.then((_) async {
      try {
        await target.write(snapshot);
      } catch (_) {
        // Persistence failure must not break the visible Plan experience.
      }
    });
  }
}
