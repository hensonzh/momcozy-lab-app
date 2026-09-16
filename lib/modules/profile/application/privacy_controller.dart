import 'package:flutter/foundation.dart';
import '../../../domain/care/intake.dart';
import '../../../domain/shared/product_failure.dart';

/// Matches the backend ConsentWrite policy literal; changes need a new review.
const privacyPolicyVersion = '2026-09-08';

class PrivacyController extends ChangeNotifier {
  PrivacyController({required this.repository, required this.episodeId});
  final IntakeRepository repository;
  final String episodeId;
  Map<CareConsentScope, CareConsent> current = {};
  Map<CareConsentScope, bool> draft = {};
  bool loading = true, busy = false, saved = false, needsReload = false;
  ProductFailure? failure;
  final _pending = <({CareConsentScope scope, bool active, int version})>[];
  bool _disposed = false;
  int _generation = 0;
  bool get uncertain => _pending.isNotEmpty;
  bool get dirty => CareConsentScope.values.any(
    (s) => (draft[s] ?? false) != (current[s]?.active ?? false),
  );
  bool get canEdit =>
      !loading && !busy && !uncertain && !needsReload && draft.isNotEmpty;
  List<CareConsentScope> get revokedRequired => [
    CareConsentScope.ibclcCase,
    CareConsentScope.video,
  ].where((s) => current[s]?.active == true && draft[s] == false).toList();

  Future<void> load() async {
    if (busy || _disposed) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    saved = false;
    notifyListeners();
    try {
      final values = await repository.consents(episodeId);
      if (_disposed || generation != _generation) return;
      if (values.any((c) => c.episodeId != episodeId) ||
          values.map((c) => c.scope).toSet().length != values.length) {
        throw const ProductFailure(ProductFailureKind.unavailable);
      }
      current = {for (final c in values) c.scope: c};
      draft = {
        for (final s in CareConsentScope.values) s: current[s]?.active ?? false,
      };
      _pending.clear();
      needsReload = false;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      failure = e is ProductFailure
          ? e
          : const ProductFailure(ProductFailureKind.unavailable);
      needsReload = true;
    }
    loading = false;
    notifyListeners();
  }

  void toggle(CareConsentScope scope, bool value) {
    if (!canEdit) return;
    draft[scope] = value;
    saved = false;
    failure = null;
    notifyListeners();
  }

  Future<void> save() async {
    if (_disposed || busy || loading || needsReload || (!dirty && !uncertain)) {
      return;
    }
    if (_pending.isEmpty) {
      for (final active in [false, true]) {
        for (final scope in CareConsentScope.values) {
          if (draft[scope] == active &&
              active != (current[scope]?.active ?? false)) {
            _pending.add((
              scope: scope,
              active: active,
              version: current[scope]?.version ?? 0,
            ));
          }
        }
      }
    }
    busy = true;
    failure = null;
    saved = false;
    notifyListeners();
    try {
      while (_pending.isNotEmpty) {
        final change = _pending.first;
        final result = await repository.setConsent(
          episodeId,
          scope: change.scope,
          active: change.active,
          expectedVersion: change.version,
          policyVersion: privacyPolicyVersion,
        );
        if (_disposed) return;
        if (result.episodeId != episodeId ||
            result.scope != change.scope ||
            result.active != change.active) {
          throw const ProductFailure(ProductFailureKind.unavailable);
        }
        current[change.scope] = result;
        _pending.removeAt(0);
      }
      saved = true;
    } catch (e) {
      if (_disposed) return;
      failure = e is ProductFailure
          ? e
          : const ProductFailure(ProductFailureKind.unavailable);
      if (![
        ProductFailureKind.offline,
        ProductFailureKind.unavailable,
      ].contains(failure!.kind)) {
        _pending.clear();
        needsReload = true;
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
