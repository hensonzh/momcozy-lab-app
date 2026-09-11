Map<String, Object?> jsonObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected an object.');
  return Map<String, Object?>.from(value);
}

String jsonString(Object? value) {
  if (value is! String) throw const FormatException('Expected a string.');
  return value;
}

int jsonInt(Object? value) {
  if (value is! int) throw const FormatException('Expected an integer.');
  return value;
}

double jsonDouble(Object? value) {
  if (value is! num || !value.isFinite) {
    throw const FormatException('Expected a finite number.');
  }
  return value.toDouble();
}

void requireOnlyKeys(Map<String, Object?> value, Set<String> keys) {
  if (value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Unexpected fields in the current contract.');
  }
}

/// Explicit wire values prevent Dart renames from silently changing the API.
class EnumWire<T extends Enum> {
  const EnumWire(this.mapping);
  final Map<T, String> mapping;
  T? read(Object? value) {
    if (value == null) return null;
    for (final entry in mapping.entries) {
      if (entry.value == value) return entry.key;
    }
    throw const FormatException('Unknown enum value.');
  }

  String? write(T? value) => value == null ? null : mapping[value]!;
  Set<T> readSet(Object? value) {
    if (value == null) return {};
    if (value is! List) throw const FormatException('Expected a list.');
    return Set.unmodifiable(
      value.map(
        (item) =>
            read(item) ?? (throw const FormatException('Null enum item.')),
      ),
    );
  }

  List<String> writeSet(Set<T> values) =>
      values.map((value) => write(value)!).toList(growable: false);
}

List<T> jsonList<T>(Object? value, T Function(Map<String, Object?>) read) {
  if (value is! List) throw const FormatException('Expected a list.');
  return List.unmodifiable(value.map((item) => read(jsonObject(item))));
}

List<String> jsonStrings(Object? value) {
  if (value is! List) throw const FormatException('Expected strings.');
  return List.unmodifiable(value.map(jsonString));
}

DateTime jsonInstant(Object? value) {
  final instant = DateTime.parse(jsonString(value));
  if (!instant.isUtc) {
    throw const FormatException('Timestamp requires timezone.');
  }
  return instant;
}

bool jsonBool(Object? value) {
  if (value is! bool) throw const FormatException('Expected a boolean.');
  return value;
}
