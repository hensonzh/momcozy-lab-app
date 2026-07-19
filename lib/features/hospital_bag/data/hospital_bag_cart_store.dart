import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

const _maxPersistedHospitalBagCarts = 24;

class HospitalBagCartPersistedState {
  const HospitalBagCartPersistedState({
    required this.snapshots,
    required this.customizedCartIds,
    required this.activeCartId,
  });

  final Map<String, HospitalBagCartSnapshot> snapshots;
  final Set<String> customizedCartIds;
  final String? activeCartId;

  static HospitalBagCartPersistedState? tryFromMap(Object? value) {
    if (value is! Map) return null;
    final rawSnapshots = value['snapshots'];
    if (rawSnapshots is! Map) return null;
    final snapshots = <String, HospitalBagCartSnapshot>{};
    for (final entry in rawSnapshots.entries.take(
      _maxPersistedHospitalBagCarts,
    )) {
      final cartId = entry.key is String ? (entry.key as String).trim() : '';
      final snapshot = HospitalBagCartSnapshot.tryFromCartUpdate(entry.value);
      if (cartId.isNotEmpty && snapshot != null) snapshots[cartId] = snapshot;
    }
    final rawCustomized = value['customized_cart_ids'];
    final customized = rawCustomized is List
        ? rawCustomized
              .whereType<String>()
              .map((value) => value.trim())
              .where(snapshots.containsKey)
              .toSet()
        : <String>{};
    final rawActive = value['active_cart_id'];
    final activeCartId =
        rawActive is String &&
            (rawActive == HospitalBagCartStore.defaultCartId ||
                snapshots.containsKey(rawActive))
        ? rawActive
        : null;
    return HospitalBagCartPersistedState(
      snapshots: snapshots,
      customizedCartIds: customized,
      activeCartId: activeCartId,
    );
  }

  Map<String, Object?> toMap() => {
    'version': 1,
    'snapshots': snapshots.map(
      (cartId, snapshot) => MapEntry(cartId, snapshot.toAgentContext()),
    ),
    'customized_cart_ids': customizedCartIds.toList(growable: false),
    if (activeCartId != null) 'active_cart_id': activeCartId,
  };
}

abstract interface class HospitalBagCartPersistence {
  Future<HospitalBagCartPersistedState?> read();

  Future<void> write(HospitalBagCartPersistedState state);
}

