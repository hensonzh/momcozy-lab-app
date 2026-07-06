import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

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
                router: createMomCozyRouter(initialLocation: state.location),
              ),
            ),
          );
          await tester.pumpAndSettle();

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

const _goldenSurfaceKey = ValueKey('media-viewer-state-golden-surface');

const _mediaStates = [
  _MediaGoldenState(
    label: 'PDF resource',
    fileName: 'pdf_resource_mobile.png',
    location: '/media-viewer?kind=pdf&url=%2Fdemo%2Fw1.pdf&title=W1%20使用教程',
    title: 'W1 使用教程',
  ),
  _MediaGoldenState(
    label: 'image resource',
    fileName: 'image_resource_mobile.png',
    location:
        '/media-viewer?kind=image&url=%2Fdemo%2Fpump-display.png&title=泵奶记录截图',
    title: '泵奶记录截图',
  ),
  _MediaGoldenState(
    label: 'video resource',
    fileName: 'video_resource_mobile.png',
    location:
        '/media-viewer?kind=video&url=%2Fdemo%2Fw1-guide.mp4&title=W1%20视频教程',
    title: 'W1 视频教程',
  ),
];

class _MediaGoldenState {
  const _MediaGoldenState({
    required this.label,
    required this.fileName,
    required this.location,
    required this.title,
  });

  final String label;
  final String fileName;
  final String location;
  final String title;
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
