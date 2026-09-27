import 'package:momcozy_flutter_app/domain/shared/feeding_methods.dart';

enum OnboardingStatus { required, completed }

enum OnboardingReleaseResetStatus { reset, alreadyReset }

class OnboardingReleaseReset {
  const OnboardingReleaseReset({
    required this.status,
    required this.releaseId,
    required this.deletedFileCount,
    required this.objectCleanupQueued,
  });

  factory OnboardingReleaseReset.fromMap(Map<String, Object?> map) {
    final status = switch (_string(map['status'])) {
      'reset' => OnboardingReleaseResetStatus.reset,
      'already_reset' => OnboardingReleaseResetStatus.alreadyReset,
      _ => null,
    };
    final releaseId = _string(map['release_id']).trim();
    final deletedFileCount = map['deleted_file_count'];
    final objectCleanupQueued = map['object_cleanup_queued'];
    if (status == null ||
        releaseId.isEmpty ||
        deletedFileCount is! int ||
        deletedFileCount < 0 ||
        objectCleanupQueued is! bool) {
      throw const FormatException('Invalid onboarding release reset response.');
    }
    return OnboardingReleaseReset(
      status: status,
      releaseId: releaseId,
      deletedFileCount: deletedFileCount,
      objectCleanupQueued: objectCleanupQueued,
    );
  }

  final OnboardingReleaseResetStatus status;
  final String releaseId;
  final int deletedFileCount;
  final bool objectCleanupQueued;
}

class OnboardingState {
  const OnboardingState({
    required this.status,
    required this.profileConfirmed,
    this.primaryInfantId,
  });

  factory OnboardingState.fromMap(Map<String, Object?> map) {
    final confirmed = map['profile_confirmed'];
    final status = map['status'];
    final valid =
        (status == 'required' && confirmed == false) ||
        (status == 'completed' && confirmed == true) ||
        (confirmed == true &&
            (status == 'avatar_required' || status == 'avatar_generating'));
    if (!valid) {
      throw const FormatException('Invalid onboarding state response.');
    }
    return OnboardingState(
      status: confirmed == true
          ? OnboardingStatus.completed
          : OnboardingStatus.required,
      profileConfirmed: confirmed == true,
      primaryInfantId: _nullableString(map['primary_infant_id']),
    );
  }

  final OnboardingStatus status;
  final bool profileConfirmed;
  final String? primaryInfantId;

  bool get canEnterApp => profileConfirmed;
  bool get isCompleted => profileConfirmed;
}

class OnboardingInfantDraft {
  OnboardingInfantDraft({this.nickname = '', this.sex});

  String nickname;
  String? sex;

  Map<String, Object?> toMap() => {'nickname': nickname.trim(), 'sex': sex};
}

class OnboardingProfileDraft {
  OnboardingProfileDraft({
    this.displayName = '',
    this.age,
    this.deliveryDate,
    this.deliveryCount,
    this.hasCesareanHistory,
    this.deliveryType,
    this.gestationWeeks,
    this.gestationDays,
    List<String>? feedingMethods,
    this.infantCount = 1,
    List<OnboardingInfantDraft>? infants,
  }) : infants = infants ?? [OnboardingInfantDraft()],
       feedingMethods = feedingMethods ?? [];

  String displayName;
  int? age;
  DateTime? deliveryDate;

  /// Number of births including the current delivery.
  int? deliveryCount;

  /// Cesarean history before the current delivery (not its delivery method).
  bool? hasCesareanHistory;
  String? deliveryType;
  int? gestationWeeks;
  int? gestationDays;
  List<String> feedingMethods;
  int infantCount;
  final List<OnboardingInfantDraft> infants;

  void setDeliveryCount(int value) {
    deliveryCount = value;
    if (value == 1) hasCesareanHistory = null;
  }

  void setInfantCount(int value) {
    infantCount = value;
    while (infants.length < value) {
      infants.add(OnboardingInfantDraft());
    }
    while (infants.length > value) {
      infants.removeLast();
    }
  }

  Map<String, Object?> toMap() {
    final name = displayName.trim();
    if (name.isEmpty || name.runes.length > 120) {
      throw const FormatException('Name must be 1–120 characters.');
    }
    if (deliveryDate == null) {
      throw const FormatException('Choose your delivery date.');
    }
    if (deliveryCount == null || deliveryCount! < 1 || deliveryCount! > 20) {
      throw const FormatException('Choose which delivery this is.');
    }
    if (gestationWeeks == null ||
        gestationWeeks! < 20 ||
        gestationWeeks! > 45 ||
        gestationDays == null ||
        gestationDays! < 0 ||
        gestationDays! > 6) {
      throw const FormatException(
        'Enter gestational age at delivery (weeks and days).',
      );
    }
    if (!validFeedingMethods(feedingMethods)) {
      throw const FormatException('Choose your current feeding methods.');
    }
    return <String, Object?>{
      // The backend still requires the single supported care-stage value.
      // It is a transport compatibility field, not an app-side stage model.
      'stage': 'postpartum',
      'display_name': displayName.trim(),
      'age': age,
      'delivery_date': _date(deliveryDate!),
      'client_timezone_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      'delivery_count': deliveryCount,
      'has_cesarean_history': deliveryCount == 1 ? false : hasCesareanHistory,
      'delivery_type': deliveryType,
      'gestation_weeks': gestationWeeks,
      'gestation_days': gestationDays,
      'feeding_methods': List<String>.of(feedingMethods),
      'infant_count': infantCount,
      'infants': infants.map((infant) => infant.toMap()).toList(),
    };
  }
}

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

String _date(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
