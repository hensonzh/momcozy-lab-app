enum StatusEntryIntentKind { growth, pregnancyDiary, birthJourney }

class StatusEntryIntent {
  const StatusEntryIntent({required this.kind, required this.token});

  final StatusEntryIntentKind kind;
  final String token;
}

StatusEntryIntent? statusEntryIntentFromRoute(Uri? uri, Object? extra) {
  final extraMap = <String, Object?>{};
  if (extra is Map) {
    for (final entry in extra.entries) {
      final key = entry.key;
      if (key is String) extraMap[key] = entry.value;
    }
  }
  final raw =
      uri?.queryParameters['statusIntent'] ??
      _string(extraMap['statusIntent']) ??
      _kindFromTypedIntent(_string(extraMap['type'])) ??
      _kindFromSource(_string(extraMap['source']));
  final kind = _parseKind(raw);
  if (kind == null) return null;

  final id =
      uri?.queryParameters['statusIntentId'] ??
      _string(extraMap['statusIntentId']) ??
      _string(extraMap['eventId']);
  final fallback = '${uri?.toString() ?? ''}|${extraMap.toString()}';
  return StatusEntryIntent(kind: kind, token: '${kind.name}:${id ?? fallback}');
}

StatusEntryIntentKind? _parseKind(String? value) {
  final normalized = value?.trim().toLowerCase().replaceAll(
    RegExp(r'[_\s]+'),
    '-',
  );
  return switch (normalized) {
    'growth' || 'growth-highlight' => StatusEntryIntentKind.growth,
    'pregnancy-diary' || 'diary' => StatusEntryIntentKind.pregnancyDiary,
    'birth-journey' ||
    'birth-journey-plan' => StatusEntryIntentKind.birthJourney,
    _ => null,
  };
}

String? _kindFromTypedIntent(String? type) {
  return switch (type) {
    'OpenStatusGrowthHighlight' => 'growth',
    'OpenStatusPregnancyDiaryBadge' => 'pregnancy-diary',
    'OpenStatusBirthJourneyBadge' => 'birth-journey',
    _ => null,
  };
}

String? _kindFromSource(String? source) {
  return switch (source) {
    'pregnancyDiaryChanged' => 'pregnancy-diary',
    'birthJourneyPlanChanged' => 'birth-journey',
    _ => null,
  };
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
