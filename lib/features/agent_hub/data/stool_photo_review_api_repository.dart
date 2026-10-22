import 'dart:typed_data';

import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/stool_photo_review.dart';

const stoolPhotoUploadEndpoint = '/v1/stool-photos';

class StoolPhotoReviewApiRepository implements StoolPhotoReviewRepository {
  const StoolPhotoReviewApiRepository({
    required this.uploadTransport,
    required this.readTransport,
    required this.deleteTransport,
  });

  final ApiMultipartTransport uploadTransport;
  final ApiJsonTransport readTransport;
  final ApiJsonMutationTransport deleteTransport;

  @override
  Future<bool> isReviewAvailable() async {
    final response = await readTransport.getJson(
      '$stoolPhotoUploadEndpoint/capability',
    );
    return response['review_available'] == true;
  }

  @override
  Future<StoolPhotoReview> uploadOriginal({
    required Uint8List bytes,
    required String name,
    required String mimeType,
    required String idempotencyKey,
  }) async => _parseReview(
    await uploadTransport.uploadMultipart(
      stoolPhotoUploadEndpoint,
      headers: {'Idempotency-Key': idempotencyKey},
      file: ApiUploadFile(
        name: name,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        bytes: bytes,
      ),
    ),
  );

  @override
  Future<StoolPhotoReview> getReview(String photoId) async => _parseReview(
    await readTransport.getJson(
      '$stoolPhotoUploadEndpoint/${Uri.encodeComponent(photoId)}/review',
    ),
  );

  @override
  Future<void> deletePhoto(String photoId) async {
    await deleteTransport.deleteJson(
      '$stoolPhotoUploadEndpoint/${Uri.encodeComponent(photoId)}',
    );
  }
}

StoolPhotoReview _parseReview(Map<String, Object?> value) {
  final id = value['photo_id'];
  final rawStatus = value['review_status'];
  final status = StoolPhotoReviewStatus.values.where(
    (item) =>
        item.name == rawStatus && item != StoolPhotoReviewStatus.uploading,
  );
  if (id is! String || id.isEmpty || status.length != 1) {
    throw const FormatException('Invalid stool photo review response.');
  }
  final reasons = value['reason_codes'];
  if (reasons is! List || reasons.any((item) => item is! String)) {
    throw const FormatException('Invalid stool photo review reasons.');
  }
  if (status.single == StoolPhotoReviewStatus.passed) {
    final expires = value['review_expires_at'];
    final deadline = expires is String ? DateTime.tryParse(expires) : null;
    if (deadline == null || !deadline.isAfter(DateTime.now().toUtc())) {
      return StoolPhotoReview(
        photoId: id,
        status: StoolPhotoReviewStatus.failed,
        reasonCodes: const ['review_expired'],
      );
    }
  }
  return StoolPhotoReview(
    photoId: id,
    status: status.single,
    reasonCodes: reasons.cast<String>(),
  );
}
