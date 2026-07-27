import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/platform_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';

void main() {
  late ImagePickerPlatform originalPlatform;
  late _FakeImagePickerPlatform platform;

  setUp(() {
    originalPlatform = ImagePickerPlatform.instance;
    platform = _FakeImagePickerPlatform();
    ImagePickerPlatform.instance = platform;
  });

  tearDown(() {
    ImagePickerPlatform.instance = originalPlatform;
  });

  test('maps camera and gallery sources into bounded image payloads', () async {
    final picker = AgentHubPlatformImagePicker();

    final camera = await picker.pick(AgentImageInputSource.camera);
    final gallery = await picker.pick(AgentImageInputSource.gallery);

    expect(platform.sources, [ImageSource.camera, ImageSource.gallery]);
    expect(platform.options.first.maxWidth, 2048);
    expect(platform.options.first.maxHeight, 2048);
    expect(platform.options.first.imageQuality, 86);
    expect(platform.options.first.requestFullMetadata, isFalse);
    expect(camera?.mimeType, 'image/jpeg');
    expect(camera?.name, 'photo.jpg');
    expect(camera?.size, 4);
    expect(camera?.dataUrl, isEmpty);
    expect(camera?.localBytes, [1, 2, 3, 4]);
    expect(gallery?.localBytes, camera?.localBytes);
  });

  test('restores Android lost image before opening another picker', () async {
    platform.lostData = LostDataResponse(
      file: XFile.fromData(
        Uint8List.fromList(const [7, 8]),
        mimeType: 'image/png',
        name: 'recovered.png',
      ),
      type: RetrieveType.image,
    );

    final image = await AgentHubPlatformImagePicker().pick(
      AgentImageInputSource.gallery,
    );

    expect(platform.sources, isEmpty);
    expect(image?.name, 'photo.png');
    expect(image?.dataUrl, isEmpty);
    expect(image?.localBytes, [7, 8]);
  });

  test('uses JPEG magic bytes when Android keeps a HEIC filename', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xe0]),
      mimeType: 'image/heic',
      name: 'scaled-photo.heic',
    );

    final image = await AgentHubPlatformImagePicker().pick(
      AgentImageInputSource.gallery,
    );

    expect(image?.mimeType, 'image/jpeg');
    expect(image?.name, 'photo.jpg');
    expect(image?.dataUrl, isEmpty);
    expect(image?.localBytes, [0xff, 0xd8, 0xff, 0xe0]);
  });
}

class _FakeImagePickerPlatform extends ImagePickerPlatform {
  LostDataResponse lostData = LostDataResponse.empty();
  XFile? file;
  final List<ImageSource> sources = <ImageSource>[];
  final List<ImagePickerOptions> options = <ImagePickerOptions>[];

  @override
  Future<LostDataResponse> getLostData() async {
    final response = lostData;
    lostData = LostDataResponse.empty();
    return response;
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    sources.add(source);
    this.options.add(options);
    return file ??
        XFile.fromData(
          Uint8List.fromList(const [1, 2, 3, 4]),
          mimeType: 'image/jpeg',
          name: 'picked.jpg',
        );
  }
}
