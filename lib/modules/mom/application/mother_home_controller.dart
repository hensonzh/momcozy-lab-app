import 'package:flutter/foundation.dart';
import '../../../domain/lactation/lactation_record.dart';
import '../../../domain/mother/mother_diary.dart';
import '../../../domain/mother/mother_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../domain/shared/resource_state.dart';

class MotherHomeController extends ChangeNotifier {
  MotherHomeController({
    required this.profileRepository,
    required this.diaryRepository,
    required this.lactationRepository,
    required this.ownerUserId,
    required this.now,
  });
  final MotherProfileRepository profileRepository;
  final MotherDiaryRepository diaryRepository;
  final LactationRepository lactationRepository;
  final String ownerUserId;
  final DateTime Function() now;
  ResourceState<MotherProfile> profile = const ResourceState.loading();
  ResourceState<List<MotherDiaryEntry>> diaries = const ResourceState.loading();
  ResourceState<List<LactationRecord>> lactation =
      const ResourceState.loading();
  late LocalDate date = LocalDate.fromDateTime(now().toLocal());
  bool _disposed = false;
  int _generation = 0;

  MotherDiary? get todayDiary =>
      diaries.value?.where((entry) => entry.date == date).firstOrNull?.diary;
  LactationDaySummary? get milk => lactation.value == null
      ? null
      : LactationDaySummary.fromRecords(
          lactation.value!,
          ownerUserId: ownerUserId,
          window: date.localWindow,
        );

  Future<void> load() async {
    final generation = ++_generation;
    final nextDate = LocalDate.fromDateTime(now().toLocal());
    final sameDay = nextDate == date;
    date = nextDate;
    profile = ResourceState.loading(profile.value);
    diaries = ResourceState.loading(sameDay ? diaries.value : null);
    lactation = ResourceState.loading(sameDay ? lactation.value : null);
    notifyListeners();
    await Future.wait([
      _fetch(
        profileRepository.get,
        (value) => profile = value,
        generation,
        profile.value,
      ),
      _fetch(
        () async =>
            (await diaryRepository.list(start: date.addDays(-2), end: date))
                .where((entry) => entry.ownerUserId == ownerUserId)
                .toList(growable: false),
        (value) => diaries = value,
        generation,
        diaries.value,
      ),
      _fetch(
        () async =>
            (await lactationRepository.list(
                  DayWindow(
                    date.addDays(-2).localWindow.start,
                    date.localWindow.end,
                  ),
                ))
                .where((entry) => entry.ownerUserId == ownerUserId)
                .toList(growable: false),
        (value) => lactation = value,
        generation,
        lactation.value,
      ),
    ]);
  }

  Future<void> _fetch<T>(
    Future<T> Function() fetch,
    ValueChanged<ResourceState<T>> update,
    int generation,
    T? previous,
  ) async {
    ResourceState<T> next;
    try {
      next = ResourceState(value: await fetch());
    } catch (error) {
      next = ResourceState(
        value: previous,
        failure: error is ProductFailure
            ? error
            : const ProductFailure(ProductFailureKind.unavailable),
      );
    }
    if (_disposed || generation != _generation) return;
    update(next);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
