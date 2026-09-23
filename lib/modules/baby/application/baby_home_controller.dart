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
    this.deliveryDateProvider,
    BabyHomeSnapshot? snapshot,
  }) : _selectedId = selectedBabyId ?? snapshot?.selectedId {
    if (snapshot == null) return;
    if (snapshot.profiles.hasValue) profiles = snapshot.profiles;
    timezone = snapshot.timezone;
    deliveryDate = snapshot.deliveryDate;
    date = timezone == null ? null : dateInTimezone(now(), timezone!);
    if (_selectedId == snapshot.selectedId) {
      if (snapshot.latestGrowth.hasValue) latestGrowth = snapshot.latestGrowth;
      if (snapshot.growthCurve.hasValue) growthCurve = snapshot.growthCurve;
      if (date == snapshot.date && snapshot.recentRecords.hasValue) {
        recentRecords = snapshot.recentRecords;
      }
    }
  }
  final BabyProfileRepository profileRepository;
  final BabyRecordRepository recordRepository;
  final Future<String> Function() timezoneProvider;
  final DateTime Function() now;
  final Future<LocalDate?> Function()? deliveryDateProvider;
  LocalDate? deliveryDate;
  String? _selectedId;
  String? timezone;
  LocalDate? date;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _loading;
  final _readRequests = <String, int>{};
  BabyHomeSnapshot get snapshot => BabyHomeSnapshot(this);
  ResourceState<List<BabyProfile>> profiles = const ResourceState.loading();
  ResourceState<List<BabyRecord>> recentRecords = const ResourceState.loading();
  ResourceState<List<BabyGrowthRecord>> latestGrowth =
      const ResourceState.loading();
  ResourceState<List<BabyGrowthRecord>> growthCurve =
      const ResourceState.loading();
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

  Future<void> load({String? selectedBabyId}) {
    final requested = selectedBabyId ?? _selectedId;
    if (_loading != null && requested == _selectedId) return _loading!;
    final task = _load(requested);
    _loading = task;
    return task.whenComplete(() {
      if (identical(_loading, task)) _loading = null;
    });
  }

  Future<void> _load(String? selectedBabyId) async {
    final previousBaby = baby;
    final previousZone = timezone;
    final previousDate = date;
    _selectedId = selectedBabyId;
    final generation = ++_generation;
    profiles = ResourceState.loading(profiles.value);
    if (previousBaby?.id != _selectedId) _clearRecords();
    if (timezone != null && dateInTimezone(now(), timezone!) != date) {
      date = dateInTimezone(now(), timezone!);
      recentRecords = const ResourceState.loading();
    }
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        profileRepository.list(),
        timezoneProvider(),
        deliveryDateProvider?.call() ?? Future<LocalDate?>.value(),
      ]);
      if (!_current(generation)) return;
      final values = results[0] as List<BabyProfile>,
          zone = results[1] as String;
      deliveryDate = results[2] as LocalDate?;
      profiles = ResourceState(value: values);
      timezone = zone;
      date = dateInTimezone(now(), zone);
      if (!values.any((value) => value.id == _selectedId)) {
        _selectedId = values.firstOrNull?.id;
      }
      if (baby?.id != previousBaby?.id) {
        _clearRecords();
      } else {
        if (date != previousDate || zone != previousZone) {
          recentRecords = const ResourceState.loading();
        }
        if (baby?.birthDate != previousBaby?.birthDate) {
          growthCurve = const ResourceState.loading();
        }
      }
      notifyListeners();
      await _loadRecords(generation);
    } catch (error) {
      if (!_current(generation)) return;
      final failure = _failure(error);
      profiles = ResourceState(
        value: _canRetain(failure) ? profiles.value : null,
        failure: failure,
      );
      if (!profiles.hasValue) _clearRecords();
      notifyListeners();
    }
  }

  Future<void> select(String id) async {
    if (profiles.value?.any((value) => value.id == id) != true ||
        _selectedId == id) {
      return;
    }
    _selectedId = id;
    _loading = null;
    final generation = ++_generation;
    _clearRecords();
    notifyListeners();
    await _loadRecords(generation);
  }

  Future<void> applySavedProfile(BabyProfile saved) async {
    final previous = baby;
    _generation++;
    _loading = null;
    profiles = ResourceState(
      value: [
        ...?profiles.value?.where((value) => value.id != saved.id),
        saved,
      ],
    );
    if (previous?.id != saved.id) {
      await select(saved.id);
      return;
    }
    if (previous?.birthDate != saved.birthDate) {
      growthCurve = const ResourceState.loading();
    }
    notifyListeners();
    await _loadRecords(
      _generation,
      recent: !recentRecords.hasValue,
      growth: !latestGrowth.hasValue || !growthCurve.hasValue,
    );
  }

  Future<void> refreshRecords({BabyRecordKind? kind}) async {
    if (_disposed || baby == null || timezone == null) return;
    final day = dateInTimezone(now(), timezone!);
    final changedDay = date != day;
    date = day;
    if (changedDay) {
      recentRecords = const ResourceState.loading();
      _generation++;
    }
    final generation = _generation;
    notifyListeners();
    await _loadRecords(
      generation,
      recent: changedDay || kind != BabyRecordKind.growth,
      growth: changedDay || kind == null || kind == BabyRecordKind.growth,
    );
  }

  void tick() {
    if (_disposed || timezone == null || date == null) return;
    if (dateInTimezone(now(), timezone!) != date) {
      refreshRecords();
      return;
    }
    notifyListeners();
  }

  Future<void> _loadRecords(
    int generation, {
    bool recent = true,
    bool growth = true,
  }) async {
    final selected = baby, zone = timezone, day = date;
    if (selected == null || zone == null || day == null) return;
    final birth = selected.birthDate;
    final curveEnd = birth?.addMonths(6).addDays(1);
    await Future.wait([
      if (recent)
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
          recentRecords,
          'recent',
        ),
      if (growth)
        _fetch(
          () => recordRepository.latestGrowth(selected.id),
          (value) => latestGrowth = value,
          generation,
          latestGrowth,
          'latest',
        ),
      if (growth)
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
          growthCurve,
          'curve',
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
    ResourceState<T> previous,
    String resource,
  ) async {
    final request = (_readRequests[resource] ?? 0) + 1;
    _readRequests[resource] = request;
    bool current() =>
        _current(generation) && _readRequests[resource] == request;
    try {
      final value = await read();
      if (current()) update(ResourceState(value: value));
    } catch (error) {
      if (current()) {
        final failure = _failure(error);
        update(
          ResourceState(
            value: _canRetain(failure) ? previous.value : null,
            failure: failure,
          ),
        );
      }
    }
    if (_current(generation)) notifyListeners();
  }

  bool _canRetain(ProductFailure failure) =>
      failure.kind != ProductFailureKind.unauthenticated &&
      failure.kind != ProductFailureKind.forbidden;
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

/// Immutable, runtime-scoped view data. No controller or timer is cached.
class BabyHomeSnapshot {
  BabyHomeSnapshot(BabyHomeController c)
    : selectedId = c._selectedId,
      timezone = c.timezone,
      date = c.date,
      deliveryDate = c.deliveryDate,
      profiles = ResourceState(value: c.profiles.value),
      recentRecords = ResourceState(value: c.recentRecords.value),
      latestGrowth = ResourceState(value: c.latestGrowth.value),
      growthCurve = ResourceState(value: c.growthCurve.value);
  final String? selectedId, timezone;
  final LocalDate? date, deliveryDate;
  final ResourceState<List<BabyProfile>> profiles;
  final ResourceState<List<BabyRecord>> recentRecords;
  final ResourceState<List<BabyGrowthRecord>> latestGrowth, growthCurve;
}
