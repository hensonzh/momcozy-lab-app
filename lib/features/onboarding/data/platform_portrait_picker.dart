import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

enum OnboardingPortraitSource { camera, gallery }

class OnboardingPlatformPortraitPicker {
  OnboardingPlatformPortraitPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const _maxBytes = 10 * 1024 * 1024;
  final ImagePicker _picker;

  Future<OnboardingPortrait?> pick(OnboardingPortraitSource source) async {
    final file = await _picker.pickImage(
      source: source == OnboardingPortraitSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > _maxBytes) {
      throw const FormatException('Please choose an image smaller than 10 MB.');
    }
    final mimeType = _detectMimeType(bytes);
    if (mimeType == null) {
      throw const FormatException('Please choose a JPEG, PNG, or WebP image.');
    }
    return OnboardingPortrait(
      bytes: Uint8List.fromList(bytes),
      name: _safeName(file.name, mimeType),
      mimeType: mimeType,
    );
  }
}

String? _detectMimeType(List<int> bytes) {
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
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

String _safeName(String value, String mimeType) {
  final name = value.trim();
  if (name.isNotEmpty) return name;
  return mimeType == 'image/png'
      ? 'portrait.png'
      : mimeType == 'image/webp'
      ? 'portrait.webp'
      : 'portrait.jpg';
}
