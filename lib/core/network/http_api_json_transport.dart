import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_json_transport.dart';
import 'transport_security_policy.dart';

/// JSON transport shared by native and web entrypoints. The runtime owns [client].
class HttpApiJsonTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  HttpApiJsonTransport({
    required Uri baseUri,
    required this.client,
    this.accessToken,
    this.timeout = const Duration(seconds: 25),
  }) : baseUri = TransportSecurityPolicy.requireSecureHttp(baseUri) {
    if (baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment) {
      throw ArgumentError(
        'API base URL cannot contain credentials, query, or fragment.',
      );
    }
  }
  final Uri baseUri;
  final http.Client client;
  final String? accessToken;
  final Duration timeout;
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => _send('GET', path, query: query);
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send('POST', path, body: body, headers: headers);
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send('PUT', path, body: body, headers: headers);
  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send('PATCH', path, body: body, headers: headers);
  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => _send('DELETE', path, headers: headers);

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final target = baseUri.resolve(path);
    if (target.origin != baseUri.origin || target.userInfo.isNotEmpty) {
      throw ArgumentError('API requests must remain on the configured origin.');
    }
    final uri = target.replace(
      queryParameters: query.isEmpty
          ? null
          : {
              for (final entry in query.entries)
                if (entry.value != null) entry.key: entry.value.toString(),
            },
    );
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers.addAll({
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      ...headers,
    });
    if (method != 'GET' && method != 'DELETE') {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await client.send(request).timeout(timeout),
    ).timeout(timeout);
    Map<String, Object?>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) json = Map<String, Object?>.from(decoded);
    } on FormatException {
      // Preserve the HTTP status for non-JSON proxy responses without exposing their body.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiHttpException(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase ?? '',
        body: json,
        requestId: response.headers['x-request-id'],
      );
    }
    if (json == null) {
      if (response.statusCode == 204) return const {};
      throw const FormatException('API response is not a JSON object.');
    }
    return json;
  }
}
