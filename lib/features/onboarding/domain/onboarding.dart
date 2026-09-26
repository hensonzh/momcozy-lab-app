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
    final confirmed =
        map['profile_confirmed'] == true || map['status'] == 'completed';
    return OnboardingState(
      status: confirmed
          ? OnboardingStatus.completed
          : OnboardingStatus.required,
      profileConfirmed: confirmed,
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
    this.infantCount = 1,
    List<OnboardingInfantDraft>? infants,
  }) : infants = infants ?? [OnboardingInfantDraft()];

  String displayName;
  int? age;
  DateTime? deliveryDate;

  /// Number of births including the current delivery.
  int? deliveryCount;

  /// Cesarean history before the current delivery (not its delivery method).
  bool? hasCesareanHistory;
  String? deliveryType;
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
    if (deliveryCount == null || deliveryCount! < 1 || deliveryCount! > 20) {
      throw const FormatException('Choose which delivery this is.');
    }
    return <String, Object?>{
      // The backend still requires the single supported care-stage value.
      // It is a transport compatibility field, not an app-side stage model.
      'stage': 'postpartum',
      'display_name': displayName.trim(),
      'age': age,
      'delivery_date': _date(deliveryDate!),
      'delivery_count': deliveryCount,
      'has_cesarean_history': deliveryCount == 1 ? false : hasCesareanHistory,
      'delivery_type': deliveryType,
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
