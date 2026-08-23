import 'dart:typed_data';

enum OnboardingStatus {
  required,
  avatarRequired,
  avatarGenerating,
  avatarReview,
  avatarFailed,
  completed,
}

enum OnboardingAvatarGenerationPhase {
  queued,
  generating,
  succeeded,
  failed,
  unknown,
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
    required this.phase,
    this.outputFileId,
    this.errorCode = '',
    this.candidates = const [],
  });

  factory OnboardingAvatarGeneration.fromMap(Map<String, Object?> map) {
    final rawStatus = _string(map['status']).trim();
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
    final status = _status(rawStatus);
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
      phase: _avatarGenerationPhase(rawStatus),
      outputFileId: _nullableString(map['output_file_id']),
      errorCode: _string(map['error_code']),
      candidates: List.unmodifiable(candidates),
    );
  }

  final String id;
  final OnboardingStatus status;
  final OnboardingAvatarGenerationPhase phase;
  final String? outputFileId;
  final String errorCode;
  final List<OnboardingAvatarCandidate> candidates;
}

class OnboardingState {
  const OnboardingState({
    required this.status,
    required this.profileConfirmed,
    this.canEnterApp = false,
    this.avatarSetupCompleted = false,
    this.canContinueWithDefault = false,
    this.primaryInfantId,
    this.activeAvatarFileId,
    this.pendingAvatar,
  });

  factory OnboardingState.fromMap(Map<String, Object?> map) {
    final status = _status(_string(map['status']));
    final avatarSetupCompleted =
        map['avatar_setup_completed'] == true ||
        status == OnboardingStatus.completed;
    final pendingAvatar =
        map['pending_avatar'] ?? (avatarSetupCompleted ? null : map['avatar']);
    return OnboardingState(
      status: status,
      profileConfirmed: map['profile_confirmed'] == true,
      canEnterApp:
          map['can_enter_app'] == true || status == OnboardingStatus.completed,
      avatarSetupCompleted: avatarSetupCompleted,
      canContinueWithDefault: map['can_continue_with_default'] == true,
      primaryInfantId: _nullableString(map['primary_infant_id']),
      activeAvatarFileId: _nullableString(
        map['active_avatar_file_id'] ?? map['selected_avatar_file_id'],
      ),
      pendingAvatar: pendingAvatar is Map
          ? OnboardingAvatarGeneration.fromMap(
              Map<String, Object?>.from(pendingAvatar),
            )
          : null,
    );
  }

  final OnboardingStatus status;
  final bool profileConfirmed;
  final bool canEnterApp;
  final bool avatarSetupCompleted;
  final bool canContinueWithDefault;
  final String? primaryInfantId;
  final String? activeAvatarFileId;
  final OnboardingAvatarGeneration? pendingAvatar;

  bool get isCompleted =>
      avatarSetupCompleted || status == OnboardingStatus.completed;
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
    this.gestationalWeeks,
    this.gestationalDays,
    this.deliveryType,
    this.infantCount = 1,
    List<OnboardingInfantDraft>? infants,
  }) : infants = infants ?? [OnboardingInfantDraft()];

  String displayName;
  int? age;
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
    return <String, Object?>{
      // The backend still requires the single supported care-stage value.
      // It is a transport compatibility field, not an app-side stage model.
      'stage': 'postpartum',
      'display_name': displayName.trim(),
      'age': age,
      'delivery_date': _date(deliveryDate!),
      'delivery_gestational_age': {
        'weeks': gestationalWeeks!,
        if (gestationalDays != null) 'days': gestationalDays,
      },
      'delivery_type': deliveryType,
      'infant_count': infantCount,
      'infants': infants.map((infant) => infant.toMap()).toList(),
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

OnboardingAvatarGenerationPhase _avatarGenerationPhase(String value) =>
    switch (value) {
      'queued' => OnboardingAvatarGenerationPhase.queued,
      'generating' => OnboardingAvatarGenerationPhase.generating,
      'succeeded' => OnboardingAvatarGenerationPhase.succeeded,
      'failed' => OnboardingAvatarGenerationPhase.failed,
      _ => OnboardingAvatarGenerationPhase.unknown,
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
