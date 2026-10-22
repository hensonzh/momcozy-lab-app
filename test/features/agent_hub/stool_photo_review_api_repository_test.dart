import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/stool_photo_review_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_photo_review.dart';

void main() {
  test(
    'dedicated original upload, owner-scoped review, and delete do not use chat files',
    () async {
      final transport = _Transport();
      final repository = StoolPhotoReviewApiRepository(
        uploadTransport: transport,
        readTransport: transport,
        deleteTransport: transport,
      );
      expect(await repository.isReviewAvailable(), isFalse);
      final original = Uint8List.fromList([1, 2, 3]);
      final uploaded = await repository.uploadOriginal(
        bytes: original,
        name: 'original.heic',
        mimeType: 'image/heic',
        idempotencyKey: 'per-photo-key',
      );
      expect(uploaded.photoId, 'photo-1');
      expect(uploaded.status, StoolPhotoReviewStatus.pending);
      expect(transport.uploadPath, '/v1/stool-photos');
      expect(transport.file?.bytes, original);
      expect(transport.headers, {'Idempotency-Key': 'per-photo-key'});
      expect(
        (await repository.getReview(uploaded.photoId)).status,
        StoolPhotoReviewStatus.rejected,
      );
      expect(transport.getPath, '/v1/stool-photos/photo-1/review');
      await repository.deletePhoto(uploaded.photoId);
      expect(transport.deletePath, '/v1/stool-photos/photo-1');
    },
  );

  test(
    'capture readiness is server-owned, not inferred from upload route',
    () async {
      final transport = _Transport()..captureAvailable = true;
      final repository = StoolPhotoReviewApiRepository(
        uploadTransport: transport,
        readTransport: transport,
        deleteTransport: transport,
      );
      expect(await repository.isReviewAvailable(), isTrue);
      expect(transport.getPath, '/v1/stool-photos/capability');
    },
  );

  test('expired or malformed approval never appears approved', () async {
    final transport = _Transport()..approvedResponse = true;
    final repository = StoolPhotoReviewApiRepository(
      uploadTransport: transport,
      readTransport: transport,
      deleteTransport: transport,
    );
    expect((await repository.getReview('photo-1')).isApproved, isFalse);
    transport.expiry = 'not-a-date';
    expect((await repository.getReview('photo-1')).isApproved, isFalse);
  });

  test('malformed or unknown review states fail closed', () async {
    final transport = _Transport()..invalidResponse = true;
    final repository = StoolPhotoReviewApiRepository(
      uploadTransport: transport,
      readTransport: transport,
      deleteTransport: transport,
    );
    expect(() => repository.getReview('photo-1'), throwsFormatException);
  });
}

class _Transport
    implements
        ApiMultipartTransport,
        ApiJsonTransport,
        ApiJsonMutationTransport {
  String? uploadPath;
  String? getPath;
  String? deletePath;
  Map<String, String>? headers;
  ApiUploadFile? file;
  bool invalidResponse = false;
  bool approvedResponse = false;
  bool captureAvailable = false;
  String expiry = '2020-01-01T00:00:00Z';

  @override
  Future<Map<String, Object?>> uploadMultipart(
    String path, {
    Map<String, Object?> query = const {},
    Map<String, Object?> fields = const {},
    Map<String, String> headers = const {},
    required ApiUploadFile file,
  }) async {
    uploadPath = path;
    this.headers = headers;
    this.file = file;
    return {
      'photo_id': 'photo-1',
      'review_status': 'pending',
      'reason_codes': [],
    };
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getPath = path;
    if (path.endsWith('/capability')) {
      return {
        'review_available': captureAvailable,
        'analysis_available': false,
      };
    }
    return {
      'photo_id': 'photo-1',
      'review_status': invalidResponse
          ? 'unknown'
          : (approvedResponse ? 'passed' : 'rejected'),
      if (approvedResponse) 'review_expires_at': expiry,
      'reason_codes': ['not_stool'],
    };
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    deletePath = path;
    return {};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
