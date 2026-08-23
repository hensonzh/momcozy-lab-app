/// Read-only compatibility filter for artifacts persisted by retired prenatal
/// app versions. It prevents old conversation history from resurfacing removed
/// product UI; it does not implement any prenatal behavior.
const _retiredArtifactTypes = <String>{
  'birth_journey_plan_card',
  'birth_plan_card',
  'hospital_bag_card',
  'hospital_bag_cart',
};

const _retiredFormIds = <String>{
  'birth_journey_basic_info_intake',
  'birth_plan_card_intake',
  'hospital_bag_intake',
};

const _retiredPlanTypes = <String>{'pregnancy', 'birth_journey', 'prenatal'};

bool isRetiredPrenatalArtifactType(String? value) {
  return _retiredArtifactTypes.contains(value?.trim().toLowerCase());
}

bool isRetiredPrenatalForm(Map<String, Object?> form) {
  final rawId = form['id'];
  if (rawId is! String) return false;
  final id = rawId
      .trim()
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll(RegExp(r'[\s\-]+'), '_')
      .toLowerCase();
  return _retiredFormIds.contains(id);
}

bool isRetiredPrenatalRoute(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return false;
  return Uri.tryParse(normalized)?.path == '/hospital-bag-cart';
}

bool isRetiredPrenatalPlanType(Object? value) {
  return _retiredPlanTypes.contains(_normalizedString(value));
}

bool isRetiredPrenatalPlanPayload(Map<String, Object?> payload) {
  final type =
      payload['record_type'] ??
      payload['task_type'] ??
      payload['activity_type'] ??
      payload['kind'];
  return isRetiredPrenatalPlanType(type);
}

/// Removes links to retired prenatal destinations from persisted Agent
/// markdown. Non-retired links and surrounding text are preserved.
String stripRetiredPrenatalLinks(String markdown) {
  final withoutStandaloneLinks = markdown
      .split('\n')
      .where((line) => !_isStandaloneRetiredLink(line))
      .join('\n');
  final withoutMarkdownLinks = withoutStandaloneLinks.replaceAllMapped(
    _markdownLinkPattern,
    (match) {
      final destination = match.group(1)?.trim();
      return isRetiredPrenatalRoute(destination) ? '' : match.group(0) ?? '';
    },
  );
  return withoutMarkdownLinks
      .replaceAllMapped(_bareUrlPattern, (match) {
        final destination = match.group(0)?.trim();
        return isRetiredPrenatalRoute(destination) ? '' : match.group(0) ?? '';
      })
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

bool _isStandaloneRetiredLink(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final markdownDestination = _standaloneMarkdownLinkPattern
      .firstMatch(trimmed)
      ?.group(1)
      ?.trim();
  if (isRetiredPrenatalRoute(markdownDestination)) return true;
  final bareDestination = _standaloneBareUrlPattern
      .firstMatch(trimmed)
      ?.group(1)
      ?.trim();
  return isRetiredPrenatalRoute(bareDestination);
}

String? _normalizedString(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

final _markdownLinkPattern = RegExp(
  r'''(?:[*_]{1,3})?\s*\[[^\]\n]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)\s*(?:[*_]{1,3})?''',
);
final _standaloneMarkdownLinkPattern = RegExp(
  r'''^(?:[*_]{1,3})?\s*\[[^\]\n]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)\s*(?:[*_]{1,3})?$''',
);
final _bareUrlPattern = RegExp(
  r'(?:https?://[^\s)]+|/[a-z0-9][a-z0-9/_-]*(?:[?#][^\s)]*)?)',
  caseSensitive: false,
);
final _standaloneBareUrlPattern = RegExp(
  r'^(?:[*_]{1,3})?\s*((?:https?://[^\s)]+|/[a-z0-9][a-z0-9/_-]*(?:[?#][^\s)]*)?))\s*(?:[*_]{1,3})?$',
  caseSensitive: false,
);
