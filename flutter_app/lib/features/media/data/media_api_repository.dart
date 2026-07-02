import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';

const mediaUploadEndpoint = '/v1/files/upload';

class MediaApiRepository implements MediaRepository {
  const MediaApiRepository({required this.transport});

  final ApiMultipartTransport transport;

  @override
  Future<UploadedMediaFile> uploadFile({
    required String userId,
    required ApiUploadFile file,
    String? idempotencyKey,
  }) async {
    final normalizedIdempotencyKey = idempotencyKey?.trim();
    final response = await transport.uploadMultipart(
      mediaUploadEndpoint,
      headers: {
        if (normalizedIdempotencyKey != null &&
            normalizedIdempotencyKey.isNotEmpty)
          'Idempotency-Key': normalizedIdempotencyKey,
      },
      file: file,
    );
    return UploadedMediaFile(
      id: _string(response['id'] ?? response['fileId']) ?? '',
      name:
          _string(
            response['original_filename'] ??
                response['name'] ??
                response['fileName'],
          ) ??
          '',
      sizeBytes:
          _int(
            response['size_bytes'] ?? response['size'] ?? response['fileSize'],
          ) ??
          0,
      extension:
          _extension(
            _string(
                  response['original_filename'] ??
                      response['name'] ??
                      response['fileName'],
                ) ??
                '',
          ) ??
          '',
      mimeType:
          _string(
            response['content_type'] ??
                response['mime_type'] ??
                response['mimeType'],
          ) ??
          '',
    );
  }
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

String? _extension(String filename) {
  final index = filename.lastIndexOf('.');
  if (index <= 0 || index == filename.length - 1) return null;
  return filename.substring(index + 1).toLowerCase();
}
