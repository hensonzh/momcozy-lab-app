import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

class FixtureApiJsonTransport implements ApiJsonTransport {
  FixtureApiJsonTransport(this.response);

  final Map<String, Object?> response;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  Map<String, Object?>? lastBody;

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
    if (isHttpErrorBody(response)) throw ApiHttpException.fromBody(response);
    return response;
  }
}
