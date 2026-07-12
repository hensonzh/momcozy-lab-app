import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

void main() {
  group('IoApiJsonTransport', () {
    test('sends GET query, auth, and headers', () async {
      final connector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          body: '{"status":200,"data":{"ok":true}}',
        ),
      );
      final transport = IoApiJsonTransport(
        baseUri: Uri.parse('http://127.0.0.1:8769?existing=1'),
        token: 'secret-token',
        headers: const {'X-Momcozy-Client': 'flutter'},
        connector: connector,
      );

      final response = await transport.getJson(
        '/v1/files',
        query: {'limit': 10},
      );

      expect(response['status'], 200);
      expect(
        connector.uri,
        Uri.parse('http://127.0.0.1:8769/v1/files?existing=1&limit=10'),
      );
      expect(connector.headers, containsPair('Accept', 'application/json'));
      expect(
        connector.headers,
        containsPair('Authorization', 'Bearer secret-token'),
      );
      expect(connector.headers, containsPair('X-Momcozy-Client', 'flutter'));
      expect(connector.body, isNull);
    });

    test('sends POST JSON body and content type', () async {
      final connector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          body: '{"status":200,"data":{"accepted":true}}',
        ),
      );
      final transport = IoApiJsonTransport(
        baseUri: Uri.parse('http://127.0.0.1:8769'),
        connector: connector,
      );

      await transport.postJson(
        '/v1/records/feeding',
        body: {'feed_time': '2026-06-29T08:00:00Z', 'feed_type': 'bottle'},
        headers: {'Idempotency-Key': 'idem-001'},
      );

      expect(
        connector.uri,
        Uri.parse('http://127.0.0.1:8769/v1/records/feeding'),
      );
      expect(
        connector.headers,
        containsPair('Content-Type', 'application/json'),
      );
      expect(connector.headers, containsPair('Idempotency-Key', 'idem-001'));
      expect(jsonDecode(connector.body!) as Map<String, Object?>, {
        'feed_time': '2026-06-29T08:00:00Z',
        'feed_type': 'bottle',
      });
    });

    test('sends PUT, PATCH, and DELETE mutations', () async {
      final connector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          body: '{"id":"record-001"}',
        ),
      );
      final transport = IoApiJsonTransport(
        baseUri: Uri.parse('http://127.0.0.1:8769'),
        connector: connector,
      );

      final putResponse = await transport.putJson(
        '/v1/pregnancy-diary/entries/2026-07-11',
        body: {'mood': '平稳'},
      );
      expect(putResponse, {'id': 'record-001'});
      expect(connector.method, 'PUT');
      expect(jsonDecode(connector.body!) as Map<String, Object?>, {
        'mood': '平稳',
      });

      final patchResponse = await transport.patchJson(
        '/v1/plans/tasks/task-001/completion',
        body: {'completed': true},
      );
      expect(patchResponse, {'id': 'record-001'});
      expect(connector.method, 'PATCH');
      expect(jsonDecode(connector.body!) as Map<String, Object?>, {
        'completed': true,
      });

      final deleteResponse = await transport.deleteJson('/v1/plans/plan-001');
      expect(deleteResponse, {'id': 'record-001'});
      expect(connector.method, 'DELETE');
      expect(connector.body, isNull);
    });

    test('accepts an empty successful DELETE response', () async {
      final connector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 204,
          statusText: 'No Content',
          body: '',
        ),
      );
      final transport = IoApiJsonTransport(
        baseUri: Uri.parse('http://127.0.0.1:8769'),
        connector: connector,
      );

      final response = await transport.deleteJson('/v1/plans/plan-001');

      expect(response, isEmpty);
      expect(connector.method, 'DELETE');
    });

    test('HTTP connector sends non-ASCII JSON bodies as UTF-8', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final receivedBody = server.first.then((request) async {
        final body = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"status":200,"data":{"accepted":true}}');
        await request.response.close();
        return body;
      });
      final connector = IoApiHttpConnector();

      final response = await connector.post(
        Uri.parse('http://${server.address.host}:${server.port}/v1/diary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'content': '今天感觉不错'}),
      );

      expect(response.statusCode, 200);
      expect(jsonDecode(await receivedBody) as Map<String, Object?>, {
        'content': '今天感觉不错',
      });
    });

    test('throws typed exceptions for HTTP and malformed bodies', () async {
      final httpConnector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 502,
          statusText: 'Bad Gateway',
          body: '{"request_id":"req-001","message":"upstream down"}',
        ),
      );
      final malformedConnector = _RecordingApiHttpConnector(
        const ApiHttpResponse(statusCode: 200, statusText: 'OK', body: '[]'),
      );
      final nonJsonHttpConnector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 503,
          statusText: 'Service Unavailable',
          body: '<html>temporarily unavailable</html>',
        ),
      );
      final productionErrorConnector = _RecordingApiHttpConnector(
        const ApiHttpResponse(
          statusCode: 429,
          statusText: 'Too Many Requests',
          body:
              '{"error":{"code":"rate_limited","message":"Slow down","request_id":"req-prod","details":{"retry_after_seconds":60}}}',
        ),
      );

      await expectLater(
        IoApiJsonTransport(
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          connector: httpConnector,
        ).getJson('/v1/user/profile'),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.requestId,
            'requestId',
            'req-001',
          ),
        ),
      );
      await expectLater(
        IoApiJsonTransport(
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          connector: malformedConnector,
        ).getJson('/v1/user/profile'),
        throwsA(isA<ApiEnvelopeFormatException>()),
      );
      await expectLater(
        IoApiJsonTransport(
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          connector: nonJsonHttpConnector,
        ).getJson('/v1/user/profile'),
        throwsA(
          isA<ApiHttpException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.body, 'body', isNull),
        ),
      );
      await expectLater(
        IoApiJsonTransport(
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          connector: productionErrorConnector,
        ).getJson('/v1/records/feeding'),
        throwsA(
          isA<ApiHttpException>()
              .having((error) => error.statusCode, 'statusCode', 429)
              .having((error) => error.requestId, 'requestId', 'req-prod')
              .having(
                (error) => error.effectiveRequestId,
                'effectiveRequestId',
                'req-prod',
              )
              .having((error) => error.errorCode, 'errorCode', 'rate_limited')
              .having(
                (error) => error.errorMessage,
                'errorMessage',
                'Slow down',
              ),
        ),
      );
    });

    test(
      'omits missing tokens and surfaces expired-token HTTP status',
      () async {
        final missingTokenConnector = _RecordingApiHttpConnector(
          const ApiHttpResponse(
            statusCode: 200,
            statusText: 'OK',
            body: '{"status":200,"data":{"ok":true}}',
          ),
        );
        final expiredTokenConnector = _RecordingApiHttpConnector(
          const ApiHttpResponse(
            statusCode: 401,
            statusText: 'Unauthorized',
            body: '{"request_id":"auth-expired","message":"token expired"}',
          ),
        );

        await IoApiJsonTransport(
          baseUri: Uri.parse('http://127.0.0.1:8769'),
          token: ' ',
          connector: missingTokenConnector,
        ).getJson('/v1/profile/me');

        expect(
          missingTokenConnector.headers,
          isNot(containsPair('Authorization', anything)),
        );
        await expectLater(
          IoApiJsonTransport(
            baseUri: Uri.parse('http://127.0.0.1:8769'),
            token: 'expired-token',
            connector: expiredTokenConnector,
          ).getJson('/v1/profile/me'),
          throwsA(
            isA<ApiHttpException>()
                .having((error) => error.statusCode, 'statusCode', 401)
                .having(
                  (error) => error.requestId,
                  'requestId',
                  'auth-expired',
                ),
          ),
        );
      },
    );
  });
}

class _RecordingApiHttpConnector implements ApiHttpConnector {
  _RecordingApiHttpConnector(this.response);

  final ApiHttpResponse response;
  Uri? uri;
  Map<String, String>? headers;
  String? body;
  String? method;

  @override
  Future<ApiHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    method = 'GET';
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    body = null;
    return response;
  }

  @override
  Future<ApiHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    method = 'POST';
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.body = body;
    return response;
  }

  @override
  Future<ApiHttpResponse> put(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    method = 'PUT';
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.body = body;
    return response;
  }

  @override
  Future<ApiHttpResponse> patch(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    method = 'PATCH';
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.body = body;
    return response;
  }

  @override
  Future<ApiHttpResponse> delete(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    method = 'DELETE';
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    body = null;
    return response;
  }
}
