import 'dart:convert';
import 'dart:io';

import 'api_envelope.dart';

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

class ApiHttpResponse {
  const ApiHttpResponse({
    required this.statusCode,
    required this.statusText,
    required this.body,
  });

  final int statusCode;
  final String statusText;
  final String body;
}

abstract interface class ApiHttpConnector {
  Future<ApiHttpResponse> get(Uri uri, {required Map<String, String> headers});

  Future<ApiHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
}

class IoApiHttpConnector implements ApiHttpConnector {
  IoApiHttpConnector({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<ApiHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final request = await _httpClient.getUrl(uri);
    headers.forEach(request.headers.set);
    return _close(request);
  }

  @override
  Future<ApiHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = await _httpClient.postUrl(uri);
    headers.forEach(request.headers.set);
    request.write(body);
    return _close(request);
  }

  Future<ApiHttpResponse> _close(HttpClientRequest request) async {
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return ApiHttpResponse(
      statusCode: response.statusCode,
      statusText: response.reasonPhrase,
      body: body,
    );
  }
}

class IoApiJsonTransport implements ApiJsonTransport {
  const IoApiJsonTransport({
    required this.baseUri,
    this.token,
    this.headers = const <String, String>{},
    this.connector = const _DefaultApiHttpConnector(),
  });

  final Uri baseUri;
  final String? token;
  final Map<String, String> headers;
  final ApiHttpConnector connector;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final response = await connector.get(
      _resolve(path, query: query),
      headers: _requestHeaders(),
    );
    return _decodeResponse(response);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    final response = await connector.post(
      _resolve(path),
      headers: _requestHeaders(includeContentType: true),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Uri _resolve(String path, {Map<String, Object?> query = const {}}) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final nextPath = path.startsWith('/') ? path.substring(1) : path;
    final nextQuery = <String, String>{
      ...baseUri.queryParameters,
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return baseUri.replace(
      path: '$basePath$nextPath',
      queryParameters: nextQuery.isEmpty ? null : nextQuery,
    );
  }

  Map<String, String> _requestHeaders({bool includeContentType = false}) {
    final authToken = token?.trim();
    return {
      ...headers,
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, Object?> _decodeResponse(ApiHttpResponse response) {
    final body = _decodeJsonObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: response.statusCode,
        statusText: response.statusText,
        body: body,
        requestId: body?['request_id'] is String
            ? body!['request_id']! as String
            : null,
      );
    }
    if (body == null) {
      throw const ApiEnvelopeFormatException('Response body is not an object.');
    }
    return body;
  }
}

Map<String, Object?>? _decodeJsonObject(String body) {
  if (body.trim().isEmpty) return null;
  final decoded = jsonDecode(body);
  return decoded is Map ? Map<String, Object?>.from(decoded) : null;
}

class _DefaultApiHttpConnector implements ApiHttpConnector {
  const _DefaultApiHttpConnector();

  @override
  Future<ApiHttpResponse> get(Uri uri, {required Map<String, String> headers}) {
    return IoApiHttpConnector().get(uri, headers: headers);
  }

  @override
  Future<ApiHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return IoApiHttpConnector().post(uri, headers: headers, body: body);
  }
}
