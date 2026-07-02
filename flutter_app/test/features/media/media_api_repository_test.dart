import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('MediaApiRepository', () {
    test('uploads owner-scoped file and maps production FileRead', () async {
      final transport = FixtureApiMultipartTransport({
        'id': 'file-001',
        'owner_user_id': 'user-001',
        'original_filename': 'pump-display-fixture.png',
        'content_type': 'image/png',
        'size_bytes': 68,
        'status': 'ready',
      });
      final repository = MediaApiRepository(transport: transport);

      final uploaded = await repository.uploadFile(
        userId: 'ignored-user-authority',
        idempotencyKey: ' upload-idem-001 ',
        file: _file,
      );

      expect(transport.lastPath, mediaUploadEndpoint);
      expect(transport.lastFields, isEmpty);
      expect(transport.lastHeaders, {'Idempotency-Key': 'upload-idem-001'});
      expect(transport.lastFile?.name, 'pump-display-fixture.png');
      expect(transport.lastFile?.mimeType, 'image/png');
      expect(transport.lastFile?.sizeBytes, 68);
      expect(uploaded.id, 'file-001');
      expect(uploaded.name, 'pump-display-fixture.png');
      expect(uploaded.sizeBytes, 68);
      expect(uploaded.extension, 'png');
      expect(uploaded.mimeType, 'image/png');
    });

    test('omits blank idempotency keys and maps empty partial data', () async {
      final transport = FixtureApiMultipartTransport({'id': 'file-001'});
      final uploaded = await MediaApiRepository(
        transport: transport,
      ).uploadFile(
        userId: 'ignored-user-authority',
        idempotencyKey: ' ',
        file: _file,
      );

      expect(transport.lastFields, isEmpty);
      expect(transport.lastHeaders, isEmpty);
      expect(uploaded.id, 'file-001');
      expect(uploaded.name, isEmpty);
      expect(uploaded.sizeBytes, 0);
      expect(uploaded.mimeType, isEmpty);
    });

    test(
      'keeps HTTP, cancel, and timeout failures distinct',
      () async {
        await expectLater(
          MediaApiRepository(
            transport: FixtureApiMultipartTransport({
              'http_status': 413,
              'status_text': 'Payload Too Large',
              'body': {
                'error': {
                  'code': 'payload_too_large',
                  'message': 'File is too large',
                  'request_id': 'req-file-001',
                },
              },
            }),
          ).uploadFile(userId: 'ignored-user-authority', file: _file),
          throwsA(
            isA<ApiHttpException>().having(
              (error) => error.errorCode,
              'errorCode',
              'payload_too_large',
            ),
          ),
        );
        await expectLater(
          MediaApiRepository(
            transport: _failureTransport(const ApiRequestCancelledException()),
          ).uploadFile(userId: 'ignored-user-authority', file: _file),
          throwsA(isA<ApiRequestCancelledException>()),
        );
        await expectLater(
          MediaApiRepository(
            transport: _failureTransport(const ApiRequestTimeoutException()),
          ).uploadFile(userId: 'ignored-user-authority', file: _file),
          throwsA(isA<ApiRequestTimeoutException>()),
        );
      },
    );
  });
}

const _file = ApiUploadFile(
  name: 'pump-display-fixture.png',
  mimeType: 'image/png',
  sizeBytes: 68,
);

FixtureApiMultipartTransport _failureTransport(Object failure) {
  return FixtureApiMultipartTransport(const {}, failure: failure);
}
