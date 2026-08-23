Map<String, Object?> normalizeAgentArtifactForm(Map<String, Object?> form) {
  if (form.isEmpty) return form;
  final normalized = Map<String, Object?>.from(form);
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
      if (id.isEmpty) continue;
      field['id'] = id;
      final defaultValue = _firstValidDefault([
        field['default_value'],
        field['defaultValue'],
        formValues[id],
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

  normalized['id'] = canonicalAgentFormId(_string(form['id']));
  normalized.remove('defaultValues');
  normalized['default_values'] = formValues;
  normalized['fields'] = fields;
  return normalized;
}

String canonicalAgentFormId(String value) => _snakeCase(value);

String canonicalAgentFormFieldId(String value) => _snakeCase(value);

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

String _snakeCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .toLowerCase();
}

String _string(Object? value) => value is String ? value : '';
