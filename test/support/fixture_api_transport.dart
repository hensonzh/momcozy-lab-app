import 'package:app/core/network/api_envelope.dart';
import 'package:app/core/network/api_json_transport.dart';

class FixtureApiJsonTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  FixtureApiJsonTransport(this.response);

  final Map<String, Object?> response;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastBody;
  Map<String, String>? lastHeaders;
  final List<Map<String, Object?>> postedBodies = [];
  final List<String> getPaths = [];
  String? lastMethod;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    getPaths.add(path);
    lastQuery = Map<String, Object?>.from(query);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _mutate('PUT', path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _mutate('PATCH', path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => _mutate('DELETE', path, headers: headers);

  Future<Map<String, Object?>> _mutate(
    String method,
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    if (method != 'DELETE') postedBodies.add(lastBody!);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }
}

class FixtureApiJsonTransportByPath
    implements ApiJsonTransport, ApiJsonMutationTransport {
  FixtureApiJsonTransportByPath(
    this.responsesByPath, {
    this.writeResponsesByPath = const {},
  });

  final Map<String, Map<String, Object?>> responsesByPath;
  final Map<String, Map<String, Object?>> writeResponsesByPath;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastBody;
  Map<String, String>? lastHeaders;
  final List<Map<String, Object?>> postedBodies = [];
  final List<String> getPaths = [];
  String? lastMethod;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    lastMethod = 'GET';
    lastPath = path;
    getPaths.add(path);
    lastQuery = Map<String, Object?>.from(query);
    final response = _response(path);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = 'POST';
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    postedBodies.add(lastBody!);
    final response = _writeResponse(path);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _mutate('PUT', path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _mutate('PATCH', path, body: body, headers: headers);

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => _mutate('DELETE', path, headers: headers);

  Future<Map<String, Object?>> _mutate(
    String method,
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    lastHeaders = Map<String, String>.from(headers);
    if (method != 'DELETE') postedBodies.add(lastBody!);
    final response = _writeResponse(path);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  Map<String, Object?> _response(String path) {
    return responsesByPath[path] ??
        const <String, Object?>{'status': 200, 'data': <String, Object?>{}};
  }

  Map<String, Object?> _writeResponse(String path) {
    return writeResponsesByPath[path] ?? _response(path);
  }
}

class FixtureApiMultipartTransport implements ApiMultipartTransport {
  FixtureApiMultipartTransport(this.response, {this.failure});

  final Map<String, Object?> response;
  final Object? failure;
  String? lastPath;
  Map<String, Object?>? lastFields;
  Map<String, String>? lastHeaders;
  ApiUploadFile? lastFile;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    lastPath = path;
    lastFields = Map<String, Object?>.from(fields);
    lastHeaders = Map<String, String>.from(headers);
    lastFile = file;
    final failure = this.failure;
    if (failure != null) throw failure;
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }
}
