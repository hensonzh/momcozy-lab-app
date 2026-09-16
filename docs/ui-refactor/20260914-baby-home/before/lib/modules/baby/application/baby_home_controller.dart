import 'package:flutter/foundation.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/baby/baby_record.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../domain/shared/resource_state.dart';
import '../../../shared/zoned_time.dart';

class BabyHomeController extends ChangeNotifier {
  BabyHomeController({
    required this.profileRepository,
    required this.recordRepository,
    required this.timezoneProvider,
    required this.now,
    String? selectedBabyId,
  }) : _selectedId = selectedBabyId;
  final BabyProfileRepository profileRepository;
  final BabyRecordRepository recordRepository;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() now;
  String? _selectedId;
  String? timezone;
  LocalDate? date;
  bool _disposed = false;
  int _generation = 0;
  ResourceState<List<BabyProfile>> profiles = const ResourceState.loading();
  ResourceState<List<BabyRecord>> recentRecords = const ResourceState.loading();
  ResourceState<List<BabyGrowthRecord>> latestGrowth =
      const ResourceState.loading();
  ResourceState<List<BabyGrowthRecord>> growthCurve =
      const ResourceState.loading();
  BabySavedFeedback? savedFeedback;

  void showSaved(List<BabyRecord> records, {required bool allowUndo}) {
    if (_disposed ||
        records.isEmpty ||
        records.any((r) => r.babyId != baby?.id)) {
      return;
    }
    savedFeedback = BabySavedFeedback(records, allowUndo: allowUndo);
    notifyListeners();
  }

  void dismissSaved() {
    if (savedFeedback?.busy == true || _disposed) return;
    savedFeedback = null;
    notifyListeners();
  }

  Future<void> undoSaved() async {
    final feedback = savedFeedback;
    if (_disposed || feedback == null || !feedback.canUndo) return;
    feedback.busy = true;
    feedback.failure = null;
    notifyListeners();
    try {
      while (feedback.pending.isNotEmpty) {
        final record = feedback.pending.first;
        await recordRepository.delete(
          record.id,
          babyId: record.babyId,
          expectedVersion: record.version,
        );
        feedback.pending.removeAt(0);
      }
      feedback.undone = true;
    } catch (error) {
      feedback.failure = _failure(error);
    } finally {
      feedback.busy = false;
      if (!_disposed && identical(savedFeedback, feedback)) {
        notifyListeners();
        await refreshRecords();
      }
    }
  }

  BabyProfile? get baby =>
      profiles.value?.where((value) => value.id == _selectedId).firstOrNull;
  BabyDaySummary? get summary {
    final id = baby?.id,
        records = recentRecords.value,
        zone = timezone,
        day = date;
    if (id == null || records == null || zone == null || day == null) {
      return null;
    }
    return BabyDaySummary.fromRecords(
      records,
      babyId: id,
      window: zonedDayWindow(day, zone),
      now: now(),
    );
  }

