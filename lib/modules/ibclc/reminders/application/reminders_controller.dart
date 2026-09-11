import 'package:flutter/foundation.dart';
import '../../../../domain/ibclc/workbench_reminder.dart';
import '../../../../domain/shared/product_failure.dart';

class WorkbenchRemindersController extends ChangeNotifier {
  WorkbenchRemindersController(this.repository);
  final WorkbenchRemindersRepository repository;
  WorkbenchReminders? data;
  ProductFailure? failure;
  int offset = 0, _generation = 0;
  bool loading = false, _disposed = false;
  String? readingId;
  bool get busy => loading || readingId != null;

  Future<void> load() async {
    if (readingId != null) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.reminders(offset: offset);
      if (_disposed || generation != _generation) return;
      if (result.total > 0 && result.offset >= result.total) {
        offset = ((result.total - 1) ~/ result.limit) * result.limit;
        return load();
      }
      data = result;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      data = null;
      failure = _failure(error);
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> markRead(WorkbenchReminder item) async {
    if (busy) return false;
    if (item.readAt != null) return true;
    final generation = ++_generation;
    readingId = item.event.id;
    failure = null;
    notifyListeners();
    try {
      await repository.readReminder(item.event.id);
      if (_disposed || generation != _generation) return false;
      readingId = null;
      await load();
      return failure == null;
    } catch (error) {
      if (_disposed || generation != _generation) return false;
      readingId = null;
      data = null;
      failure = _failure(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> page(int direction) {
    final current = data;
    if (current == null || busy) return Future.value();
    final next = offset + direction * current.limit;
    if (next < 0 || next >= current.total) return Future.value();
    offset = next;
    data = null;
    return load();
  }

  ProductFailure _failure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
