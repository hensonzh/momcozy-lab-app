import 'api_json_transport.dart';

/// Retries only an unauthorized request after refreshing the same login session.
class RefreshingJsonTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  const RefreshingJsonTransport({
    required this.transportFactory,
    required this.accessToken,
    required this.sessionGeneration,
    required this.refresh,
  });
  final ApiJsonTransport Function(String? token) transportFactory;
  final String? Function() accessToken;
  final int Function() sessionGeneration;
  final Future<void> Function(String? previousToken) refresh;
  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => _send((transport) => transport.getJson(path, query: query));
  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send(
    (transport) => transport.postJson(path, body: body, headers: headers),
  );
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send(
    (transport) => (transport as ApiJsonMutationTransport).putJson(
      path,
      body: body,
      headers: headers,
    ),
  );
  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => _send(
    (transport) => (transport as ApiJsonMutationTransport).patchJson(
      path,
      body: body,
      headers: headers,
    ),
  );
  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) => _send(
    (transport) => (transport as ApiJsonMutationTransport).deleteJson(
      path,
      headers: headers,
    ),
  );

  Future<Map<String, Object?>> _send(
    Future<Map<String, Object?>> Function(ApiJsonTransport transport) call,
  ) async {
    final generation = sessionGeneration(), token = accessToken();
    void checkSession() {
      if (generation != sessionGeneration()) {
        throw const ApiHttpException(
          statusCode: 401,
          statusText: 'Session changed',
          body: null,
        );
      }
    }

    try {
      final result = await call(transportFactory(token));
      checkSession();
      return result;
    } on ApiHttpException catch (error) {
      if (error.statusCode != 401 ||
          generation != sessionGeneration() ||
          token == null) {
        rethrow;
      }
      await refresh(token);
      if (generation != sessionGeneration() || accessToken() == null) rethrow;
      final result = await call(transportFactory(accessToken()));
      checkSession();
      return result;
    }
  }
}
