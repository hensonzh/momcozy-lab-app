import 'package:flutter/foundation.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../domain/shared/record_deletion.dart';
import '../../../domain/shared/resource_state.dart';
import '../../../shared/zoned_time.dart';

class BabyRecordsController extends ChangeNotifier {
  BabyRecordsController({
    required this.repository,
    required this.baby,
    required this.timezone,
    required this.now,
    this.kind = BabyRecordKind.feeding,
  }) : month = LocalDate(
         dateInTimezone(now(), timezone).year,
         dateInTimezone(now(), timezone).month,
         1,
       );
  final BabyRecordRepository repository;
  final BabyProfile baby;
  final String timezone;
  final DateTime Function() now;
  BabyRecordKind kind;
  LocalDate month;
  ResourceState<List<BabyRecord>> records = const ResourceState.loading();
  int total = 0, _generation = 0;
  bool loadingMore = false, busy = false, _disposed = false;
  ProductFailure? mutationFailure, pageFailure;
  BabyRecord? _pendingDelete;
  RecordDeletion? deletion;
  bool _pendingRestore = false;
  bool get uncertainMutation => _pendingDelete != null || _pendingRestore;
  bool get canChange => !busy && !uncertainMutation;
  bool get hasMore => (records.value?.length ?? 0) < total;

  Future<void> select({BabyRecordKind? kind, LocalDate? month}) async {
    if (!canChange) return;
    this.kind = kind ?? this.kind;
    this.month = month == null
        ? this.month
        : LocalDate(month.year, month.month, 1);
    await load();
  }

  Future<void> load() async {
    if (!canChange) return;
    final generation = ++_generation;
    records = const ResourceState.loading();
    total = 0;
    loadingMore = false;
    pageFailure = null;
    notifyListeners();
    try {
      final page = await _page(0);
      if (!_current(generation)) return;
      records = ResourceState(value: page.items);
      total = page.total;
    } catch (error) {
      if (!_current(generation)) return;
      records = ResourceState(failure: _failure(error));
    }
    if (_current(generation)) notifyListeners();
  }

  Future<void> more() async {
    if (!canChange || loadingMore || !hasMore || records.value == null) return;
    final generation = _generation, current = records.value!;
    loadingMore = true;
    pageFailure = null;
    notifyListeners();
    try {
      final page = await _page(current.length);
      if (!_current(generation)) return;
      final combined = [...current, ...page.items];
      if (page.total != total ||
          combined.map((value) => value.id).toSet().length != combined.length ||
          page.items.isEmpty && combined.length < total) {
        throw const ProductFailure(ProductFailureKind.conflict);
      }
      records = ResourceState(value: List.unmodifiable(combined));
    } catch (error) {
      if (_current(generation)) pageFailure = _failure(error);
    }
    if (_current(generation)) {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<BabyRecordPage> _page(int offset) async {
    final page = await repository.list(
      babyId: baby.id,
      startDate: month,
      endDate: month.addMonths(1),
      timezone: timezone,
      kind: kind,
      offset: offset,
      limit: 50,
    );
    if (page.items.any(
      (value) => value.babyId != baby.id || value.recordKind != kind,
    )) {
      throw const ProductFailure(ProductFailureKind.unavailable);
    }
    return page;
  }

  Future<bool> delete(BabyRecord record) async {
    if (busy ||
        _disposed ||
        _pendingRestore ||
        record.babyId != baby.id ||
        _pendingDelete != null && _pendingDelete!.id != record.id) {
      return false;
    }
    _pendingDelete ??= record;
    busy = true;
    mutationFailure = null;
    notifyListeners();
    try {
      final receipt = await repository.delete(
        record.id,
        babyId: baby.id,
        expectedVersion: _pendingDelete!.version,
      );
      if (_disposed) return false;
      _pendingDelete = null;
      deletion = receipt;
      final values = records.value;
      if (values != null && values.any((value) => value.id == record.id)) {
        records = ResourceState(
          value: List.unmodifiable(
            values.where((value) => value.id != record.id),
          ),
        );
        total--;
      }
      return true;
    } catch (error) {
      if (!_disposed) {
        mutationFailure = _failure(error);
        if (!_uncertain(mutationFailure!)) _pendingDelete = null;
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> undo() async {
    final receipt = deletion;
    if (receipt == null || busy || _disposed || _pendingDelete != null) {
      return false;
    }
    _pendingRestore = true;
    busy = true;
    mutationFailure = null;
    notifyListeners();
    var restored = false;
    try {
      await repository.restore(
        receipt.id,
        babyId: baby.id,
        expectedVersion: receipt.version,
      );
      if (_disposed) return false;
      deletion = null;
      _pendingRestore = false;
      restored = true;
    } catch (error) {
      if (!_disposed) {
        mutationFailure = _failure(error);
        if (!_uncertain(mutationFailure!)) _pendingRestore = false;
      }
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
    if (restored) await load();
    return restored;
  }

  Future<void> retryMutation() async {
    final record = _pendingDelete;
    if (record != null) {
      await delete(record);
    } else if (_pendingRestore) {
      await undo();
    }
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  bool _uncertain(ProductFailure error) => [
    ProductFailureKind.offline,
    ProductFailureKind.unavailable,
  ].contains(error.kind);
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
