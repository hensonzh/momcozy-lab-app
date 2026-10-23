import 'dart:typed_data';

/// Review is photo suitability only; it must not carry a medical risk result.
enum StoolPhotoReviewStatus {
  uploading,
  pending,
  reviewing,
  passed,
  rejected,
  inconclusive,
  failed,
}

class StoolPhotoReview {
  const StoolPhotoReview({
    required this.photoId,
    required this.status,
    this.reasonCodes = const [],
  });

  final String photoId;
  final StoolPhotoReviewStatus status;
  final List<String> reasonCodes;

  bool get isWaiting =>
      status == StoolPhotoReviewStatus.pending ||
      status == StoolPhotoReviewStatus.reviewing;
  bool get isApproved => status == StoolPhotoReviewStatus.passed;
}

abstract interface class StoolPhotoReviewRepository {
  Future<bool> isReviewAvailable();

  Future<StoolPhotoReview> uploadOriginal({
    required Uint8List bytes,
    required String name,
    required String mimeType,
    required String idempotencyKey,
  });

  Future<StoolPhotoReview> getReview(String photoId);
  Future<void> deletePhoto(String photoId);
}

String stoolPhotoReviewLabel(StoolPhotoReviewStatus status) => switch (status) {
  StoolPhotoReviewStatus.uploading => '正在上传照片…',
  StoolPhotoReviewStatus.pending ||
  StoolPhotoReviewStatus.reviewing => '正在审核照片…',
  StoolPhotoReviewStatus.passed => '照片审核通过',
  StoolPhotoReviewStatus.rejected => '照片未通过审核，请删除后重新拍摄',
  StoolPhotoReviewStatus.inconclusive => '照片无法确认，请删除后重新拍摄',
  StoolPhotoReviewStatus.failed => '照片审核失败，请删除后重试',
};

String? stoolPhotoReviewReason(List<String> codes) {
  if (codes.isEmpty) return null;
  return switch (codes.first) {
    'not_stool' => '未拍到可识别的便便',
    'color_unreadable' ||
    'shape_unreadable' ||
    'color_shape_unclear' => '颜色或形态不够清晰',
    'bad_lighting' || 'lighting_abnormal' => '光线或色偏影响识别',
    'face_visible' ||
    'private_parts_visible' ||
    'other_sensitive_content' ||
    'sensitive_info_visible' => '照片含不必要的敏感内容',
    'policy_not_calibrated' || 'review_unavailable' => '审核暂不可用',
    'review_expired' => '审核已过期，请重新上传',
    _ => '请重新选择清晰、仅包含便便的照片',
  };
}
