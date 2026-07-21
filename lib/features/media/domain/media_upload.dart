import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';

abstract interface class MediaRepository {
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
    bool temporary = false,
  });

  Future<void> deleteFile({required String fileId, String? idempotencyKey});
}

class UploadedMediaFile {
  const UploadedMediaFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.extension,
    required this.mimeType,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String extension;
  final String mimeType;

  bool get isEmpty =>
      id.isEmpty && name.isEmpty && sizeBytes == 0 && mimeType.isEmpty;
}
