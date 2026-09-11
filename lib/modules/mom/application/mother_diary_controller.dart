import 'package:flutter/foundation.dart';

import '../../../domain/mother/mother_diary.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';

enum DiaryPhase { loading, ready, saving, failed }

/// Owns an editor session. A failed save keeps every field and the base version.
class MotherDiaryController extends ChangeNotifier {
  MotherDiaryController({required this.repository, required this.date});
  final MotherDiaryRepository repository;
  final LocalDate date;
  DiaryPhase phase = DiaryPhase.loading;
  MotherDiaryEntry? saved;
  MotherDiary draft = const MotherDiary();
  ProductFailure? failure;
  bool dirty = false;
  bool _disposed = false;
  int _generation = 0;

  bool get canEdit => phase == DiaryPhase.ready;
  bool get canSave => canEdit && dirty && !draft.isEmpty;

  Future<void> load() async {
    if (phase == DiaryPhase.saving) return;
    final generation = ++_generation;
    phase = DiaryPhase.loading;
    failure = null;
    notifyListeners();
    try {
      final entries = await repository.list(start: date, end: date);
      if (_disposed || generation != _generation) return;
      saved = entries.where((entry) => entry.date == date).firstOrNull;
      draft = saved?.diary ?? const MotherDiary();
      dirty = false;
      phase = DiaryPhase.ready;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      phase = DiaryPhase.failed;
    }
    notifyListeners();
  }

  void edit(MotherDiary value) {
    if (!canEdit) return;
    draft = value;
    dirty = true;
    failure = null;
    notifyListeners();
  }

  Future<bool> save() async {
    if (!canSave) return false;
    phase = DiaryPhase.saving;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.save(
        date: date,
        diary: draft,
        expectedVersion: saved?.version ?? 0,
      );
      if (_disposed) return false;
      saved = result;
      draft = result.diary;
      dirty = false;
      phase = DiaryPhase.ready;
      notifyListeners();
      return true;
    } catch (error) {
      if (_disposed) return false;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      phase = DiaryPhase.ready;
      notifyListeners();
      return false;
    }
  }

  /// Explicit user choice after a conflict; never silently overwrites another edit.
  Future<void> reloadAfterConflict() => load();

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
