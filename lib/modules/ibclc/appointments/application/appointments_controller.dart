import 'package:flutter/foundation.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/local_date.dart';
import '../../../../domain/shared/product_failure.dart';

class WorkbenchAppointmentsController extends ChangeNotifier {
  WorkbenchAppointmentsController(this.repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final WorkbenchRepository repository;
  final DateTime Function() _now;
  LocalDate? date;
  WorkbenchAppointments? data;
  ProductFailure? failure;
  bool loading = false, _disposed = false;
  int offset = 0, _generation = 0;
  Duration _clockOffset = Duration.zero;
  DateTime get now => _now().add(_clockOffset);

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.appointments(date: date, offset: offset);
      if (_disposed || generation != _generation) return;
      if (result.total > 0 && result.offset >= result.total) {
        offset = ((result.total - 1) ~/ result.limit) * result.limit;
        return load();
      }
      data = result;
      _clockOffset = result.serverTime.difference(_now());
    } catch (error) {
      if (_disposed || generation != _generation) return;
      data = null;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> selectDate(LocalDate? value) {
    date = value;
    offset = 0;
    data = null;
    return load();
  }

  Future<void> page(int direction) {
    final current = data;
    if (current == null || loading) return Future.value();
    final next = offset + direction * current.limit;
    if (next < 0 || next >= current.total) return Future.value();
    offset = next;
    data = null;
    return load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
