import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/http_api_json_transport.dart';
import 'package:momcozy_flutter_app/core/network/refreshing_json_transport.dart';

void main() {
  test(
    'empty 204 acknowledgements succeed while empty JSON responses are rejected',
    () async {
      var status = 204;
      final client = MockClient((_) async => http.Response('', status));
      addTearDown(client.close);
      final transport = HttpApiJsonTransport(
        baseUri: Uri.parse('http://localhost:8000'),
        client: client,
      );
      expect(
        await transport.putJson('/v1/ibclc/reminders/event/read'),
        isEmpty,
      );
      status = 200;
      await expectLater(
        transport.getJson('/v1/ibclc/reminders'),
        throwsFormatException,
      );
    },
  );
  test(
    'authorized retry preserves the mutation body and idempotency key',
    () async {
      var token = 'old';
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.headers['authorization'] == 'Bearer old'
                ? {
                    'error': {'code': 'authentication_required'},
                  }
                : {'saved': true},
          ),
          requests.length == 1 ? 401 : 200,
        );
      });
      addTearDown(client.close);
      final transport = RefreshingJsonTransport(
        transportFactory: (token) => HttpApiJsonTransport(
          baseUri: Uri.parse('http://localhost:8000'),
          client: client,
          accessToken: token,
        ),
        accessToken: () => token,
        sessionGeneration: () => 1,
        refresh: (_) async {
          token = 'new';
        },
      );
      final result = await transport.putJson(
        '/v1/clinical-note',
        body: {'expected_version': 4, 'text': '同一份草稿'},
        headers: {'Idempotency-Key': 'stable-key'},
      );
      expect(result, {'saved': true});
      expect(requests, hasLength(2));
      expect(requests.first.body, requests.last.body);
      expect(requests.last.headers['Idempotency-Key'], 'stable-key');
      expect(requests.last.headers['authorization'], 'Bearer new');
    },
  );
  test(
    'a successful response from a logged-out session is discarded',
    () async {
      final gate = Completer<http.Response>();
      final started = Completer<void>();
      var generation = 1;
      final client = MockClient((_) {
        started.complete();
        return gate.future;
      });
      addTearDown(client.close);
      final transport = RefreshingJsonTransport(
        transportFactory: (token) => HttpApiJsonTransport(
          baseUri: Uri.parse('http://localhost:8000'),
          client: client,
          accessToken: token,
        ),
        accessToken: () => 'old',
        sessionGeneration: () => generation,
        refresh: (_) async => fail('Must not refresh a previous session'),
      );
      final request = transport.getJson('/v1/ibclc/clients');
      final expectation = expectLater(
        request,
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.statusCode,
            'status',
            401,
          ),
        ),
      );
      await started.future;
      generation++;
      gate.complete(http.Response('{"private":"old account"}', 200));
      await expectation;
    },
  );
  test(
    'network failure does not retry a potentially completed mutation',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        throw http.ClientException('offline');
      });
      addTearDown(client.close);
      final transport = RefreshingJsonTransport(
        transportFactory: (token) => HttpApiJsonTransport(
          baseUri: Uri.parse('http://localhost:8000'),
          client: client,
          accessToken: token,
        ),
        accessToken: () => 'old',
        sessionGeneration: () => 1,
        refresh: (_) async =>
            fail('Network failures do not refresh credentials'),
      );
      await expectLater(
        transport.postJson(
          '/v1/care/plan/publish',
          headers: {'Idempotency-Key': 'frozen-key'},
        ),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
    },
  );
  test(
    'transport rejects a foreign origin without sending credentials and preserves proxy error status',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.followRedirects, isFalse);
        return http.Response(
          '<html>proxy error</html>',
          503,
          headers: {'x-request-id': 'trace-id'},
        );
      });
      addTearDown(client.close);
      final transport = HttpApiJsonTransport(
        baseUri: Uri.parse('https://api.example.test'),
        client: client,
        accessToken: 'secret',
      );
      await expectLater(
        transport.getJson('https://foreign.example.test/'),
        throwsArgumentError,
      );
      expect(calls, 0);
      await expectLater(
        transport.getJson('/v1/ibclc/me'),
        throwsA(
          isA<ApiHttpException>()
              .having((error) => error.statusCode, 'status', 503)
              .having((error) => error.requestId, 'request id', 'trace-id')
              .having((error) => error.body, 'body', isNull),
        ),
      );
    },
  );
}
