import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/features/media/data/product_asset_repository.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/fake_video_player_platform.dart';
import '../../support/momcozy_test_fonts.dart';
import '../../support/test_pdf_fixture.dart';

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    _goldenImageBytes = await File('assets/images/M9.png').readAsBytes();
  });

  late VideoPlayerPlatform previousVideoPlatform;

  setUp(() {
    _installPathProviderMock();
    previousVideoPlatform = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  tearDown(() async {
    VideoPlayerPlatform.instance = previousVideoPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  group('Media Viewer state goldens', () {
    for (final viewport in _goldenViewports) {
      for (final state in _mediaStates) {
        testWidgets('${state.label} matches ${viewport.label} baseline', (
          tester,
        ) async {
          await _setViewport(tester, viewport.size);

          await tester.pumpWidget(
            RepaintBoundary(
              key: _goldenSurfaceKey,
              child: MomCozyFlutterApp(
                apiRuntime: MomCozyApiRuntime.fromEnvironment(
                  productAssetRepository: ProductAssetRepository(
                    baseUri: Uri.parse('https://api.example.test'),
                    connector: _GoldenProductAssetConnector(),
                  ),
                ),
                router: createMomCozyRouter(initialLocation: state.location),
              ),
            ),
          );
          await _pumpMediaState(tester, state);

          expect(
            find.byKey(const ValueKey('route-page-/media-viewer')),
            findsOneWidget,
          );
          expect(find.text(state.title), findsOneWidget);

          await expectLater(
            find.byKey(_goldenSurfaceKey),
            matchesGoldenFile(viewport.filePath(state.fileName)),
          );
        });
      }
    }
  });
}

Future<void> _pumpMediaState(
  WidgetTester tester,
  _MediaGoldenState state,
) async {
  for (var frame = 0; frame < 80; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    final routeReady = find
        .byKey(const ValueKey('route-page-/media-viewer'))
        .evaluate()
        .isNotEmpty;
    final mediaReady = switch (state.kind) {
      _MediaGoldenKind.image =>
        find.byKey(const ValueKey('product-asset-image')).evaluate().isNotEmpty,
      _MediaGoldenKind.pdf =>
        find.byKey(const ValueKey('media-pdf-viewer')).evaluate().isNotEmpty,
      _MediaGoldenKind.video =>
        find
            .byKey(const ValueKey('product-asset-video-player'))
            .evaluate()
            .isNotEmpty,
    };
    if (routeReady && mediaReady) {
      if (state.kind == _MediaGoldenKind.image ||
          state.kind == _MediaGoldenKind.video) {
        await tester.runAsync(
          () => Future<void>.delayed(
            state.kind == _MediaGoldenKind.image
                ? const Duration(milliseconds: 80)
                : Duration.zero,
          ),
        );
      }
      await tester.pump(const Duration(milliseconds: 32));
      return;
    }
    if (find
        .byKey(const ValueKey('media-viewer-load-error'))
        .evaluate()
        .isNotEmpty) {
      fail('Media viewer entered an error state.');
    }
  }
  fail('Media viewer did not reach a stable golden state.');
}

const _goldenSurfaceKey = ValueKey('media-viewer-state-golden-surface');
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
late Uint8List _goldenImageBytes;

const _mediaStates = [
  _MediaGoldenState(
    label: 'PDF resource',
    fileName: 'pdf_resource_mobile.png',
    location:
        '/media-viewer?kind=pdf&url=%2Fv1%2Fassets%2Fasset-pdf%3Fkind%3Dpdf&title=W1%20使用教程',
    title: 'W1 使用教程',
    kind: _MediaGoldenKind.pdf,
  ),
  _MediaGoldenState(
    label: 'image resource',
    fileName: 'image_resource_mobile.png',
    location:
        '/media-viewer?kind=image&url=%2Fv1%2Fassets%2Fasset-image%3Fkind%3Dimage&title=Air1%20核心部件',
    title: 'Air1 核心部件',
    kind: _MediaGoldenKind.image,
  ),
  _MediaGoldenState(
    label: 'video resource',
    fileName: 'video_resource_mobile.png',
    location:
        '/media-viewer?kind=video&url=%2Fv1%2Fassets%2Fasset-video%3Fkind%3Dvideo&title=W1%20视频教程',
    title: 'W1 视频教程',
    kind: _MediaGoldenKind.video,
  ),
];

enum _MediaGoldenKind { image, pdf, video }

class _MediaGoldenState {
  const _MediaGoldenState({
    required this.label,
    required this.fileName,
    required this.location,
    required this.title,
    required this.kind,
  });

  final String label;
  final String fileName;
  final String location;
  final String title;
  final _MediaGoldenKind kind;
}

class _GoldenProductAssetConnector implements ProductAssetHttpConnector {
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    if (headers['Accept']?.contains('application/pdf') ?? false) {
      return ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'application/pdf',
        body: buildTwoPageTestPdf(),
      );
    }
    return ProductAssetHttpResponse(
      statusCode: 200,
      statusText: 'OK',
      contentType: 'image/png',
      body: _goldenImageBytes,
    );
  }
}

void _installPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        return Directory.systemTemp.path;
      });
}

const _goldenViewports = [
  _GoldenViewport(
    label: 'narrow mobile 360x800',
    size: Size(360, 800),
    directory: 'narrow_360x800',
  ),
  _GoldenViewport(label: 'compact mobile', size: Size(390, 844)),
  _GoldenViewport(
    label: 'large mobile 430x932',
    size: Size(430, 932),
    directory: 'large_430x932',
  ),
];

class _GoldenViewport {
  const _GoldenViewport({
    required this.label,
    required this.size,
    this.directory,
  });

  final String label;
  final Size size;
  final String? directory;

  String filePath(String fileName) {
    final viewportDirectory = directory;
    if (viewportDirectory == null) {
      return '../../goldens/media_viewer_states/$fileName';
    }
    return '../../goldens/media_viewer_states/$viewportDirectory/$fileName';
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
