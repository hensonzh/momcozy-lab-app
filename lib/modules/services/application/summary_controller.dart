import 'package:flutter/foundation.dart';
import '../../../domain/care/care_plan.dart';
import '../../../domain/care/documentation.dart';
import '../../../domain/shared/product_failure.dart';

typedef _TaskUpdate = ({
  String publicationId,
  String sourceKey,
  int version,
  CareTaskStatus status,
});

class CareSummaryController extends ChangeNotifier {
  CareSummaryController({
    required this.repository,
    required this.appointmentId,
  });
  final PatientCarePlanRepository repository;
  final String appointmentId;
  PatientCareSummary? data;
  ProductFailure? failure;
  bool loading = false, busy = false, needsReload = false;
  bool _disposed = false;
  int _generation = 0;
  _TaskUpdate? _pending;
  bool get uncertain => _pending != null;
  bool get canUpdate => !loading && !busy && !uncertain && !needsReload;

  Future<void> load() async {
    if (busy || uncertain) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.summary(appointmentId);
      if (_disposed || generation != _generation) return;
      data = result;
      needsReload = false;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _failed(error);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> update(PublishedCareTask task, CareTaskStatus status) async {
    if (!canUpdate || data?.publication == null || task.status == status) {
      return;
    }
    _pending = (
      publicationId: data!.publication!.id,
      sourceKey: task.content.sourceKey,
      version: task.progressVersion,
      status: status,
    );
    await _submit();
  }

  Future<void> retry() => _pending == null ? load() : _submit();

  Future<void> _submit() async {
    if (busy || _pending == null) return;
    final update = _pending!;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final publication = await repository.updateTask(
        update.publicationId,
        update.sourceKey,
        expectedVersion: update.version,
        status: update.status,
      );
      if (_disposed) return;
      data = PatientCareSummary(
        episode: data!.episode,
        appointment: data!.appointment,
        consultation: data!.consultation,
        publication: publication,
      );
      _pending = null;
    } catch (error) {
      if (_disposed) return;
      _failed(error);
    }
    busy = false;
    notifyListeners();
  }

  void _failed(Object error) {
    failure = error is ProductFailure
        ? error
        : const ProductFailure(ProductFailureKind.unavailable);
    if (![
      ProductFailureKind.offline,
      ProductFailureKind.unavailable,
    ].contains(failure!.kind)) {
      _pending = null;
    }
    if (failure!.kind == ProductFailureKind.conflict) needsReload = true;
    if ([
      ProductFailureKind.unauthenticated,
      ProductFailureKind.forbidden,
    ].contains(failure!.kind)) {
      data = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
