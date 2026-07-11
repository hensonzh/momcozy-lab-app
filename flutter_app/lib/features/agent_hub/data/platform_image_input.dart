import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';

class AgentHubPlatformImagePicker {
  AgentHubPlatformImagePicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const double _maxSide = 2048;
  static const int _imageQuality = 86;
  static const int _maxImageBytes = 10 * 1024 * 1024;

  final ImagePicker _picker;

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

    final mimeType = _imageMimeType(file);
    if (!mimeType.startsWith('image/')) {
      throw const AgentImageInputException('Selected file is not an image.');
    }
    final name = file.name.trim().isEmpty ? _defaultName(mimeType) : file.name;
    return AgentStreamImageInput(
      dataUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
      mimeType: mimeType,
      name: name,
      size: bytes.length,
      detail: 'auto',
    );
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

String _imageMimeType(XFile file) {
  final explicit = file.mimeType?.trim().toLowerCase();
  if (explicit != null && explicit.startsWith('image/')) return explicit;

  final name = file.name.toLowerCase();
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  if (name.endsWith('.gif')) return 'image/gif';
  return 'image/png';
}

String _defaultName(String mimeType) {
  return switch (mimeType) {
    'image/jpeg' => 'photo.jpg',
    'image/webp' => 'photo.webp',
    'image/heic' => 'photo.heic',
    'image/gif' => 'photo.gif',
    _ => 'photo.png',
  };
}
