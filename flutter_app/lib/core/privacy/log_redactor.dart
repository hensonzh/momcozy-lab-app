const redactedLogValue = '***';

Map<String, Object?> redactLogMap(Map<String, Object?> payload) {
  return Map<String, Object?>.unmodifiable({
    for (final entry in payload.entries)
      entry.key: isSensitiveLogKey(entry.key)
          ? redactedLogValue
          : redactLogValue(entry.value),
  });
}

Object? redactLogValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        '${entry.key}': isSensitiveLogKey('${entry.key}')
            ? redactedLogValue
            : redactLogValue(entry.value),
    });
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(redactLogValue));
  }
  if (value is Uri) {
    return redactUrlForLog(value.toString());
  }
  if (value is String && value.contains('?')) {
    return redactUrlForLog(value);
  }
  return value;
}

String redactUrlForLog(String rawUrl) {
  final queryStart = rawUrl.indexOf('?');
  if (queryStart < 0) return rawUrl;

  final fragmentStart = rawUrl.indexOf('#', queryStart);
  final prefix = rawUrl.substring(0, queryStart + 1);
  final query = fragmentStart < 0
      ? rawUrl.substring(queryStart + 1)
      : rawUrl.substring(queryStart + 1, fragmentStart);
  final fragment = fragmentStart < 0 ? '' : rawUrl.substring(fragmentStart);
  final redactedQuery = query
      .split('&')
      .map((part) => _redactQueryPart(part))
      .join('&');
  return '$prefix$redactedQuery$fragment';
}

bool isSensitiveLogKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized == 'authorization' ||
      normalized == 'cookie' ||
      normalized == 'setcookie' ||
      normalized == 'token' ||
      normalized.endsWith('token') ||
      normalized == 'apikey' ||
      normalized == 'userid' ||
      normalized == 'conversationid' ||
      normalized == 'threadid' ||
      normalized == 'sessionid' ||
      normalized == 'serialnumber' ||
      normalized == 'deviceid' ||
      normalized == 'bledeviceid' ||
      normalized == 'healthdata' ||
      normalized == 'healthpayload' ||
      normalized == 'momhealth' ||
      normalized == 'babyhealth' ||
      normalized == 'pumpmilkrecords' ||
      normalized == 'feedingrecords' ||
      normalized == 'growthrecords' ||
      normalized == 'pregnancydiary';
}

String _redactQueryPart(String part) {
  final equalsIndex = part.indexOf('=');
  final rawKey = equalsIndex < 0 ? part : part.substring(0, equalsIndex);
  final key = Uri.decodeQueryComponent(rawKey.replaceAll('+', ' '));
  if (!isSensitiveLogKey(key)) return part;
  return equalsIndex < 0 ? rawKey : '$rawKey=$redactedLogValue';
}
