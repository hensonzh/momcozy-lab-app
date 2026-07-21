import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';

const mediaUploadEndpoint = '/v1/files/upload';

class MediaApiRepository implements MediaRepository {
  const MediaApiRepository({required this.transport, this.mutationTransport});

  final ApiMultipartTransport transport;
  final ApiJsonMutationTransport? mutationTransport;

  @override
  Future<UploadedMediaFile> uploadFile({
    required ApiUploadFile file,
    String? idempotencyKey,
    bool temporary = false,
  }) async {
    final normalizedIdempotencyKey = idempotencyKey?.trim();
    final response = await transport.uploadMultipart(
      mediaUploadEndpoint,
      query: {if (temporary) 'temporary': true},
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

  @override
  Future<void> deleteFile({
    required String fileId,
    String? idempotencyKey,
  }) async {
    final normalizedFileId = fileId.trim();
    if (normalizedFileId.isEmpty) return;
    final transport = mutationTransport;
    if (transport == null) {
      throw StateError('Media delete transport is not configured.');
    }
    final normalizedIdempotencyKey = idempotencyKey?.trim();
    await transport.deleteJson(
      '/v1/files/${Uri.encodeComponent(normalizedFileId)}',
      headers: {
        if (normalizedIdempotencyKey != null &&
            normalizedIdempotencyKey.isNotEmpty)
          'Idempotency-Key': normalizedIdempotencyKey,
      },
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
