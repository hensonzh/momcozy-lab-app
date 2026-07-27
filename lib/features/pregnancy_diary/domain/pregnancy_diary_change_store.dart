import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';

const _diaryChangedEventType = 'diary.changed';
const _supportedOperations = <String>{'created', 'updated', 'deleted'};
const _maxSeenEventIds = 64;

@immutable
class PregnancyDiaryChange {
  const PregnancyDiaryChange({
    required this.operation,
    required this.entryId,
    required this.entryDate,
    required this.updatedAt,
    required this.source,
    required this.eventId,
  });

  static PregnancyDiaryChange? tryFromEvent(AgentStreamEvent event) {
    if (event.type != _diaryChangedEventType || event.isTransient) {
      return null;
    }

    final eventId = _string(event.eventId);
    final operation = _string(event.payload['operation']);
    final entryId = _string(
      event.payload['entry_id'] ?? event.payload['entryId'],
    );
    final entryDate = _date(
      event.payload['entry_date'] ?? event.payload['entryDate'],
    );
    final updatedAt = _date(
      event.payload['updated_at'] ?? event.payload['updatedAt'],
    );
    final source = _string(event.payload['source']);
    if (eventId == null ||
        operation == null ||
        !_supportedOperations.contains(operation) ||
        entryId == null ||
        entryDate == null ||
        updatedAt == null ||
        source == null) {
      return null;
    }

    return PregnancyDiaryChange(
      operation: operation,
      entryId: entryId,
      entryDate: entryDate,
      updatedAt: updatedAt,
      source: source,
      eventId: eventId,
    );
  }

  final String operation;
  final String entryId;
  final DateTime entryDate;
  final DateTime updatedAt;
  final String source;
  final String eventId;
}

@immutable
class PregnancyDiaryPendingState {
  const PregnancyDiaryPendingState({
    required this.hasUnread,
    required this.highlightCard,
    required this.revision,
    required this.lastEventId,
    required this.seenEventIds,
  });

  factory PregnancyDiaryPendingState.fromMap(Object? value) {
    if (value is! Map) {
      return const PregnancyDiaryPendingState(
        hasUnread: false,
        highlightCard: false,
        revision: 0,
        lastEventId: null,
        seenEventIds: <String>[],
      );
    }
    final map = Map<Object?, Object?>.from(value);
    final seen = <String>[];
    final rawSeen = map['seen_event_ids'];
    if (rawSeen is List) {
      for (final item in rawSeen) {
        final eventId = _string(item);
        if (eventId == null || seen.contains(eventId)) continue;
        seen.add(eventId);
      }
    }
    final boundedSeen = seen.length <= _maxSeenEventIds
        ? seen
        : seen.sublist(seen.length - _maxSeenEventIds);
    final rawRevision = map['revision'];
    final revision = rawRevision is int
        ? math.max(0, rawRevision)
        : math.max(0, int.tryParse(rawRevision?.toString() ?? '') ?? 0);
    return PregnancyDiaryPendingState(
      hasUnread: map['has_unread'] == true,
      highlightCard: map['highlight_card'] == true,
      revision: revision,
      lastEventId: _string(map['last_event_id']),
      seenEventIds: List<String>.unmodifiable(boundedSeen),
    );
  }

  final bool hasUnread;
  final bool highlightCard;
  final int revision;
  final String? lastEventId;
  final List<String> seenEventIds;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'has_unread': hasUnread,
      'highlight_card': highlightCard,
      'revision': revision,
      'last_event_id': lastEventId,
      'seen_event_ids': seenEventIds,
    };
  }
}

abstract interface class PregnancyDiaryChangePersistence {
  Future<PregnancyDiaryPendingState?> read();

  Future<void> write(PregnancyDiaryPendingState state);
}

class PregnancyDiaryChangeStore extends ChangeNotifier {
  PregnancyDiaryChangeStore({this.persistence})
    : _restoreCompleted = persistence == null;

  final PregnancyDiaryChangePersistence? persistence;
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  final List<PregnancyDiaryChange> _pendingRestoreChanges =
      <PregnancyDiaryChange>[];
  final Set<String> _pendingRestoreEventIds = <String>{};
  bool _hasUnread = false;
  bool _highlightCard = false;
  int _revision = 0;
  String? _lastEventId;
  bool _restoreCompleted;
  Future<void>? _restoreFuture;
  Future<void> _persistenceTail = Future<void>.value();

  bool get hasUnread => _hasUnread;
  bool get highlightCard => _highlightCard;
  int get revision => _revision;
  String? get lastEventId => _lastEventId;

