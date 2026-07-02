import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

class FixtureApiJsonTransport implements ApiJsonTransport {
  FixtureApiJsonTransport(this.response);

  final Map<String, Object?> response;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastBody;
  final List<Map<String, Object?>> postedBodies = [];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    lastPath = path;
    lastQuery = Map<String, Object?>.from(query);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    postedBodies.add(lastBody!);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }
}

class FixtureApiJsonTransportByPath implements ApiJsonTransport {
  FixtureApiJsonTransportByPath(this.responsesByPath);

  final Map<String, Map<String, Object?>> responsesByPath;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastBody;
  final List<Map<String, Object?>> postedBodies = [];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    lastPath = path;
    lastQuery = Map<String, Object?>.from(query);
    final response = _response(path);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
  }) async {
    lastPath = path;
    lastBody = Map<String, Object?>.from(body);
    postedBodies.add(lastBody!);
    final response = _response(path);
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }

  Map<String, Object?> _response(String path) {
    return responsesByPath[path] ??
        const <String, Object?>{'status': 200, 'data': <String, Object?>{}};
  }
}

class FixtureApiMultipartTransport implements ApiMultipartTransport {
  FixtureApiMultipartTransport(this.response, {this.failure});

  final Map<String, Object?> response;
  final Object? failure;
  String? lastPath;
  Map<String, Object?>? lastFields;
  ApiUploadFile? lastFile;

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> fields = const {},
    required ApiUploadFile file,
  }) async {
    lastPath = path;
    lastFields = Map<String, Object?>.from(fields);
    lastFile = file;
    final failure = this.failure;
    if (failure != null) throw failure;
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }
}
