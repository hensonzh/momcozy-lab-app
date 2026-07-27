import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:app/core/agent_stream/agent_stream_event.dart';

const _milkPlanChangedEventType = 'milk_plan.changed';
const _maxSeenEventIds = 64;
const _maxAffectedDates = 31;

enum MilkPlanChangeOperation { updated, rescheduled, deleted }

@immutable
class MilkPlanChange {
  const MilkPlanChange({
    required this.eventId,
    required this.affectedDateKeys,
    required this.operation,
  });

  static MilkPlanChange? tryFromEvent(AgentStreamEvent event) {
    if (event.type != _milkPlanChangedEventType || event.isTransient) {
      return null;
    }
    final eventId = _string(event.eventId);
    final operation = _string(event.payload['operation']);
    final planType = _string(
      event.payload['plan_type'] ?? event.payload['planType'],
    );
    final source = _string(event.payload['source']);
    final reason = _string(event.payload['reason']);
    final rawDates =
        event.payload['affected_dates'] ?? event.payload['affectedDates'];
    final parsedOperation = switch (operation) {
      'updated' => MilkPlanChangeOperation.updated,
      'rescheduled' => MilkPlanChangeOperation.rescheduled,
      'deleted' => MilkPlanChangeOperation.deleted,
      _ => null,
    };
    if (eventId == null ||
        parsedOperation == null ||
        planType != 'milk_management' ||
        source != 'agent_action' ||
        reason == null) {
      return null;
    }
    final dates = <String>[];
    if (rawDates is List) {
      for (final value in rawDates) {
        final dateKey = _dateKey(value);
        if (dateKey == null || dates.contains(dateKey)) continue;
        dates.add(dateKey);
        if (dates.length == _maxAffectedDates) break;
      }
    }
    dates.sort();
    return MilkPlanChange(
      eventId: eventId,
      operation: parsedOperation,
      affectedDateKeys: List<String>.unmodifiable(dates),
    );
  }

  final String eventId;
  final MilkPlanChangeOperation operation;
  final List<String> affectedDateKeys;
}

@immutable
class MilkPlanPendingState {
  const MilkPlanPendingState({
    required this.hasUnread,
    required this.hasPageNotice,
    required this.revision,
    required this.lastEventId,
    required this.affectedDateKeys,
    required this.seenEventIds,
  });

