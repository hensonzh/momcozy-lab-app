import 'package:app/features/agent_hub/domain/birth_prep_profile_defaults.dart';

const _hospitalBagFormFieldIds = <String>{
  'due_date_or_week',
  'first_birth',
  'fetus_count',
  'pregnancy_history_or_notes',
  'birth_path',
  'feeding_intention',
  'return_to_work_timing',
  'support_person',
  'budget_preference',
  'top_worries',
};

const _hospitalBagDetectorFieldIds = <String>{
  'fetus_count',
  'return_to_work_timing',
  'budget_preference',
  'top_worries',
};

const _removedHospitalBagFieldIds = <String>{
  'hospital_rules_or_notes',
  'existing_checklist_or_photo_note',
};

const _birthJourneyRequiredFieldIds = <String>{
  'current_week',
  'ivf',
  'fetus_count',
  'age',
  'first_birth',
  'birth_path',
};

Map<String, Object?> normalizeAgentArtifactForm(
  Map<String, Object?> form, {
  BirthPrepProfileDefaults profileDefaults = const BirthPrepProfileDefaults(),
}) {
  if (form.isEmpty) return form;
  final normalizedForm = Map<String, Object?>.from(form);
  final formId = canonicalAgentFormId(_string(form['id']));
  final profileValues = profileDefaults.toFormDefaultValues();
  final formValues = _canonicalDefaultValues(
    form['default_values'] ?? form['defaultValues'],
  );
  final rawFields = form['fields'];
  final fields = <Map<String, Object?>>[];
  if (rawFields is List) {
    for (final rawField in rawFields) {
      if (rawField is! Map) continue;
      final field = Map<String, Object?>.from(rawField);
      final id = canonicalAgentFormFieldId(_string(field['id']));
      field['id'] = id;
      final defaultValue = _firstValidDefault([
        field['default_value'],
        field['defaultValue'],
        formValues[id],
        profileValues[id],
      ]);
      field.remove('defaultValue');
      if (defaultValue == null) {
        field.remove('default_value');
      } else {
        field['default_value'] = defaultValue;
      }
      fields.add(field);
    }
  }

  final isBirthJourneyBasic = formId == 'birth_journey_basic_info_intake';
  final isHospitalBag =
      formId == 'hospital_bag_intake' ||
      (!isBirthJourneyBasic && _looksLikeHospitalBagForm(fields));

  normalizedForm['id'] = isHospitalBag ? 'hospital_bag_intake' : formId;
  normalizedForm.remove('defaultValues');
  normalizedForm['default_values'] = {...profileValues, ...formValues};

  if (isHospitalBag) {
    normalizedForm['title'] = '信息采集';
    normalizedForm['description'] = '';
  }

  final normalizedFields = <Map<String, Object?>>[];
  for (final field in fields) {
    final id = _string(field['id']);
    if (isHospitalBag && _removedHospitalBagFieldIds.contains(id)) continue;
    var next = Map<String, Object?>.from(field);
    if (isHospitalBag) next = _normalizeHospitalBagField(next);
    if (isBirthJourneyBasic && _birthJourneyRequiredFieldIds.contains(id)) {
      next['required'] = true;
    }
    normalizedFields.add(next);
  }
  normalizedForm['fields'] = normalizedFields;
  return normalizedForm;
}

Map<String, Object?> _normalizeHospitalBagField(Map<String, Object?> field) {
  final id = _string(field['id']);
  if (id == 'due_date_or_week') {
    field['label'] = _nonEmptyString(field['label']) ?? '基本信息｜预产期或当前孕周';
    field['type'] = 'text';
    field['placeholder'] =
        _nonEmptyString(field['placeholder']) ?? '例如：2026-06-12 或 37 周';
  }
  if (id == 'pregnancy_history_or_notes' && field['options'] is List) {
    field['options'] = List<Object?>.from(field['options'] as List)
      ..removeWhere((option) => option?.toString().trim() == '计划剖宫产');
  }
  if (id == 'birth_path') {
    field['label'] = _replaceFieldLabel(field['label'], '分娩方式');
    field['default_value'] = _normalizedBirthPath(field['default_value']);
  }
  field.remove('helpText');
  field['help_text'] = '';
  return field;
}

bool _looksLikeHospitalBagForm(List<Map<String, Object?>> fields) {
  final ids = fields.map((field) => _string(field['id'])).toSet();
  final matched = ids.where(_hospitalBagFormFieldIds.contains).length;
  return matched >= 2 && ids.any(_hospitalBagDetectorFieldIds.contains);
}

Map<String, Object?> _canonicalDefaultValues(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  final defaults = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || !hasAgentFormDefaultValue(entry.value)) continue;
    defaults[canonicalAgentFormFieldId(key)] = entry.value;
  }
  return defaults;
}

Object? _firstValidDefault(List<Object?> values) {
  for (final value in values) {
    if (hasAgentFormDefaultValue(value)) return value;
  }
  return null;
}

Object? _normalizedBirthPath(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  if (const <String>{
    '计划剖宫产',
    '剖腹产',
    'planned_c_section',
    'c_section',
    'c-section',
    'cesarean',
  }.contains(normalized)) {
    return '剖宫产';
  }
  return value;
}

String _replaceFieldLabel(Object? value, String fieldLabel) {
  final label = _string(value).trim();
  final separatorIndex = label.indexOf('｜');
  if (separatorIndex <= 0) return fieldLabel;
  final group = label.substring(0, separatorIndex).trim();
  return group.isEmpty ? fieldLabel : '$group｜$fieldLabel';
}

String? _nonEmptyString(Object? value) {
  final normalized = _string(value).trim();
  return normalized.isEmpty ? null : normalized;
}

String _string(Object? value) => value is String ? value : '';
