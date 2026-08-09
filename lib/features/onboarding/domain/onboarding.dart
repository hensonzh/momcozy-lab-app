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

class OnboardingAvatarCandidate {
  const OnboardingAvatarCandidate({
    required this.id,
    required this.fileId,
    required this.position,
  });

  factory OnboardingAvatarCandidate.fromMap(Map<String, Object?> map) {
    final id = _string(map['id']).trim();
    final fileId = _string(map['file_id']).trim();
    final position = map['position'];
    if (id.isEmpty ||
        fileId.isEmpty ||
        position is! int ||
        position < 1 ||
        position > 4) {
      throw const FormatException('Invalid avatar candidate response.');
    }
    return OnboardingAvatarCandidate(
      id: id,
      fileId: fileId,
      position: position,
    );
  }

  final String id;
  final String fileId;
  final int position;
}

class OnboardingAvatarGeneration {
  const OnboardingAvatarGeneration({
    required this.id,
    required this.status,
    this.outputFileId,
    this.errorCode = '',
    this.candidates = const [],
  });

  factory OnboardingAvatarGeneration.fromMap(Map<String, Object?> map) {
    final rawCandidates = map['candidates'];
    final candidates = rawCandidates is List
        ? rawCandidates
              .map(
                (value) => value is Map
                    ? OnboardingAvatarCandidate.fromMap(
                        Map<String, Object?>.from(value),
                      )
                    : throw const FormatException(
                        'Invalid avatar candidate response.',
                      ),
              )
              .toList()
        : <OnboardingAvatarCandidate>[];
    candidates.sort((left, right) => left.position.compareTo(right.position));
    final status = _status(_string(map['status']));
    if (status == OnboardingStatus.avatarReview &&
        (candidates.length != 4 ||
            candidates.map((value) => value.position).toSet().length != 4)) {
      throw const FormatException(
        'Avatar generation did not return four candidates.',
      );
    }
    return OnboardingAvatarGeneration(
      id: _string(map['id']),
      status: status,
      outputFileId: _nullableString(map['output_file_id']),
      errorCode: _string(map['error_code']),
      candidates: List.unmodifiable(candidates),
    );
  }

  final String id;
  final OnboardingStatus status;
  final String? outputFileId;
  final String errorCode;
  final List<OnboardingAvatarCandidate> candidates;
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
    this.gestationalDays,
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
  int? gestationalDays;
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
        'delivery_gestational_age': {
          'weeks': gestationalWeeks!,
          if (gestationalDays != null) 'days': gestationalDays,
        },
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
