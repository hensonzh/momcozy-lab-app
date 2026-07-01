import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('MediaApiRepository', () {
    test('uploads file metadata and maps success contract', () async {
      final transport = _transport('success');
      final repository = MediaApiRepository(transport: transport);

      final uploaded = await repository.uploadFile(
        userId: 'demo-user-fixture',
        file: _file,
      );

      expect(transport.lastPath, mediaUploadEndpoint);
      expect(transport.lastFields, {'user_id': 'demo-user-fixture'});
      expect(transport.lastFile?.name, 'pump-display-fixture.png');
      expect(transport.lastFile?.mimeType, 'image/png');
      expect(transport.lastFile?.sizeBytes, 68);
      expect(uploaded.id, 'file-001');
      expect(uploaded.name, 'pump-display-fixture.png');
      expect(uploaded.sizeBytes, 68);
      expect(uploaded.extension, 'png');
      expect(uploaded.mimeType, 'image/png');
    });

    test('accepts aliases and partial empty data', () async {
      final legacy = await MediaApiRepository(
        transport: _transport('legacy_alias'),
      ).uploadFile(userId: 'demo-user-fixture', file: _file);
      final partial = await MediaApiRepository(
        transport: _transport('partial'),
      ).uploadFile(userId: 'demo-user-fixture', file: _file);
      final empty = await MediaApiRepository(
        transport: _transport('empty'),
      ).uploadFile(userId: 'demo-user-fixture', file: _file);

      expect(legacy.id, 'file-001');
      expect(legacy.mimeType, 'image/png');
      expect(partial.id, 'file-001');
      expect(partial.sizeBytes, 0);
      expect(empty.isEmpty, isTrue);
    });

    test(
      'keeps business, HTTP, cancel, and timeout failures distinct',
      () async {
        await expectLater(
          MediaApiRepository(
            transport: _transport('business_error'),
          ).uploadFile(userId: 'demo-user-fixture', file: _file),
          throwsA(isA<ApiBusinessException>()),
        );
        await expectLater(
          MediaApiRepository(
            transport: _transport('http_error'),
          ).uploadFile(userId: 'demo-user-fixture', file: _file),
          throwsA(isA<ApiHttpException>()),
        );
        await expectLater(
          MediaApiRepository(
            transport: _failureTransport(const ApiRequestCancelledException()),
          ).uploadFile(userId: 'demo-user-fixture', file: _file),
          throwsA(isA<ApiRequestCancelledException>()),
        );
        await expectLater(
          MediaApiRepository(
            transport: _failureTransport(const ApiRequestTimeoutException()),
          ).uploadFile(userId: 'demo-user-fixture', file: _file),
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

FixtureApiMultipartTransport _transport(String variant) {
  final fixture = readFixtureMap('api/media/$variant.json');
  return FixtureApiMultipartTransport(
    Map<String, Object?>.from(fixture['response']! as Map),
  );
}

FixtureApiMultipartTransport _failureTransport(Object failure) {
  return FixtureApiMultipartTransport(const {}, failure: failure);
}