  Future<void> restore() {
    if (_restoreCompleted) return Future<void>.value();
    return _restoreFuture ??= _restore();
  }

  Future<void> _restore() async {
    final persistence = this.persistence;
    if (persistence == null) {
      _restoreCompleted = true;
      return;
    }
    final previousHasUnread = _hasUnread;
    final previousHighlightCard = _highlightCard;
    final previousRevision = _revision;
    final previousLastEventId = _lastEventId;
    PregnancyDiaryPendingState? restored;
    try {
      restored = await persistence.read();
    } catch (_) {
      // Continue with queued in-memory events when local persistence fails.
    }
    if (restored != null) {
      _mergeSeenEventIds(restored.seenEventIds);
      final restoredLastEventId = restored.lastEventId;
      if (restoredLastEventId != null) {
        _rememberEventId(restoredLastEventId);
      }
      _hasUnread = restored.hasUnread;
      _highlightCard = restored.highlightCard;
      _revision = restored.revision;
      _lastEventId = restored.lastEventId;
    }
    _restoreCompleted = true;

    var appliedQueuedChange = false;
    final queuedChanges = List<PregnancyDiaryChange>.of(_pendingRestoreChanges);
    _pendingRestoreChanges.clear();
    _pendingRestoreEventIds.clear();
    for (final change in queuedChanges) {
      if (_seenEventIds.contains(change.eventId)) continue;
      _recordNow(change, notify: false, persist: false);
      appliedQueuedChange = true;
    }
    final changed =
        _hasUnread != previousHasUnread ||
        _highlightCard != previousHighlightCard ||
        _revision != previousRevision ||
        _lastEventId != previousLastEventId;
    if (changed) notifyListeners();
    if (appliedQueuedChange) _schedulePersistence();
  }

  bool record(PregnancyDiaryChange change) {
    if (_seenEventIds.contains(change.eventId) ||
        _pendingRestoreEventIds.contains(change.eventId)) {
      return false;
    }
    if (!_restoreCompleted) {
      _pendingRestoreChanges.add(change);
      _pendingRestoreEventIds.add(change.eventId);
      unawaited(restore());
      return true;
    }
    return _recordNow(change);
  }

  bool _recordNow(
    PregnancyDiaryChange change, {
    bool notify = true,
    bool persist = true,
  }) {
    _rememberEventId(change.eventId);

    _revision += 1;
    _lastEventId = change.eventId;
    if (change.operation == 'deleted') {
      _hasUnread = false;
      _highlightCard = false;
    } else {
      _hasUnread = true;
      _highlightCard = false;
    }
    if (notify) notifyListeners();
    if (persist) _schedulePersistence();
    return true;
  }

  void transferNavigationNoticeToCard() {
    if (!_hasUnread) return;
    _hasUnread = false;
    _highlightCard = true;
    notifyListeners();
    _schedulePersistence();
  }

  void clearCardNotice() {
    if (!_highlightCard) return;
    _highlightCard = false;
    notifyListeners();
    _schedulePersistence();
  }

  void restoreNavigationNotice() {
    if (!_highlightCard) return;
    _highlightCard = false;
    _hasUnread = true;
    notifyListeners();
    _schedulePersistence();
  }

  Future<void> flushPersistence() async {
    await restore();
    await _persistenceTail;
  }

  void _schedulePersistence() {
    final persistence = this.persistence;
    if (persistence == null) return;
    _persistenceTail = _persistenceTail.then((_) async {
      try {
        await persistence.write(_snapshot());
      } catch (_) {
        // In-memory notice state remains usable when local persistence fails.
      }
    });
  }

  PregnancyDiaryPendingState _snapshot() {
    return PregnancyDiaryPendingState(
      hasUnread: _hasUnread,
      highlightCard: _highlightCard,
      revision: _revision,
      lastEventId: _lastEventId,
      seenEventIds: List<String>.unmodifiable(_seenEventIds),
    );
  }

  void _mergeSeenEventIds(Iterable<String> eventIds) {
    for (final eventId in eventIds) {
      final normalized = _string(eventId);
      if (normalized != null) _rememberEventId(normalized);
    }
  }

  void _rememberEventId(String eventId) {
    _seenEventIds
      ..remove(eventId)
      ..add(eventId);
    while (_seenEventIds.length > _maxSeenEventIds) {
      _seenEventIds.remove(_seenEventIds.first);
    }
  }
}

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final text = _string(value);
  return text == null ? null : DateTime.tryParse(text);
}
