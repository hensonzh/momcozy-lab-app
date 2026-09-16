import 'package:flutter/foundation.dart';
import '../../../domain/baby/baby_profile.dart';
import '../../../domain/care/intake.dart';
import '../../../domain/shared/local_date.dart';
import '../../../domain/shared/product_failure.dart';
import '../../../shared/zoned_time.dart';

final class _Submission {
  const _Submission(
    this.content,
    this.version,
    this.consentVersion,
    this.policyVersion,
  );
  final IntakeContent content;
  final int version, consentVersion;
  final String policyVersion;
}

class IntakeController extends ChangeNotifier {
  IntakeController({
    required this.repository,
    required this.appointmentId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final IntakeRepository repository;
  final String appointmentId;
  final DateTime Function() now;
  IntakeContext? data;
  CareIntake? saved;
  Set<IntakeSymptom> symptoms = {};
  String goal = '', support = '', postpartumDays = '', babyName = '';
  String? babyId, region;
  LocalDate? babyBirthDate;
  BabySex babySex = BabySex.unspecified;
  FeedingMode feedingMode = FeedingMode.unknown;
  bool consent = false, loading = true, busy = false, dirty = false;
  ProductFailure? failure;
  String? validation;
  int draftRevision = 0;
  _Submission? _pending;
  bool _disposed = false;
  bool get uncertainSave => _pending != null;
  bool get canEdit => !busy && !uncertainSave;
  bool get profileReady =>
      babyId != null &&
      babyName.trim().isNotEmpty &&
      babyName.trim().length <= 120 &&
      babyBirthDate != null &&
      babyBirthDate!.compareTo(today) <= 0 &&
      babySex != BabySex.unspecified &&
      feedingMode != FeedingMode.unknown &&
      (int.tryParse(postpartumDays) ?? -1) >= 0 &&
      (int.tryParse(postpartumDays) ?? -1) <=
          today.daysSince(LocalDate(1900, 1, 1)) &&
      region != null &&
      RegExp(r'^[A-Z]{2}$').hasMatch(region!);
  bool get canSubmit =>
      !busy &&
      (uncertainSave ||
          (profileReady &&
              symptoms.isNotEmpty &&
              goal.trim().isNotEmpty &&
              goal.trim().length <= 1000 &&
              support.trim().length <= 3000 &&
              consent));
  LocalDate get today =>
      dateInTimezone(now(), data?.appointment.timezone ?? 'UTC');

  Future<void> load() async {
    if (busy) return;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final result = await repository.load(appointmentId);
      if (_disposed) return;
      data = result;
      saved = result.intake;
      final prefill = result.intake ?? result.previousIntake;
      symptoms = {...?prefill?.content.symptoms};
      goal = prefill?.content.feedingGoal ?? '';
      support = prefill?.content.supportNeeded ?? '';
      region = prefill?.content.profile.region ?? result.appointment.region;
      final delivery =
          prefill?.content.profile.deliveryDate ?? result.deliveryDate;
      postpartumDays = delivery == null
          ? ''
          : today.daysSince(delivery).toString();
      final baby =
          prefill?.content.profile.baby ??
          (result.babies.length == 1 ? result.babies.first : null);
      _fillBaby(baby);
      consent =
          result.intake != null &&
          (result.consent(CareConsentScope.ibclcCase)?.active ?? false);
      dirty = false;
      validation = null;
      _pending = null;
      draftRevision++;
    } catch (error) {
      if (_disposed) return;
      failure = _failure(error);
    }
    loading = false;
    notifyListeners();
  }

  void _fillBaby(BabyProfile? value) {
    babyId = value?.id;
    babyName = value?.name ?? '';
    babyBirthDate = value?.birthDate;
    babySex = value?.sex ?? BabySex.unspecified;
    feedingMode = value?.feedingMode ?? FeedingMode.unknown;
  }

  void selectBaby(String? id) {
    if (!canEdit) return;
    _fillBaby(data?.babies.where((item) => item.id == id).firstOrNull);
    dirty = true;
    draftRevision++;
    notifyListeners();
  }

  void change(VoidCallback change) {
    if (canEdit) {
      change();
      dirty = true;
      validation = null;
      notifyListeners();
    }
  }

  void toggleSymptom(IntakeSymptom value) => change(() {
    if (symptoms.contains(value)) {
      symptoms.remove(value);
    } else {
      symptoms.add(value);
    }
  });

  IntakeContent? _validated() {
    final days = int.tryParse(postpartumDays);
    if (symptoms.isEmpty || goal.trim().isEmpty) {
      validation = '请至少选择一项问题，并填写希望的变化';
      return null;
    }
    if (goal.trim().length > 1000 || support.trim().length > 3000) {
      validation = '目标最多 1000 字，补充情况最多 3000 字';
      return null;
    }
    if (babyId == null ||
        babyName.trim().isEmpty ||
        babyName.trim().length > 120 ||
        babyBirthDate == null ||
        babySex == BabySex.unspecified ||
        feedingMode == FeedingMode.unknown ||
        days == null ||
        days < 0 ||
        days > today.daysSince(LocalDate(1900, 1, 1))) {
      validation = '请完善基础信息';
      return null;
    }
    if (babyBirthDate!.compareTo(today) > 0) {
      validation = '宝宝出生日期不能在未来';
      return null;
    }
    if (region == null || !RegExp(r'^[A-Z]{2}$').hasMatch(region!)) {
      validation = '请确认当前所在州';
      return null;
    }
    if (!consent) {
      validation = '请确认允许本次服务的 IBCLC 查看此表';
      return null;
    }
    return IntakeContent(
      symptoms: Set.unmodifiable(symptoms),
      feedingGoal: goal.trim(),
      supportNeeded: support.trim(),
      profile: IntakeProfile(
        baby: BabyProfile(
          id: babyId!,
          name: babyName.trim(),
          birthDate: babyBirthDate!,
          sex: babySex,
          feedingMode: feedingMode,
        ),
        deliveryDate: today.addDays(-days),
        region: region!,
      ),
    );
  }

  Future<CareIntake?> save() async {
    if (busy || data == null) return null;
    if (_pending == null) {
      final content = _validated();
      if (content == null) {
        notifyListeners();
        return null;
      }
      _pending = _Submission(
        content,
        saved?.version ?? 0,
        data!.consent(CareConsentScope.ibclcCase)?.version ?? 0,
        data!.policyVersion,
      );
    }
    final submission = _pending!;
    busy = true;
    failure = null;
    validation = null;
    notifyListeners();
    CareIntake? result;
    try {
      result = await repository.save(
        appointmentId,
        content: submission.content,
        expectedVersion: submission.version,
        expectedConsentVersion: submission.consentVersion,
        policyVersion: submission.policyVersion,
      );
      if (_disposed) return null;
      saved = result;
      dirty = false;
      _pending = null;
    } catch (error) {
      if (_disposed) return null;
      failure = _failure(error);
      if (![
        ProductFailureKind.offline,
        ProductFailureKind.unavailable,
      ].contains(failure!.kind)) {
        _pending = null;
      }
      validation = switch (failure!.code) {
        'consent_conflict' => '授权已发生变化，请重新载入并确认',
        'service_baby_mismatch' => '本次服务已关联其他宝宝，请重新载入后核对',
        'region_unavailable' => '这位专家暂时无法在当前州提供服务',
        _ => null,
      };
    }
    busy = false;
    notifyListeners();
    return result;
  }

  ProductFailure _failure(Object error) => error is ProductFailure
      ? error
      : const ProductFailure(ProductFailureKind.unavailable);
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
