import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

  test(
    'stool picker requests unscaled original and checks decoded short edge',
    () async {
      final original = Uint8List.fromList(
        img.encodePng(img.Image(width: 720, height: 800)),
      );
      platform.file = XFile.fromData(
        original,
        mimeType: 'image/png',
        name: 'original.png',
      );
      final picked = await AgentHubPlatformImagePicker().pickStoolOriginal(
        AgentImageInputSource.gallery,
      );
      expect(platform.options.single.maxWidth, isNull);
      expect(platform.options.single.maxHeight, isNull);
      expect(platform.options.single.imageQuality, isNull);
      expect(picked?.localBytes, original);
      expect(picked?.mimeType, 'image/png');
    },
  );

  test(
    'stool picker discards unknown Android lost data and picks a new original',
    () async {
      final ordinaryChatRecovery = Uint8List.fromList(
        img.encodePng(img.Image(width: 720, height: 900)),
      );
      final newOriginal = Uint8List.fromList(
        img.encodePng(img.Image(width: 820, height: 900)),
      );
      platform.lostData = LostDataResponse(
        file: XFile.fromData(ordinaryChatRecovery, name: 'scaled-chat.png'),
        type: RetrieveType.image,
      );
      platform.file = XFile.fromData(newOriginal, name: 'fresh-original.png');

      final picked = await AgentHubPlatformImagePicker().pickStoolOriginal(
        AgentImageInputSource.gallery,
      );

      expect(platform.sources, [ImageSource.gallery]);
      expect(platform.options.single.maxWidth, isNull);
      expect(platform.options.single.imageQuality, isNull);
      expect(picked?.localBytes, newOriginal);
      expect(picked?.localBytes, isNot(ordinaryChatRecovery));
    },
  );

  test('stool picker rejects undersized and non-PRD formats', () async {
    platform.file = XFile.fromData(
      Uint8List.fromList(img.encodePng(img.Image(width: 719, height: 900))),
      name: 'tiny.png',
      mimeType: 'image/png',
    );
    await expectLater(
      AgentHubPlatformImagePicker().pickStoolOriginal(
        AgentImageInputSource.gallery,
      ),
      throwsA(isA<AgentImageInputException>()),
    );
    platform.file = XFile.fromData(
      Uint8List.fromList(img.encodeGif(img.Image(width: 720, height: 900))),
      name: 'wrong.gif',
      mimeType: 'image/gif',
    );
    await expectLater(
      AgentHubPlatformImagePicker().pickStoolOriginal(
        AgentImageInputSource.gallery,
      ),
      throwsA(isA<AgentImageInputException>()),
    );
  });

  test(
    'HEIC original remains untouched when platform preview codec cannot inspect it',
    () async {
      platform.file = XFile.fromData(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          0x66,
          0x74,
          0x79,
          0x70,
          0x68,
          0x65,
          0x69,
          0x63,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]),
        mimeType: 'image/heic',
        name: 'original.heic',
      );
      final picked = await AgentHubPlatformImagePicker().pickStoolOriginal(
        AgentImageInputSource.gallery,
      );
      expect(picked?.mimeType, 'image/heic');
      expect(picked?.name, 'photo.heic');
      expect(
        picked?.localBytes,
        platform.file == null ? null : await platform.file!.readAsBytes(),
      );
      // The Product API remains authoritative for decoded HEIC size and validity.
    },
  );

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
