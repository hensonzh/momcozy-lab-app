import 'dart:convert';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/core/agent_stream/agent_stream_client.dart';
import 'package:app/features/agent_hub/domain/agent_image_input.dart';
import 'package:app/features/media/domain/media_upload.dart';

class AgentHubPlatformImagePicker {
  AgentHubPlatformImagePicker({ImagePicker? picker, this.uploadRepository})
    : _picker = picker ?? ImagePicker();

  static const double _maxSide = 2048;
  static const int _imageQuality = 86;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final ImagePicker _picker;
  final MediaRepository? uploadRepository;

  Future<AgentStreamImageInput?> pick(AgentImageInputSource source) async {
    final recovered = await _recoverLostImage();
    final file =
        recovered ??
        await _picker.pickImage(
          source: source == AgentImageInputSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: _maxSide,
          maxHeight: _maxSide,
          imageQuality: _imageQuality,
          preferredCameraDevice: CameraDevice.rear,
          requestFullMetadata: false,
        );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    if (bytes.length > _maxImageBytes) {
      throw const AgentImageInputException('Selected image is too large.');
    }

    final mimeType = _imageMimeType(file, bytes);
    if (mimeType == null) {
      throw const AgentImageInputException('Selected file is not an image.');
    }
    final name = _imageName(file.name, mimeType);
    final assetId = await _uploadImage(
      bytes: bytes,
      mimeType: mimeType,
      name: name,
    );
    return AgentStreamImageInput(
      assetId: assetId,
      dataUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
      mimeType: mimeType,
      name: name,
      size: bytes.length,
      detail: 'auto',
    );
  }

  Future<String> _uploadImage({
    required List<int> bytes,
    required String mimeType,
    required String name,
  }) async {
    final repository = uploadRepository;
    if (repository == null) return '';
    final uploaded = await repository.uploadFile(
      file: ApiUploadFile(
        name: name,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        bytes: bytes,
      ),
      idempotencyKey: _newImageUploadIdempotencyKey(),
    );
    final assetId = uploaded.id.trim();
    if (assetId.isEmpty) {
      throw const AgentImageInputException('Image upload result is invalid.');
    }
    return assetId;
  }

  String _newImageUploadIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'agent-image-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  Future<XFile?> _recoverLostImage() async {
    LostDataResponse response;
    try {
      response = await _picker.retrieveLostData();
    } on UnimplementedError {
      return null;
    }
    if (response.isEmpty) return null;
    if (response.exception != null) throw response.exception!;
    final files = response.files;
    if (files != null && files.isNotEmpty) return files.first;
    return response.file;
  }
}

class AgentImageInputException implements Exception {
  const AgentImageInputException(this.message);

  final String message;

  @override
  String toString() => 'AgentImageInputException($message)';
}

String? _imageMimeType(XFile file, List<int> bytes) {
  final detected = _imageMimeTypeFromBytes(bytes);
  if (detected != null) return detected;

  final explicit = file.mimeType?.trim().toLowerCase();
  if (_supportedImageMimeTypes.contains(explicit)) return explicit;

  return _imageMimeTypeFromName(file.name);
}

const _supportedImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
};

String? _imageMimeTypeFromBytes(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return 'image/png';
  }
  if (bytes.length >= 6) {
    final signature = String.fromCharCodes(bytes.take(6));
    if (signature == 'GIF87a' || signature == 'GIF89a') {
      return 'image/gif';
    }
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

String? _imageMimeTypeFromName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.webp')) return 'image/webp';
  if (normalized.endsWith('.gif')) return 'image/gif';
  return null;
}

String _imageName(String rawName, String mimeType) {
  final name = rawName.trim();
  if (name.isNotEmpty && _imageMimeTypeFromName(name) == mimeType) {
    return name;
  }
  return _defaultName(mimeType);
}

String _defaultName(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' => 'photo.jpg',
    'image/webp' => 'photo.webp',
    'image/gif' => 'photo.gif',
    _ => 'photo.png',
  };
}