  factory MilkPlanPendingState.fromMap(Object? value) {
    if (value is! Map) return empty;
    final map = Map<Object?, Object?>.from(value);
    final affectedDates = _boundedDateKeys(map['affected_date_keys']);
    final seen = <String>[];
    final rawSeen = map['seen_event_ids'];
    if (rawSeen is List) {
      for (final value in rawSeen) {
        final eventId = _string(value);
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
    return MilkPlanPendingState(
      hasUnread: map['has_unread'] == true,
      hasPageNotice: map['has_page_notice'] == true,
      revision: revision,
      lastEventId: _string(map['last_event_id']),
      affectedDateKeys: List<String>.unmodifiable(affectedDates),
      seenEventIds: List<String>.unmodifiable(boundedSeen),
    );
  }

  static const empty = MilkPlanPendingState(
    hasUnread: false,
    hasPageNotice: false,
    revision: 0,
    lastEventId: null,
    affectedDateKeys: <String>[],
    seenEventIds: <String>[],
  );

  final bool hasUnread;
  final bool hasPageNotice;
  final int revision;
  final String? lastEventId;
  final List<String> affectedDateKeys;
  final List<String> seenEventIds;

  Map<String, Object?> toMap() => <String, Object?>{
    'has_unread': hasUnread,
    'has_page_notice': hasPageNotice,
    'revision': revision,
    'last_event_id': lastEventId,
    'affected_date_keys': affectedDateKeys,
    'seen_event_ids': seenEventIds,
  };
}

abstract interface class MilkPlanChangePersistence {
  Future<MilkPlanPendingState?> read();

  Future<void> write(MilkPlanPendingState state);
}

class MilkPlanChangeStore extends ChangeNotifier {
  MilkPlanChangeStore({this.persistence})
    : _restoreCompleted = persistence == null;

  final MilkPlanChangePersistence? persistence;
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  final LinkedHashSet<String> _affectedDateKeys = LinkedHashSet<String>();
  final List<MilkPlanChange> _pendingRestoreChanges = <MilkPlanChange>[];
  final Set<String> _pendingRestoreEventIds = <String>{};
  bool _hasUnread = false;
  bool _hasPageNotice = false;
  int _revision = 0;
  String? _lastEventId;
  bool _restoreCompleted;
  Future<void>? _restoreFuture;
  Future<void> _persistenceTail = Future<void>.value();

  bool get hasUnread => _hasUnread;
  bool get hasPageNotice => _hasPageNotice;
  int get revision => _revision;
  String? get lastEventId => _lastEventId;
  List<String> get affectedDateKeys =>
      List<String>.unmodifiable(_affectedDateKeys);

  Future<void> restore() {
    if (_restoreCompleted) return Future<void>.value();
    return _restoreFuture ??= _restore();
  }

  Future<void> _restore() async {
    MilkPlanPendingState? restored;
    try {
      restored = await persistence?.read();
    } catch (_) {
      // In-memory changes remain usable if secure persistence is unavailable.
    }
    if (restored != null) {
      _mergeSeenEventIds(restored.seenEventIds);
      _affectedDateKeys.addAll(restored.affectedDateKeys);
      _hasUnread = restored.hasUnread;
      _hasPageNotice = restored.hasPageNotice;
      _revision = restored.revision;
      _lastEventId = restored.lastEventId;
    }
    _restoreCompleted = true;
    final queued = List<MilkPlanChange>.of(_pendingRestoreChanges);
    _pendingRestoreChanges.clear();
    _pendingRestoreEventIds.clear();
    var changed = restored != null;
    for (final change in queued) {
      if (_seenEventIds.contains(change.eventId)) continue;
      _recordNow(change, notify: false, persist: false);
      changed = true;
    }
    if (changed) notifyListeners();
    if (queued.isNotEmpty) _schedulePersistence();
  }

  bool record(MilkPlanChange change) {
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
    MilkPlanChange change, {
    bool notify = true,
    bool persist = true,
  }) {
    _rememberEventId(change.eventId);
    _mergeAffectedDateKeys(change.affectedDateKeys);
    _revision += 1;
    _lastEventId = change.eventId;
    _hasUnread = true;
    _hasPageNotice = false;
    if (notify) notifyListeners();
    if (persist) _schedulePersistence();
    return true;
  }

  void transferNavigationNoticeToPage() {
    if (!_hasUnread) return;
    _hasUnread = false;
    _hasPageNotice = true;
    notifyListeners();
    _schedulePersistence();
  }

  void clearPageNotice() {
    if (!_hasPageNotice) return;
    _hasPageNotice = false;
    _affectedDateKeys.clear();
    notifyListeners();
    _schedulePersistence();
  }

  void restoreNavigationNotice() {
    if (!_hasPageNotice) return;
    _hasPageNotice = false;
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
        // Keep the current in-memory notice usable.
      }
    });
  }

  MilkPlanPendingState _snapshot() => MilkPlanPendingState(
    hasUnread: _hasUnread,
    hasPageNotice: _hasPageNotice,
    revision: _revision,
    lastEventId: _lastEventId,
    affectedDateKeys: affectedDateKeys,
    seenEventIds: List<String>.unmodifiable(_seenEventIds),
  );

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

  void _mergeAffectedDateKeys(Iterable<String> dateKeys) {
    final merged = <String>{..._affectedDateKeys, ...dateKeys}.toList()..sort();
    _affectedDateKeys.clear();
    for (final dateKey in merged.take(_maxAffectedDates)) {
      _affectedDateKeys.add(dateKey);
    }
  }
}

List<String> _boundedDateKeys(Object? value) {
  final result = <String>[];
  if (value is! List) return result;
  for (final item in value) {
    final dateKey = _dateKey(item);
    if (dateKey == null || result.contains(dateKey)) continue;
    result.add(dateKey);
    if (result.length == _maxAffectedDates) break;
  }
  result.sort();
  return result;
}

String? _dateKey(Object? value) {
  final raw = _string(value);
  if (raw == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
    return null;
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null ||
      '${parsed.year.toString().padLeft(4, '0')}-'
              '${parsed.month.toString().padLeft(2, '0')}-'
              '${parsed.day.toString().padLeft(2, '0')}' !=
          raw) {
    return null;
  }
  return raw;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
