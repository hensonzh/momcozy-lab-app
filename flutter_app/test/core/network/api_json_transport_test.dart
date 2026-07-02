import 'dart:convert';

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
        '/v1/mom-baby/info/query',
        query: {'user_id': 'demo-user-fixture'},
      );

      expect(response['status'], 200);
      expect(
        connector.uri,
        Uri.parse(
          'http://127.0.0.1:8769/v1/mom-baby/info/query?existing=1&user_id=demo-user-fixture',
        ),
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
        '/v1/pump/workstate',
        body: {'user_id': 'demo-user-fixture'},
      );

      expect(
        connector.uri,
        Uri.parse('http://127.0.0.1:8769/v1/pump/workstate'),
      );
      expect(
        connector.headers,
        containsPair('Content-Type', 'application/json'),
      );
      expect(jsonDecode(connector.body!) as Map<String, Object?>, {
        'user_id': 'demo-user-fixture',
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
        ).getJson('/v1/mom-baby/info/query');

        expect(
          missingTokenConnector.headers,
          isNot(containsPair('Authorization', anything)),
        );
        await expectLater(
          IoApiJsonTransport(
            baseUri: Uri.parse('http://127.0.0.1:8769'),
            token: 'expired-token',
            connector: expiredTokenConnector,
          ).getJson('/v1/mom-baby/info/query'),
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

  @override
  Future<ApiHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
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
    this.uri = uri;
    this.headers = Map<String, String>.from(headers);
    this.body = body;
    return response;
  }
}
