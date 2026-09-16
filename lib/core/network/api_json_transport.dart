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
    Map<String, String> headers = const {},
  });
}

abstract interface class ApiJsonMutationTransport {
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  });

  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  });

  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  });
}

class ApiErrorEnvelope {
  const ApiErrorEnvelope({
    required this.code,
    required this.message,
    this.requestId,
    this.details,
  });

  factory ApiErrorEnvelope.fromMap(Map<String, Object?> map) {
    return ApiErrorEnvelope(
      code: _stringOrEmpty(map['code']),
      message: _stringOrEmpty(map['message']),
      requestId: map['request_id'] is String
          ? map['request_id']! as String
          : null,
      details: map['details'],
    );
  }

  final String code;
  final String message;
  final String? requestId;
  final Object? details;
}

class ApiHttpException implements Exception {
  const ApiHttpException({
    required this.statusCode,
    required this.statusText,
    required this.body,
    this.requestId,
  });

  factory ApiHttpException.fromBody(Map<String, Object?> body) {
    final responseBody = body['body'] is Map
        ? Map<String, Object?>.from(body['body']! as Map)
        : null;
    return ApiHttpException(
      statusCode: body['http_status'] is int ? body['http_status']! as int : 0,
      statusText: body['status_text'] is String
          ? body['status_text']! as String
          : '',
      requestId: _requestIdFromErrorBody(responseBody),
      body: responseBody,
    );
  }

  final int statusCode;
  final String statusText;
  final String? requestId;
  final Map<String, Object?>? body;

  ApiErrorEnvelope? get error {
    final errorBody = body?['error'];
    if (errorBody is Map) {
      return ApiErrorEnvelope.fromMap(Map<String, Object?>.from(errorBody));
    }
    return null;
  }

  String? get effectiveRequestId => requestId ?? error?.requestId;

  String? get errorCode => error?.code;

  String? get errorMessage => error?.message;

  @override
  String toString() => 'ApiHttpException($statusCode, $statusText)';
}

abstract interface class ApiMultipartTransport {
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  });
}

typedef ApiUploadStreamFactory = Stream<List<int>> Function();
typedef ApiUploadProgress = void Function(int sentBytes, int totalBytes);

class ApiUploadFile {
  const ApiUploadFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    this.bytes = const <int>[],
    this.openRead,
    this.onProgress,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final List<int> bytes;
  final ApiUploadStreamFactory? openRead;
  final ApiUploadProgress? onProgress;
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

