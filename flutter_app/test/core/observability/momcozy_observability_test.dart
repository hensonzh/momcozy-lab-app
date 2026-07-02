import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/observability/momcozy_observability.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MomCozyObservability', () {
    test('records redacted route, feature, agent, and non-fatal events', () {
      final sink = MemoryMomCozyTelemetrySink();
      final observability = MomCozyObservability(
        sink: sink,
        now: () => DateTime.utc(2026, 7, 2, 10),
      );

      observability.recordRouteView('/pump?token=secret');
      observability.recordFeatureEvent(
        'pump-session',
        'finish',
        attributes: const {'user_id': 'demo-user', 'milkMl': 120},
      );
      observability.recordAgentStreamLifecycle(
        'reconnect',
        transport: 'sse',
        attributes: const {'threadId': 'thread-secret', 'elapsedMs': 42},
      );
      observability.recordNonFatal(
        StateError('failed Bearer secret-token'),
        context: const {'route': '/pump', 'message': 'private health note'},
      );

      expect(sink.events.map((event) => event.name), [
        'route.view',
        'feature.event',
        'agent.stream.reconnect',
        'app.non_fatal',
      ]);
      expect(sink.events[0].attributes, {'route': '/pump', 'source': 'router'});
      expect(sink.events[1].attributes, {
        'feature': 'pump-session',
        'action': 'finish',
        'user_id': '***',
        'milkMl': 120,
      });
      expect(sink.events[2].attributes, {
        'transport': 'sse',
        'threadId': '***',
        'elapsedMs': 42,
      });
      expect(sink.events[3].attributes.toString(), isNot(contains('secret')));
      expect(
        sink.events[3].attributes.toString(),
        isNot(contains('private health note')),
      );
      expect(
        sink.events.every((event) => event.timestamp.year == 2026),
        isTrue,
      );
    });

    test('observed JSON transport records success and HTTP failure', () async {
      final sink = MemoryMomCozyTelemetrySink();
      final observability = MomCozyObservability(sink: sink);
      final successTransport = ObservedApiJsonTransport(
        inner: FixtureApiJsonTransport(const {
          'status': 200,
          'data': {'ok': true},
        }),
        observability: observability,
      );
      final failureTransport = ObservedApiJsonTransport(
        inner: FixtureApiJsonTransport(const {
          'http_status': 503,
          'status_text': 'Unavailable',
          'request_id': 'req-503',
          'body': {'message': 'down'},
        }),
        observability: observability,
      );

      await successTransport.getJson(
        '/v1/profile/me?token=secret',
      );
      await expectLater(
        failureTransport.postJson('/v1/devices/pump-telemetry'),
        throwsA(isA<ApiHttpException>()),
      );

      expect(sink.events.map((event) => event.name), [
        'api.request',
        'api.request',
      ]);
      expect(sink.events[0].attributes, {
        'method': 'GET',
        'path': '/v1/profile/me',
        'elapsedMs': sink.events[0].attributes['elapsedMs'],
        'statusCode': 200,
        'retryable': false,
      });
      expect(sink.events[0].attributes, containsPair('elapsedMs', isA<int>()));
      expect(sink.events[1].attributes, {
        'method': 'POST',
        'path': '/v1/devices/pump-telemetry',
        'elapsedMs': sink.events[1].attributes['elapsedMs'],
        'statusCode': 503,
        'errorType': 'ApiHttpException',
        'retryable': false,
      });
      expect(sink.events[1].attributes, containsPair('elapsedMs', isA<int>()));
    });

    test(
      'observed multipart transport records upload without file metadata',
      () async {
        final sink = MemoryMomCozyTelemetrySink();
        final observability = MomCozyObservability(sink: sink);
        final transport = ObservedApiMultipartTransport(
          inner: FixtureApiMultipartTransport(const {
            'status': 200,
            'data': {'id': 'file-001'},
          }),
          observability: observability,
        );

        await transport.uploadMultipart(
          '/v1/files/upload',
          fields: const {'user_id': 'demo-user'},
          file: const ApiUploadFile(
            name: 'private-image.png',
            mimeType: 'image/png',
            sizeBytes: 4,
          ),
        );

        expect(sink.events.single.name, 'api.request');
        expect(sink.events.single.attributes, {
          'method': 'MULTIPART',
          'path': '/v1/files/upload',
          'elapsedMs': sink.events.single.attributes['elapsedMs'],
          'statusCode': 200,
          'retryable': false,
        });
        expect(
          sink.events.single.attributes,
          containsPair('elapsedMs', isA<int>()),
        );
        expect(
          sink.events.single.attributes.toString(),
          isNot(contains('demo-user')),
        );
        expect(
          sink.events.single.attributes.toString(),
          isNot(contains('private-image')),
        );
      },
    );
  });
}
