import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';

const _maxIbclcConsultCompletions = 50;

abstract interface class IbclcConsultPersistence {
  Future<List<IbclcConsultCompletion>> read();

  Future<void> write(List<IbclcConsultCompletion> completions);
}

class FlutterSecureIbclcConsultPersistence implements IbclcConsultPersistence {
  const FlutterSecureIbclcConsultPersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.ibclc.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<List<IbclcConsultCompletion>> read() async {
    final raw = await storage.read(key: _key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final completions = <IbclcConsultCompletion>[];
      for (final value in decoded) {
        try {
          completions.add(IbclcConsultCompletion.fromMap(value));
        } catch (_) {
          // Ignore malformed historical entries without losing valid ones.
        }
      }
      return completions;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<IbclcConsultCompletion> completions) {
    return storage.write(
      key: _key,
      value: jsonEncode(
        completions.map((completion) => completion.toMap()).toList(),
      ),
    );
  }

  String get _key {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.completions';
  }
}

class IbclcConsultStore extends ChangeNotifier {
  IbclcConsultStore({required this.persistence, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  factory IbclcConsultStore.inMemory({DateTime Function()? now}) {
    return IbclcConsultStore(
      persistence: const _InMemoryIbclcConsultPersistence(),
      now: now,
    );
  }

  final IbclcConsultPersistence persistence;
  final DateTime Function() _now;
  final Map<String, IbclcConsultCompletion> _completions = {};
  Future<void>? _restoreFuture;
  Future<void> _persistenceTail = Future<void>.value();
  IbclcConsultRouteState? _activeRouteState;
  IbclcConsultRouteState? _lastCompletedRouteState;
  int _completionRevision = 0;

  IbclcConsultRouteState? get activeRouteState => _activeRouteState;

  IbclcConsultRouteState? get lastCompletedRouteState =>
      _lastCompletedRouteState;

  int get completionRevision => _completionRevision;

  List<IbclcConsultCompletion> get completions =>
      List<IbclcConsultCompletion>.unmodifiable(_orderedCompletions());

  bool isCompleted(String consultId) {
    final normalized = consultId.trim();
    return normalized.isNotEmpty && _completions.containsKey(normalized);
  }

  void beginConsult(IbclcConsultRouteState routeState) {
    _activeRouteState = routeState;
  }

  Future<void> restore() {
    return _restoreFuture ??= _restore();
  }

  Future<void> _restore() async {
    List<IbclcConsultCompletion> restored;
    try {
      restored = await persistence.read();
    } catch (_) {
      return;
    }
    var changed = false;
    for (final completion in restored) {
      if (_completions.containsKey(completion.consultId)) continue;
      _completions[completion.consultId] = completion;
      changed = true;
    }
    _trimCompletions();
    if (changed) notifyListeners();
  }

  Future<void> markCompleted(IbclcConsultRouteState routeState) async {
    final consultId = routeState.consultId.trim();
    if (consultId.isEmpty) return;
    _completions.remove(consultId);
    _completions[consultId] = IbclcConsultCompletion(
      consultId: consultId,
      threadId: routeState.threadId.trim(),
      completedAt: _now(),
    );
    _trimCompletions();
    _activeRouteState = null;
    _lastCompletedRouteState = routeState;
    _completionRevision += 1;
    notifyListeners();
    await restore();
    final snapshot = _orderedCompletions();
    _persistenceTail = _persistenceTail.then((_) async {
      try {
        await persistence.write(snapshot);
      } catch (_) {
        // Completion remains valid in memory when local persistence is unavailable.
      }
    });
    await _persistenceTail;
  }

  List<IbclcConsultCompletion> _orderedCompletions() {
    final values = _completions.values.toList(growable: false)
      ..sort((left, right) => left.completedAt.compareTo(right.completedAt));
    return values;
  }

  void _trimCompletions() {
    final ordered = _orderedCompletions();
    final overflow = ordered.length - _maxIbclcConsultCompletions;
    if (overflow <= 0) return;
    for (final completion in ordered.take(overflow)) {
      _completions.remove(completion.consultId);
    }
  }
}

class _InMemoryIbclcConsultPersistence implements IbclcConsultPersistence {
  const _InMemoryIbclcConsultPersistence();

  @override
  Future<List<IbclcConsultCompletion>> read() async => const [];

  @override
  Future<void> write(List<IbclcConsultCompletion> completions) async {}
}
