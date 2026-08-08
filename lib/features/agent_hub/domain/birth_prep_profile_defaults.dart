class BirthPrepProfileDefaults {
  const BirthPrepProfileDefaults({
    this.age,
    this.dueDateOrWeek,
    this.ivf,
    this.fetusCount,
    this.cityOrCountry,
    this.birthHospital,
    this.birthPath,
    this.firstBirth,
    this.feedingIntention,
    this.returnToWorkTiming,
    this.supportPerson,
    this.pregnancyHistoryOrNotes,
    this.topWorries,
  });

  factory BirthPrepProfileDefaults.fromProfileMap(
    Map<String, Object?> profile,
  ) {
    final currentCareStage = _firstProfileText(profile, const [
      'current_care_stage',
      'currentCareStage',
    ]);
    return BirthPrepProfileDefaults(
      age: _profileAge(profile['age']),
      dueDateOrWeek: currentCareStage == 'pregnancy'
          ? _firstProfileText(profile, const [
              'birth_prep_due_date_or_week',
              'birthPrepDueDateOrWeek',
              'expected_due_date',
              'expectedDueDate',
            ])
          : null,
      ivf: _firstProfileText(profile, const ['birth_prep_ivf', 'birthPrepIvf']),
      fetusCount: _firstProfileText(profile, const [
        'birth_prep_fetus_count',
        'birthPrepFetusCount',
      ]),
      cityOrCountry: _firstProfileText(profile, const [
        'birth_prep_city_or_country',
        'birthPrepCityOrCountry',
      ]),
      birthHospital: _firstProfileText(profile, const [
        'birth_prep_birth_hospital',
        'birthPrepBirthHospital',
      ]),
      birthPath: _firstProfileText(profile, const [
        'birth_prep_birth_path',
        'birthPrepBirthPath',
      ]),
      firstBirth: _firstProfileText(profile, const [
        'birth_prep_first_birth',
        'birthPrepFirstBirth',
      ]),
      feedingIntention: _firstProfileText(profile, const [
        'birth_prep_feeding_intention',
        'birthPrepFeedingIntention',
      ]),
      returnToWorkTiming: _firstProfileText(profile, const [
        'birth_prep_return_to_work_timing',
        'birthPrepReturnToWorkTiming',
      ]),
      supportPerson: _firstProfileText(profile, const [
        'birth_prep_support_person',
        'birthPrepSupportPerson',
      ]),
      pregnancyHistoryOrNotes: _firstProfileText(profile, const [
        'birth_prep_pregnancy_history_or_notes',
        'birthPrepPregnancyHistoryOrNotes',
      ]),
      topWorries: _firstProfileText(profile, const [
        'birth_prep_top_worries',
        'birthPrepTopWorries',
      ]),
    );
  }

  final int? age;
  final String? dueDateOrWeek;
  final String? ivf;
  final String? fetusCount;
  final String? cityOrCountry;
  final String? birthHospital;
  final String? birthPath;
  final String? firstBirth;
  final String? feedingIntention;
  final String? returnToWorkTiming;
  final String? supportPerson;
  final String? pregnancyHistoryOrNotes;
  final String? topWorries;

  Map<String, Object?> toFormDefaultValues() {
    final values = <String, Object?>{
      'age': age,
      'due_date_or_week': dueDateOrWeek,
      'ivf': ivf,
      'fetus_count': fetusCount,
      'city_or_country': cityOrCountry,
      'birth_hospital': birthHospital,
      'birth_setting': birthHospital,
      'birth_path': birthPath,
      'first_birth': firstBirth,
      'feeding_intention': feedingIntention,
      'return_to_work_timing': returnToWorkTiming,
      'support_person': supportPerson,
      'pregnancy_history_or_notes': pregnancyHistoryOrNotes,
      'top_worries': topWorries,
    };
    values.removeWhere((key, value) => !hasAgentFormDefaultValue(value));
    return Map<String, Object?>.unmodifiable(values);
  }
}

String canonicalAgentFormId(String value) {
  final normalized = value.trim();
  return const <String, String>{
        'hospitalBagIntake': 'hospital_bag_intake',
        'birthPlanCardIntake': 'birth_plan_card_intake',
        'birthJourneyBasicInfoIntake': 'birth_journey_basic_info_intake',
      }[normalized] ??
      normalized;
}

String canonicalAgentFormFieldId(String value) {
  final normalized = value.trim();
  return const <String, String>{
        'currentWeek': 'current_week',
        'dueDateOrWeek': 'due_date_or_week',
        'birthPath': 'birth_path',
        'firstBirth': 'first_birth',
        'fetusCount': 'fetus_count',
        'pregnancyHistoryOrNotes': 'pregnancy_history_or_notes',
        'feedingIntention': 'feeding_intention',
        'returnToWorkTiming': 'return_to_work_timing',
        'supportPerson': 'support_person',
        'topWorries': 'top_worries',
        'cityOrCountry': 'city_or_country',
        'birthHospital': 'birth_hospital',
        'birthSetting': 'birth_setting',
        'hospitalRulesOrNotes': 'hospital_rules_or_notes',
        'existingChecklistOrPhotoNote': 'existing_checklist_or_photo_note',
      }[normalized] ??
      normalized;
}

bool hasAgentFormDefaultValue(Object? value) {
  if (value is List) return value.any(hasAgentFormDefaultValue);
  if (value is Map) return value.values.any(hasAgentFormDefaultValue);
  if (value == null) return false;
  final normalized = value.toString().trim().toLowerCase();
  return !const <String>{
    '',
    'to confirm',
    '待确认',
    '未确定',
    '不确定',
    '还不确定',
    '还没确定',
    '还没想好',
    'none',
    'n/a',
  }.contains(normalized);
}

int? _profileAge(Object? value) {
  final age = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };
  return age != null && age > 0 ? age : null;
}

String? _firstProfileText(Map<String, Object?> profile, List<String> keys) {
  for (final key in keys) {
    final text = _profileText(profile[key]);
    if (text != null && hasAgentFormDefaultValue(text)) return text;
  }
  return null;
}

String? _profileText(Object? value) {
  if (value is List) {
    final items = value
        .map((item) => item?.toString().trim())
        .whereType<String>()
        .where((item) => item.isNotEmpty);
    final joined = items.join(',');
    return joined.isEmpty ? null : joined;
  }
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