  Future<ApiHttpResponse> put(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });

  Future<ApiHttpResponse> patch(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });

  Future<ApiHttpResponse> delete(
    Uri uri, {
    required Map<String, String> headers,
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
    return _sendJson('POST', uri, headers: headers, body: body);
  }

  @override
  Future<ApiHttpResponse> put(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return _sendJson('PUT', uri, headers: headers, body: body);
  }

  @override
  Future<ApiHttpResponse> patch(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    return _sendJson('PATCH', uri, headers: headers, body: body);
  }

  @override
  Future<ApiHttpResponse> delete(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final request = await _httpClient.openUrl('DELETE', uri);
    headers.forEach(request.headers.set);
    return _close(request);
  }

  Future<ApiHttpResponse> _sendJson(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final request = await _httpClient.openUrl(method, uri);
    headers.forEach(request.headers.set);
    request.add(utf8.encode(body));
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

class IoApiJsonTransport implements ApiJsonTransport, ApiJsonMutationTransport {
  IoApiJsonTransport({
    required Uri baseUri,
    this.token,
    this.headers = const <String, String>{},
    ApiHttpConnector? connector,
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri),
       connector =
           connector ??
           IoApiHttpConnector(httpClient: _sharedDefaultHttpClient);

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
    Map<String, String> headers = const {},
  }) async {
    final response = await connector.post(
      _resolve(path),
      headers: _requestHeaders(includeContentType: true, extraHeaders: headers),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final response = await connector.put(
      _resolve(path),
      headers: _requestHeaders(includeContentType: true, extraHeaders: headers),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final response = await connector.patch(
      _resolve(path),
      headers: _requestHeaders(includeContentType: true, extraHeaders: headers),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final response = await connector.delete(
      _resolve(path),
      headers: _requestHeaders(extraHeaders: headers),
    );
    return _decodeResponse(response, allowEmpty: true);
  }

  Uri _resolve(String path, {Map<String, Object?> query = const {}}) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    // Mutation callers may carry optimistic-lock parameters in the relative URL.
    // Keep them in the query; Uri.replace(path: ...) would encode '?' as %3F.
    final queryStart = path.indexOf('?');
    final pathOnly = queryStart < 0 ? path : path.substring(0, queryStart);
    final nextPath = pathOnly.startsWith('/')
        ? pathOnly.substring(1)
        : pathOnly;
    final nextQuery = <String, String>{
      ...baseUri.queryParameters,
      if (queryStart >= 0)
        ...Uri.splitQueryString(path.substring(queryStart + 1)),
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return baseUri.replace(
      path: '$basePath$nextPath',
      queryParameters: nextQuery.isEmpty ? null : nextQuery,
    );
  }

  Map<String, String> _requestHeaders({
    bool includeContentType = false,
    Map<String, String> extraHeaders = const {},
  }) {
    final authToken = token?.trim();
    return {
      ...headers,
      'Accept': 'application/json',
      if (includeContentType) 'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
      ...extraHeaders,
    };
  }

  Map<String, Object?> _decodeResponse(
    ApiHttpResponse response, {
    bool allowEmpty = false,
  }) {
    final body = _decodeJsonObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: response.statusCode,
        statusText: response.statusText,
        body: body,
        requestId: _requestIdFromErrorBody(body),
      );
    }
    if (body == null && allowEmpty && response.body.trim().isEmpty) {
      return const <String, Object?>{};
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
       _httpClient = httpClient ?? _sharedDefaultHttpClient;

  final Uri baseUri;
  final String? token;
  final Map<String, String> headers;
  final HttpClient _httpClient;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    final boundary = '----momcozy-${DateTime.now().microsecondsSinceEpoch}';
    final prefix = _multipartPrefix(boundary, fields, file);
    final suffix = utf8.encode('\r\n--$boundary--\r\n');
    final request = await _httpClient.postUrl(_resolve(path, query: query));
    _requestHeaders(
      boundary,
      extraHeaders: headers,
    ).forEach(request.headers.set);
    request.contentLength = prefix.length + file.sizeBytes + suffix.length;
    await request.addStream(
      _multipartBodyStream(prefix: prefix, suffix: suffix, file: file),
    );
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    return _decodeResponse(
      response.statusCode,
      response.reasonPhrase,
      responseBody,
    );
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

  Map<String, String> _requestHeaders(
    String boundary, {
    Map<String, String> extraHeaders = const {},
  }) {
    final authToken = token?.trim();
    return {
      ...headers,
      'Accept': 'application/json',
      'Content-Type': 'multipart/form-data; boundary=$boundary',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
      ...extraHeaders,
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
        requestId: _requestIdFromErrorBody(decoded),
      );
    }
    if (decoded == null) {
      throw const ApiEnvelopeFormatException('Response body is not an object.');
    }
    return decoded;
  }

  List<int> _multipartPrefix(
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
    return body;
  }

  Stream<List<int>> _multipartBodyStream({
    required List<int> prefix,
    required List<int> suffix,
    required ApiUploadFile file,
  }) async* {
    yield prefix;
    var sentBytes = 0;
    file.onProgress?.call(0, file.sizeBytes);
    final source = file.openRead?.call() ?? Stream<List<int>>.value(file.bytes);
    await for (final chunk in source) {
      sentBytes += chunk.length;
      if (sentBytes > file.sizeBytes) {
        throw StateError('Upload stream exceeded declared file size.');
      }
      yield chunk;
      file.onProgress?.call(sentBytes, file.sizeBytes);
    }
    if (sentBytes != file.sizeBytes) {
      throw StateError('Upload stream did not match declared file size.');
    }
    yield suffix;
  }

  String _escape(String value) => value.replaceAll('"', r'\"');
}

Map<String, Object?>? _decodeJsonObject(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, Object?>.from(decoded) : null;
  } on FormatException {
    return null;
  }
}

String? _requestIdFromErrorBody(Map<String, Object?>? body) {
  if (body == null) return null;
  if (body['request_id'] is String) return body['request_id']! as String;
  final error = body['error'];
  if (error is Map && error['request_id'] is String) {
    return error['request_id']! as String;
  }
  return null;
}

String _stringOrEmpty(Object? value) => value is String ? value : '';

final HttpClient _sharedDefaultHttpClient = HttpClient()
  ..idleTimeout = const Duration(seconds: 90)
  ..maxConnectionsPerHost = 8;
