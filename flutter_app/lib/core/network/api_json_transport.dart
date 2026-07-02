import 'dart:convert';
import 'dart:io';

import 'api_envelope.dart';
import 'transport_security_policy.dart';

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
    this.bytes = const <int>[],
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final List<int> bytes;
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
  IoApiJsonTransport({
    required Uri baseUri,
    this.token,
    this.headers = const <String, String>{},
    this.connector = const _DefaultApiHttpConnector(),
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri);

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

class IoApiMultipartTransport implements ApiMultipartTransport {
  IoApiMultipartTransport({
    required Uri baseUri,
    this.token,
    this.headers = const <String, String>{},
    HttpClient? httpClient,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       _httpClient = httpClient ?? HttpClient();

  final Uri baseUri;
  final String? token;
  final Map<String, String> headers;
  final HttpClient _httpClient;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    required ApiUploadFile file,
  }) async {
    final boundary = '----momcozy-${DateTime.now().microsecondsSinceEpoch}';
    final body = _multipartBody(boundary, fields, file);
    final request = await _httpClient.postUrl(_resolve(path));
    _requestHeaders(boundary).forEach(request.headers.set);
    request.contentLength = body.length;
    request.add(body);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return _decodeResponse(
      response.statusCode,
      response.reasonPhrase,
      responseBody,
    );
  }

  Uri _resolve(String path) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final nextPath = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.replace(path: '$basePath$nextPath');
  }

  Map<String, String> _requestHeaders(String boundary) {
    final authToken = token?.trim();
    return {
      ...headers,
      'Accept': 'application/json',
      'Content-Type': 'multipart/form-data; boundary=$boundary',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Map<String, Object?> _decodeResponse(
    int statusCode,
    String statusText,
    String body,
  ) {
    final decoded = _decodeJsonObject(body);
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiHttpException(
        statusCode: statusCode,
        statusText: statusText,
        body: decoded,
        requestId: decoded?['request_id'] is String
            ? decoded!['request_id']! as String
            : null,
      );
    }
    if (decoded == null) {
      throw const ApiEnvelopeFormatException('Response body is not an object.');
    }
    return decoded;
  }

  List<int> _multipartBody(
    String boundary,
    Map<String, Object?> fields,
    ApiUploadFile file,
  ) {
    final body = <int>[];
    void write(String value) => body.addAll(utf8.encode(value));

    for (final entry in fields.entries) {
      if (entry.value == null) continue;
      write('--$boundary\r\n');
      write(
        'Content-Disposition: form-data; name="${_escape(entry.key)}"\r\n\r\n',
      );
      write('${entry.value}\r\n');
    }

    write('--$boundary\r\n');
    write(
      'Content-Disposition: form-data; name="file"; filename="${_escape(file.name)}"\r\n',
    );
    write('Content-Type: ${file.mimeType}\r\n\r\n');
    body.addAll(file.bytes.isEmpty ? utf8.encode(file.name) : file.bytes);
    write('\r\n--$boundary--\r\n');
    return body;
  }

  String _escape(String value) => value.replaceAll('"', r'\"');
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
