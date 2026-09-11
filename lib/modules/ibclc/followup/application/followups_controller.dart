import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../domain/ibclc/workbench_followup.dart';
import '../../../../domain/shared/product_failure.dart';

class WorkbenchFollowupsController extends ChangeNotifier {
  WorkbenchFollowupsController(
    this.repository, {
    this.query = '',
    this.filter = WorkbenchFollowupFilter.all,
  });
  final WorkbenchFollowupsRepository repository;
  WorkbenchFollowups? data;
  ProductFailure? failure;
  String query;
  WorkbenchFollowupFilter filter;
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
      final result = await repository.followups(
        query: query,
        filter: filter,
        offset: offset,
      );
      if (_disposed || generation != _generation) return;
      if (result.limit <= 0 ||
          result.offset != offset ||
          result.total < 0 ||
          result.pendingCount + result.completedCount != result.allCount) {
        throw const FormatException('Invalid follow-up page.');
      }
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

  Future<void> setFilter(WorkbenchFollowupFilter value) {
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
