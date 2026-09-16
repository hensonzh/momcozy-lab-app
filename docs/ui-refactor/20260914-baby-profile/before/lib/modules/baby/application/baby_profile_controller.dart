import 'package:flutter/foundation.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/mutation_key.dart';
import '../../../shared/zoned_time.dart';

class BabyProfileController extends ChangeNotifier {
  BabyProfileController({
    required this.repository,
    required this.timezone,
    required this.now,
    BabyProfile? initial,
  }) : _initial = initial {
    _fill(initial);
  }
  final BabyProfileRepository repository;
  final String timezone;
  final DateTime Function() now;
  BabyProfile? _initial;
  BabyProfile? _pending;
  String _key = newMutationKey();
  bool _disposed = false;
  late String name;
  LocalDate? birthDate;
  late BabySex sex;
  late FeedingMode feedingMode;
  bool busy = false, uncertain = false;
  String? validation;
  ProductFailure? failure;
  bool get editable => !busy && !uncertain;
  bool get isNew => _initial == null;
  LocalDate get today => dateInTimezone(now(), timezone);
  bool get dirty =>
      name != (_initial?.name ?? '') ||
      birthDate != _initial?.birthDate ||
      sex != (_initial?.sex ?? BabySex.unspecified) ||
      feedingMode != (_initial?.feedingMode ?? FeedingMode.unknown);

  void _fill(BabyProfile? value) {
    name = value?.name ?? '';
    birthDate = value?.birthDate;
    sex = value?.sex ?? BabySex.unspecified;
    feedingMode = value?.feedingMode ?? FeedingMode.unknown;
  }

  void _edit(VoidCallback change) {
    if (!editable) return;
    change();
    validation = null;
    failure = null;
    _pending = null;
    _key = newMutationKey();
    notifyListeners();
  }

  void setName(String value) => _edit(() => name = value);
  void setBirthDate(LocalDate? value) => _edit(() => birthDate = value);
  void setSex(BabySex value) => _edit(() => sex = value);
  void setFeedingMode(FeedingMode value) => _edit(() => feedingMode = value);

  Future<BabyProfile?> save() async {
    if (busy) return null;
    validation = name.trim().isEmpty
        ? '请填写宝宝称呼。'
        : name.trim().runes.length > 120
        ? '宝宝称呼不能超过 120 字。'
        : birthDate != null &&
              birthDate != _initial?.birthDate &&
              birthDate!.compareTo(today) > 0
        ? '出生日期不能晚于今天。'
        : null;
    if (validation != null) {
      notifyListeners();
      return null;
    }
    _pending ??= BabyProfile(
      id: _initial?.id ?? '',
      version: _initial?.version,
      name: name.trim(),
      birthDate: birthDate,
      sex: sex,
      feedingMode: feedingMode,
    );
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final saved = await repository.save(
        _pending!,
        timezone: timezone,
        idempotencyKey: _key,
      );
      if (_disposed) return null;
      _initial = saved;
      _fill(saved);
      _pending = null;
      uncertain = false;
      return saved;
    } catch (error) {
      if (_disposed) return null;
      failure = error is ProductFailure
          ? error
          : const ProductFailure(ProductFailureKind.unavailable);
      uncertain =
          failure!.kind == ProductFailureKind.offline ||
          failure!.kind == ProductFailureKind.unavailable;
      return null;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> reload() async {
    if (busy || uncertain || _initial == null) return false;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      final values = await repository.list();
      if (_disposed) return false;
      final current = values
          .where((value) => value.id == _initial!.id)
          .firstOrNull;
      if (current == null) {
        throw const ProductFailure(ProductFailureKind.forbidden);
      }
      _initial = current;
      _fill(current);
      _pending = null;
      _key = newMutationKey();
      validation = null;
      return true;
    } catch (error) {
      if (!_disposed) {
        failure = error is ProductFailure
            ? error
            : const ProductFailure(ProductFailureKind.unavailable);
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pending = null;
    super.dispose();
  }
}
