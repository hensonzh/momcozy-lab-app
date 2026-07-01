import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
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
  }) async {
    final response = await transport.uploadMultipart(
      mediaUploadEndpoint,
      fields: {'user_id': userId},
      file: file,
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    return UploadedMediaFile(
      id: _string(data['id'] ?? data['fileId']) ?? '',
      name: _string(data['name'] ?? data['fileName']) ?? '',
      sizeBytes: _int(data['size'] ?? data['fileSize']) ?? 0,
      extension: _string(data['extension'] ?? data['ext']) ?? '',
      mimeType: _string(data['mime_type'] ?? data['mimeType']) ?? '',
    );
  }
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;
