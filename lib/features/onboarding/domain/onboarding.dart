import 'dart:typed_data';

enum OnboardingCareStage { fertility, pregnancy, postpartum }

extension OnboardingCareStageValue on OnboardingCareStage {
  String get apiValue => name;

  String get title => switch (this) {
    OnboardingCareStage.fertility => 'Planning for pregnancy',
    OnboardingCareStage.pregnancy => 'Pregnant',
    OnboardingCareStage.postpartum => 'Postpartum',
  };

  String get subtitle => switch (this) {
    OnboardingCareStage.fertility => 'Cycle and preconception support',
    OnboardingCareStage.pregnancy => 'Guidance through every trimester',
    OnboardingCareStage.postpartum => 'Recovery, feeding, and baby care',
  };
}

enum OnboardingStatus {
  required,
  avatarRequired,
  avatarGenerating,
  avatarReview,
  avatarFailed,
  completed,
}

class OnboardingAvatarGeneration {
  const OnboardingAvatarGeneration({
    required this.id,
    required this.status,
    this.outputFileId,
    this.errorCode = '',
  });

  factory OnboardingAvatarGeneration.fromMap(Map<String, Object?> map) {
    return OnboardingAvatarGeneration(
      id: _string(map['id']),
      status: _status(_string(map['status'])),
      outputFileId: _nullableString(map['output_file_id']),
      errorCode: _string(map['error_code']),
    );
  }

  final String id;
  final OnboardingStatus status;
  final String? outputFileId;
  final String errorCode;
}

class OnboardingState {
  const OnboardingState({
    required this.status,
    required this.profileConfirmed,
    this.stage,
    this.canContinueWithDefault = false,
    this.primaryInfantId,
    this.selectedAvatarFileId,
    this.avatar,
  });

  factory OnboardingState.fromMap(Map<String, Object?> map) {
    final avatar = map['avatar'];
    return OnboardingState(
      status: _status(_string(map['status'])),
      profileConfirmed: map['profile_confirmed'] == true,
      stage: _stage(_nullableString(map['current_stage'])),
      canContinueWithDefault: map['can_continue_with_default'] == true,
      primaryInfantId: _nullableString(map['primary_infant_id']),
      selectedAvatarFileId: _nullableString(map['selected_avatar_file_id']),
      avatar: avatar is Map
          ? OnboardingAvatarGeneration.fromMap(
              Map<String, Object?>.from(avatar),
            )
          : null,
    );
  }

  final OnboardingStatus status;
  final bool profileConfirmed;
  final OnboardingCareStage? stage;
  final bool canContinueWithDefault;
  final String? primaryInfantId;
  final String? selectedAvatarFileId;
  final OnboardingAvatarGeneration? avatar;

  bool get isCompleted => status == OnboardingStatus.completed;
}

class OnboardingInfantDraft {
  OnboardingInfantDraft({this.nickname = '', this.sex});

  String nickname;
  String? sex;

  Map<String, Object?> toMap() => {'nickname': nickname.trim(), 'sex': sex};
}

class OnboardingProfileDraft {
  OnboardingProfileDraft({
    required this.stage,
    this.displayName = '',
    this.age,
    this.expectedDueDate,
    this.expectedInfantCount = 1,
    this.deliveryDate,
    this.gestationalWeeks,
    this.gestationalDays = 0,
    this.deliveryType,
    this.infantCount = 1,
    List<OnboardingInfantDraft>? infants,
  }) : infants = infants ?? [OnboardingInfantDraft()];

  OnboardingCareStage stage;
  String displayName;
  int? age;
  DateTime? expectedDueDate;
  int expectedInfantCount;
  DateTime? deliveryDate;
  int? gestationalWeeks;
  int gestationalDays;
  String? deliveryType;
  int infantCount;
  final List<OnboardingInfantDraft> infants;

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
    final common = <String, Object?>{
      'stage': stage.apiValue,
      'display_name': displayName.trim(),
      'age': age,
    };
    return switch (stage) {
      OnboardingCareStage.fertility => common,
      OnboardingCareStage.pregnancy => {
        ...common,
        'expected_due_date': _date(expectedDueDate!),
        'expected_infant_count': expectedInfantCount,
      },
      OnboardingCareStage.postpartum => {
        ...common,
        'delivery_date': _date(deliveryDate!),
        'delivery_gestational_age': gestationalWeeks == null
            ? null
            : {'weeks': gestationalWeeks, 'days': gestationalDays},
        'delivery_type': deliveryType,
        'infant_count': infantCount,
        'infants': infants.map((infant) => infant.toMap()).toList(),
      },
    };
  }
}

class OnboardingPortrait {
  const OnboardingPortrait({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

OnboardingStatus _status(String value) => switch (value) {
  'avatar_required' => OnboardingStatus.avatarRequired,
  'avatar_generating' ||
  'queued' ||
  'generating' => OnboardingStatus.avatarGenerating,
  'avatar_review' || 'succeeded' => OnboardingStatus.avatarReview,
  'avatar_failed' || 'failed' => OnboardingStatus.avatarFailed,
  'completed' => OnboardingStatus.completed,
  _ => OnboardingStatus.required,
};

OnboardingCareStage? _stage(String? value) => switch (value) {
  'fertility' => OnboardingCareStage.fertility,
  'pregnancy' => OnboardingCareStage.pregnancy,
  'postpartum' => OnboardingCareStage.postpartum,
  _ => null,
};

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

String _date(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
