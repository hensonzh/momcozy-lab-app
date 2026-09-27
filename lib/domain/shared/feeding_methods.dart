/// Shared, ordered choices for setup and the later Me profile editor.
const feedingMethodLabels = <String, String>{
  'direct': 'Direct breastfeeding',
  'expressed': 'Expressed breast milk',
  'formula': 'Formula',
  'unknown': 'Not sure yet',
};

bool validFeedingMethods(List<String> methods) =>
    methods.isNotEmpty &&
    methods.length <= 3 &&
    methods.every(feedingMethodLabels.containsKey) &&
    methods.toSet().length == methods.length &&
    (!methods.contains('unknown') || methods.length == 1);

List<String> toggleFeedingMethod(List<String> selected, String method) {
  if (!feedingMethodLabels.containsKey(method)) {
    throw ArgumentError.value(method, 'method');
  }
  if (selected.contains(method)) {
    // At least one explicit choice remains at all times.
    if (selected.length == 1) return selected;
    return selected.where((value) => value != method).toList();
  }
  if (method == 'unknown') return ['unknown'];
  final next = {...selected.where(feedingMethodLabels.containsKey), method}
    ..remove('unknown');
  return feedingMethodLabels.keys.where(next.contains).toList();
}