  Future<void> load({String? selectedBabyId}) async {
    _selectedId = selectedBabyId ?? _selectedId;
    final generation = ++_generation;
    profiles = const ResourceState.loading();
    _clearRecords();
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        profileRepository.list(),
        timezoneProvider(),
      ]);
      if (!_current(generation)) return;
      final values = results[0] as List<BabyProfile>,
          zone = results[1] as String;
      final day = dateInTimezone(now(), zone);
      profiles = ResourceState(value: values);
      timezone = zone;
      date = day;
      if (!values.any((value) => value.id == _selectedId)) {
        _selectedId = values.firstOrNull?.id;
      }
      if (savedFeedback?.babyId != baby?.id) savedFeedback = null;
      notifyListeners();
      await _loadRecords(generation);
    } catch (error) {
      if (!_current(generation)) return;
      profiles = ResourceState(failure: _failure(error));
      _clearRecords();
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    if (profiles.value?.any((value) => value.id == id) != true ||
        _selectedId == id) {
      return;
    }
    _selectedId = id;
    savedFeedback = null;
    final generation = ++_generation;
    _clearRecords();
    notifyListeners();
    await _loadRecords(generation);
  }

  Future<void> refreshRecords() async {
    if (baby == null || timezone == null) return;
    date = dateInTimezone(now(), timezone!);
    final generation = ++_generation;
    _clearRecords();
    notifyListeners();
    await _loadRecords(generation);
  }

  void tick() {
    if (_disposed || timezone == null || date == null) return;
    if (dateInTimezone(now(), timezone!) != date) {
      refreshRecords();
      return;
    }
    notifyListeners();
  }

  Future<void> _loadRecords(int generation) async {
    final selected = baby, zone = timezone, day = date;
    if (selected == null || zone == null || day == null) return;
    final birth = selected.birthDate;
    final curveEnd = birth?.addMonths(6).addDays(1);
    await Future.wait([
      _fetch(
        () => _all(
          selected.id,
          day.addDays(-2),
          day.addDays(1),
          zone,
          generation,
        ),
        (value) => recentRecords = value,
        generation,
      ),
      _fetch(
        () => recordRepository.latestGrowth(selected.id),
        (value) => latestGrowth = value,
        generation,
      ),
      _fetch(
        () async {
          if (birth == null || curveEnd == null || birth.compareTo(day) > 0) {
            return <BabyGrowthRecord>[];
          }
          final end = curveEnd.compareTo(day.addDays(1)) > 0
              ? day.addDays(1)
              : curveEnd;
          return (await _all(
            selected.id,
            birth,
            end,
            zone,
            generation,
            kind: BabyRecordKind.growth,
          )).cast<BabyGrowthRecord>();
        },
        (value) => growthCurve = value,
        generation,
      ),
    ]);
  }

  Future<List<BabyRecord>> _all(
    String id,
    LocalDate start,
    LocalDate end,
    String zone,
    int generation, {
    BabyRecordKind? kind,
  }) async {
    final records = <BabyRecord>[];
    int? total;
    do {
      final page = await recordRepository.list(
        babyId: id,
        startDate: start,
        endDate: end,
        timezone: zone,
        kind: kind,
        offset: records.length,
        limit: 200,
      );
      if (!_current(generation)) return const [];
      if (total != null && page.total != total) {
        throw const ProductFailure(ProductFailureKind.conflict);
      }
      total = page.total;
      if (page.items.isEmpty && records.length < total) {
        throw const ProductFailure(ProductFailureKind.unavailable);
      }
      records.addAll(page.items);
      if (records.any((value) => value.babyId != id) ||
          records.map((value) => value.id).toSet().length != records.length) {
        throw const ProductFailure(ProductFailureKind.unavailable);
      }
    } while (records.length < total);
    return List.unmodifiable(records);
  }

  Future<void> _fetch<T>(
    Future<T> Function() read,
    ValueChanged<ResourceState<T>> update,
    int generation,
  ) async {
    try {
      final value = await read();
      if (_current(generation)) update(ResourceState(value: value));
    } catch (error) {
      if (_current(generation)) update(ResourceState(failure: _failure(error)));
    }
    if (_current(generation)) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  ProductFailure _failure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  void _clearRecords() {
    recentRecords = const ResourceState.loading();
    latestGrowth = const ResourceState.loading();
    growthCurve = const ResourceState.loading();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Feedback belongs to exactly the newly saved records and their versions.
class BabySavedFeedback {
  BabySavedFeedback(List<BabyRecord> records, {required this.allowUndo})
    : records = List.unmodifiable(records),
      pending = List.of(records);
  final List<BabyRecord> records, pending;
  final bool allowUndo;
  bool busy = false, undone = false;
  ProductFailure? failure;
  String get babyId => records.first.babyId;
  bool get retryable =>
      failure == null ||
      failure!.kind == ProductFailureKind.offline ||
      failure!.kind == ProductFailureKind.unavailable;
  bool get canUndo => allowUndo && !busy && !undone && retryable;
  String get message {
    if (busy) return '正在撤销这次记录…';
    if (failure != null) {
      return retryable ? '撤销结果尚未确认，请重试确认。' : '记录已发生变化或暂时无法撤销，请到全部记录中核对。';
    }
    if (undone) return '已撤销这次记录。';
    return switch (records.first.recordKind) {
      BabyRecordKind.feeding => '这次喂养的时间和已填写数值已记下。',
      BabyRecordKind.diaper => '这次换尿布的情况已记下。',
      BabyRecordKind.sleep => '这段睡眠已记好。',
      BabyRecordKind.growth =>
        records.length > 1 ? '这次填写的生长测量已一起保存。' : '这次生长测量已保存。',
      BabyRecordKind.development => '具体行为和观察日期已记下。',
    };
  }
}