class FlutterSecureHospitalBagCartPersistence
    implements HospitalBagCartPersistence {
  const FlutterSecureHospitalBagCartPersistence({
    required this.userId,
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.hospital-bag-cart.v1',
  });

  final String userId;
  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<HospitalBagCartPersistedState?> read() async {
    final raw = await storage.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return HospitalBagCartPersistedState.tryFromMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(HospitalBagCartPersistedState state) {
    return storage.write(key: storageKey, value: jsonEncode(state.toMap()));
  }

  String get storageKey {
    final scope = userId.trim().isEmpty ? 'anonymous' : userId.trim();
    return '$namespace.user.${Uri.encodeComponent(scope)}.cart';
  }
}

class HospitalBagCartStore extends ChangeNotifier {
  HospitalBagCartStore({this.persistence})
    : _restoreCompleted = persistence == null;

  static const defaultCartId = 'default';

  final HospitalBagCartPersistence? persistence;

  final Map<String, HospitalBagCartSnapshot> _snapshots = {
    defaultCartId: defaultHospitalBagCartSnapshot,
  };
  final Set<String> _customizedCartIds = <String>{};
  final Set<String> _dirtyCartIds = <String>{};
  Future<bool>? _restoreFuture;
  Future<void> _persistenceTail = Future<void>.value();
  String? _activeCartId;
  bool _activeDirty = false;
  bool _clearedBeforeRestore = false;
  bool _restoreCompleted;

  String? get activeCartId => _activeCartId;

  Map<String, Object?>? get agentClientContext {
    final cartId = _activeCartId;
    if (cartId == null) return null;
    return {'hospital_bag_cart': snapshot(cartId).toAgentContext()};
  }

  HospitalBagCartSnapshot snapshot(String cartId) {
    return _snapshots[cartId] ?? defaultHospitalBagCartSnapshot;
  }

  Future<bool> restore() {
    if (_restoreCompleted) return Future<bool>.value(true);
    final pending = _restoreFuture;
    if (pending != null) return pending;
    late final Future<bool> restoreFuture;
    restoreFuture = _restore().whenComplete(() {
      if (identical(_restoreFuture, restoreFuture)) _restoreFuture = null;
    });
    _restoreFuture = restoreFuture;
    return restoreFuture;
  }

  Future<bool> _restore() async {
    final persistence = this.persistence;
    if (persistence == null) {
      _restoreCompleted = true;
      return true;
    }
    HospitalBagCartPersistedState? restored;
    try {
      restored = await persistence.read();
    } catch (_) {
      return false;
    }
    _restoreCompleted = true;
    if (restored == null || _clearedBeforeRestore) return true;
    var changed = false;
    for (final entry in restored.snapshots.entries) {
      if (_dirtyCartIds.contains(entry.key)) continue;
      _snapshots[entry.key] = entry.value;
      if (restored.customizedCartIds.contains(entry.key)) {
        _customizedCartIds.add(entry.key);
      } else {
        _customizedCartIds.remove(entry.key);
      }
      changed = true;
    }
    final restoredActiveCartId = restored.activeCartId;
    if (!_activeDirty &&
        restoredActiveCartId != null &&
        (restoredActiveCartId == defaultCartId ||
            _snapshots.containsKey(restoredActiveCartId))) {
      _activeCartId = restoredActiveCartId;
      changed = true;
    }
    if (changed) notifyListeners();
    return true;
  }

  String ingestArtifact(HospitalBagCartArtifactSeed seed) {
    final cartId = 'artifact:${_stableId(seed.artifactId)}';
    _snapshots[cartId] = seed.snapshot;
    _customizedCartIds.add(cartId);
    _activeCartId = cartId;
    _dirtyCartIds.add(cartId);
    _activeDirty = true;
    notifyListeners();
    unawaited(_schedulePersist());
    return cartId;
  }

  String activate([String? requestedCartId]) {
    final requested = requestedCartId?.trim();
    final resolved = requested != null && _snapshots.containsKey(requested)
        ? requested
        : defaultCartId;
    if (_activeCartId != resolved) {
      _activeCartId = resolved;
      _activeDirty = true;
      notifyListeners();
      unawaited(_schedulePersist());
    }
    return resolved;
  }

  bool removeItem({required String cartId, required String itemId}) {
    final current = snapshot(cartId);
    var removed = false;
    final groups = current.groups
        .map((group) {
          final items = group.items
              .where((item) {
                final shouldRemove = item.id == itemId;
                removed = removed || shouldRemove;
                return !shouldRemove;
              })
              .toList(growable: false);
          return group.copyWith(items: items);
        })
        .toList(growable: false);
    if (!removed) return false;

    _snapshots[cartId] = current.copyWithGroups(groups);
    _customizedCartIds.add(cartId);
    _activeCartId = cartId;
    _dirtyCartIds.add(cartId);
    _activeDirty = true;
    notifyListeners();
    unawaited(_schedulePersist());
    return true;
  }

  void reset(String cartId) {
    _snapshots[cartId] = defaultHospitalBagCartSnapshot;
    _customizedCartIds.remove(cartId);
    _activeCartId = cartId;
    _dirtyCartIds.add(cartId);
    _activeDirty = true;
    notifyListeners();
    unawaited(_schedulePersist());
  }

  bool canReset(String cartId) => _customizedCartIds.contains(cartId);

  Future<void> clearForNewSession() async {
    final previousSnapshots = Map<String, HospitalBagCartSnapshot>.of(
      _snapshots,
    );
    final previousCustomizedCartIds = Set<String>.of(_customizedCartIds);
    final previousDirtyCartIds = Set<String>.of(_dirtyCartIds);
    final previousActiveCartId = _activeCartId;
    final previousActiveDirty = _activeDirty;
    final previousClearedBeforeRestore = _clearedBeforeRestore;
    _snapshots
      ..clear()
      ..[defaultCartId] = defaultHospitalBagCartSnapshot;
    _customizedCartIds.clear();
    _dirtyCartIds.clear();
    _dirtyCartIds.add(defaultCartId);
    _activeCartId = null;
    _activeDirty = true;
    _clearedBeforeRestore = true;
    notifyListeners();
    try {
      await _schedulePersist(propagateErrors: true);
    } catch (_) {
      _snapshots
        ..clear()
        ..addAll(previousSnapshots);
      _customizedCartIds
        ..clear()
        ..addAll(previousCustomizedCartIds);
      _dirtyCartIds
        ..clear()
        ..addAll(previousDirtyCartIds);
      _activeCartId = previousActiveCartId;
      _activeDirty = previousActiveDirty;
      _clearedBeforeRestore = previousClearedBeforeRestore;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _schedulePersist({bool propagateErrors = false}) {
    final persistence = this.persistence;
    if (persistence == null) return Future<void>.value();
    final operation = _persistenceTail.then((_) async {
      final restored = await restore();
      if (!restored) {
        if (propagateErrors) {
          throw StateError('Hospital bag cart recovery is unavailable.');
        }
        return;
      }
      final snapshots = <String, HospitalBagCartSnapshot>{};
      final activeCartId = _activeCartId;
      if (activeCartId != null &&
          activeCartId != defaultCartId &&
          _snapshots.containsKey(activeCartId)) {
        snapshots[activeCartId] = _snapshots[activeCartId]!;
      }
      for (final entry in _snapshots.entries) {
        if (snapshots.containsKey(entry.key)) continue;
        if (entry.key == defaultCartId &&
            !_customizedCartIds.contains(defaultCartId)) {
          continue;
        }
        snapshots[entry.key] = entry.value;
        if (snapshots.length >= _maxPersistedHospitalBagCarts) break;
      }
      try {
        await persistence.write(
          HospitalBagCartPersistedState(
            snapshots: snapshots,
            customizedCartIds: _customizedCartIds
                .where(snapshots.containsKey)
                .toSet(),
            activeCartId: _activeCartId,
          ),
        );
      } catch (_) {
        if (propagateErrors) rethrow;
        // The in-memory cart remains usable when local persistence fails.
      }
    });
    _persistenceTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @visibleForTesting
  Future<void> flushPendingPersistence() => _persistenceTail;
}

String _stableId(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
  if (normalized.isEmpty) return 'cart';
  return normalized.length <= 128 ? normalized : normalized.substring(0, 128);
}
