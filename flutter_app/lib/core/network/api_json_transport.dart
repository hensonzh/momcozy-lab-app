abstract interface class ApiJsonTransport {
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  });

  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  });
}

class ApiHttpException implements Exception {
  const ApiHttpException({
    required this.statusCode,
    required this.statusText,
    required this.body,
    this.requestId,
  });

  factory ApiHttpException.fromBody(Map<String, Object?> body) {
    return ApiHttpException(
      statusCode: body['http_status'] is int ? body['http_status']! as int : 0,
      statusText: body['status_text'] is String
          ? body['status_text']! as String
          : '',
      requestId: body['request_id'] is String
          ? body['request_id']! as String
          : null,
      body: body['body'] is Map
          ? Map<String, Object?>.from(body['body']! as Map)
          : null,
    );
  }

  final int statusCode;
  final String statusText;
  final String? requestId;
  final Map<String, Object?>? body;

  @override
  String toString() => 'ApiHttpException($statusCode, $statusText)';
}

abstract interface class ApiMultipartTransport {
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    required ApiUploadFile file,
  });
}

class ApiUploadFile {
  const ApiUploadFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
}

class ApiRequestCancelledException implements Exception {
  const ApiRequestCancelledException();

  @override
  String toString() => 'ApiRequestCancelledException()';
}

class ApiRequestTimeoutException implements Exception {
  const ApiRequestTimeoutException();

  @override
  String toString() => 'ApiRequestTimeoutException()';
}
