import 'dart:typed_data';
import 'dart:ui' as ui;

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

    final mimeType = _imageMimeType(file, bytes);
    if (mimeType == null) {
      throw const AgentImageInputException('Selected file is not an image.');
    }
    final name = _imageName(file.name, mimeType);
    return AgentStreamImageInput(
      dataUrl: '',
      mimeType: mimeType,
      name: name,
      size: bytes.length,
      detail: 'auto',
      localBytes: Uint8List.fromList(bytes),
      openRead: file.openRead,
    );
  }

  /// The stool admission path must not resize or recompress before the server
  /// validates the original bytes. Ordinary chat images keep their own path.
  Future<AgentStreamImageInput?> pickStoolOriginal(
    AgentImageInputSource source,
  ) async {
    // Android lost picker data does not identify whether the previous request
    // came from the resized chat picker or this unscaled stool picker. Consume
    // it but never promote it to a stool original; require a fresh selection.
    try {
      await _recoverLostImage();
    } catch (_) {
      // An unknown prior picker error is not evidence of a stool original.
    }
    final file = await _picker.pickImage(
      source: source == AgentImageInputSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > _maxImageBytes) {
      throw const AgentImageInputException('原图不能超过 10 MB。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxImageBytes) {
      throw const AgentImageInputException('原图不能超过 10 MB。');
    }
    final mimeType = _stoolMimeType(bytes);
    if (mimeType == null) {
      throw const AgentImageInputException('仅支持 JPG、JPEG、PNG、HEIC 原图。');
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width < 720 || descriptor.height < 720) {
        throw const AgentImageInputException('照片短边不能低于 720 像素。');
      }
    } on AgentImageInputException {
      rethrow;
    } catch (_) {
      // Some platform codecs cannot inspect HEIC. The dedicated Product API
      // still decodes and enforces 720 px before storing the original.
      if (mimeType != 'image/heic') {
        throw const AgentImageInputException('无法读取照片分辨率，请重新选择。');
      }
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
    return AgentStreamImageInput(
      dataUrl: '',
      mimeType: mimeType,
      name:
          mimeType == 'image/heic' && file.name.toLowerCase().endsWith('.heic')
          ? file.name
          : _imageName(file.name, mimeType),
      size: bytes.length,
      localBytes: Uint8List.fromList(bytes),
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
    'image/heic' => 'photo.heic',
    'image/webp' => 'photo.webp',
    'image/gif' => 'photo.gif',
    _ => 'photo.png',
  };
}

String? _stoolMimeType(List<int> bytes) {
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
  if (bytes.length >= 16 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
      const {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'heim',
        'heis',
      }.contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return 'image/heic';
  }
  return null;
}
