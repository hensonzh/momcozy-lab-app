import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

class HospitalBagCartStore extends ChangeNotifier {
  HospitalBagCartStore();

  static const defaultCartId = 'default';

  final Map<String, HospitalBagCartSnapshot> _snapshots = {
    defaultCartId: defaultHospitalBagCartSnapshot,
  };
  final Set<String> _customizedCartIds = <String>{};
  String? _activeCartId;

  String? get activeCartId => _activeCartId;

  Map<String, Object?>? get agentClientContext {
    final cartId = _activeCartId;
    if (cartId == null) return null;
    return {'hospital_bag_cart': snapshot(cartId).toAgentContext()};
  }

  HospitalBagCartSnapshot snapshot(String cartId) {
    return _snapshots[cartId] ?? defaultHospitalBagCartSnapshot;
  }

  String ingestArtifact(HospitalBagCartArtifactSeed seed) {
    final cartId = 'artifact:${_stableId(seed.artifactId)}';
    _snapshots[cartId] = seed.snapshot;
    _customizedCartIds.add(cartId);
    _activeCartId = cartId;
    notifyListeners();
    return cartId;
  }

  String activate([String? requestedCartId]) {
    final requested = requestedCartId?.trim();
    final resolved = requested != null && _snapshots.containsKey(requested)
        ? requested
        : defaultCartId;
    if (_activeCartId != resolved) {
      _activeCartId = resolved;
      notifyListeners();
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
    notifyListeners();
    return true;
  }

  void reset(String cartId) {
    _snapshots[cartId] = defaultHospitalBagCartSnapshot;
    _customizedCartIds.remove(cartId);
    _activeCartId = cartId;
    notifyListeners();
  }

  bool canReset(String cartId) => _customizedCartIds.contains(cartId);

  void clearForNewSession() {
    _snapshots
      ..clear()
      ..[defaultCartId] = defaultHospitalBagCartSnapshot;
    _customizedCartIds.clear();
    _activeCartId = null;
    notifyListeners();
  }
}

String _stableId(String value) {
  final normalized = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
  return normalized.isEmpty ? 'cart' : normalized;
}
