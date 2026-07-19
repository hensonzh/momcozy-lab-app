class ApiBusinessException implements Exception {
  ApiBusinessException({
    required this.status,
    required this.message,
    required this.raw,
  });

  final int status;
  final String message;
  final Map<String, Object?> raw;

  @override
  String toString() => 'ApiBusinessException($status, $message)';
}

class ApiEnvelopeFormatException implements Exception {
  const ApiEnvelopeFormatException(this.message);

  final String message;

  @override
  String toString() => 'ApiEnvelopeFormatException($message)';
}

Object? unwrapApiEnvelope(Map<String, Object?> response) {
  final status = response['status'];
  if (status is! int) {
    throw const ApiEnvelopeFormatException('Missing numeric status.');
  }

  if (!response.containsKey('data')) {
    throw const ApiEnvelopeFormatException('Missing data field.');
  }

  if (status != 200) {
    final message = response['message'];
    throw ApiBusinessException(
      status: status,
      message: message is String ? message : '',
      raw: response,
    );
  }

  return response['data'];
}

bool isApiEnvelope(Map<String, Object?> response) {
  return response['status'] is int && response.containsKey('data');
}

bool isHttpErrorBody(Map<String, Object?> response) {
  return response['http_status'] is int && !response.containsKey('data');
}

String? aliasString(
  Map<String, Object?> map,
  String snakeKey,
  String camelKey,
) {
  final value = map[snakeKey] ?? map[camelKey];
  return value is String ? value : null;
}
