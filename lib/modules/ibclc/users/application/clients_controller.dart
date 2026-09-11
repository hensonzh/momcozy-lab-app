import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/ibclc/workbench.dart';
import '../../../../domain/shared/product_failure.dart';

class WorkbenchClientsController extends ChangeNotifier {
  WorkbenchClientsController(this.repository);
  final WorkbenchRepository repository;
  WorkbenchClients? data;
  ProductFailure? failure;
  String query = '';
  WorkbenchClientFilter filter = WorkbenchClientFilter.all;
  int offset = 0, _generation = 0;
  bool loading = false, _disposed = false;
  Timer? _debounce;
  Future<void> load() async {
    _debounce?.cancel();
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.clients(
        query: query,
        filter: filter,
        offset: offset,
      );
      if (_disposed || generation != _generation) return;
      if (result.total > 0 && result.offset >= result.total) {
        offset = ((result.total - 1) ~/ result.limit) * result.limit;
        return load();
      }
      data = result;
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

  void search(String value) {
    query = value.trim();
    offset = 0;
    data = null;
    failure = null;
    loading = true;
    _generation++;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(load()),
    );
    notifyListeners();
  }

  Future<void> setFilter(WorkbenchClientFilter value) {
    filter = value;
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
    _debounce?.cancel();
    super.dispose();
  }
}

class WorkbenchClientController extends ChangeNotifier {
  WorkbenchClientController(this.repository, this.patientRef);
  final WorkbenchRepository repository;
  final String patientRef;
  WorkbenchClientDetail? data;
  ProductFailure? failure;
  int offset = 0, _generation = 0;
  bool loading = false, _disposed = false;
  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.client(patientRef, offset: offset);
      if (_disposed || generation != _generation) return;
      if (result.appointmentTotal > 0 &&
          result.offset >= result.appointmentTotal) {
        offset = ((result.appointmentTotal - 1) ~/ result.limit) * result.limit;
        return load();
      }
      data = result;
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

  Future<void> page(int direction) {
    final current = data;
    if (current == null || loading) return Future.value();
    final next = offset + direction * current.limit;
    if (next < 0 || next >= current.appointmentTotal) return Future.value();
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
