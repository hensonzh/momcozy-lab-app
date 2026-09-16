import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/test_pdf_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders and navigates a two-page authenticated PDF',
    (tester) async {
      final connector = _PdfAssetConnector();
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        connector: connector,
        tokenProvider: () => 'integration-pdf-token',
      );
      final runtime = MomCozyApiRuntime(
        jsonTransport: const _NoopJsonTransport(),
        productAssetRepository: repository,
        userId: 'integration-user',
        babyId: 'integration-baby',
        locale: 'zh-CN',
      );
      final location = Uri(
        path: '/media-viewer',
        queryParameters: const {
          'kind': 'pdf',
          'url': '/v1/assets/asset-pdf?kind=pdf',
          'title': '两页 PDF 验收',
        },
      ).toString();

      await tester.pumpWidget(
        MomCozyFlutterApp(
          apiRuntime: runtime,
          router: createMomCozyRouter(
            initialLocation: location,
            agentHubBuilder: (_, _, _, _) =>
                const Center(child: Text('媒体返回目标')),
          ),
        ),
      );
      final viewer = await _waitForReadyPdf(tester);
      await tester.pumpAndSettle();

      expect(viewer.controller!.pageCount, 2);
      expect(connector.authorization, 'Bearer integration-pdf-token');
      expect(find.text('第 1 / 2 页'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump(const Duration(milliseconds: 500));
      await _captureDocument(binding, 'native-media-pdf-page-1');
      await _captureLongDocument(tester, binding, viewer.controller!);
      await tester.tap(find.byTooltip('下一页'));
      await tester.pumpAndSettle();
      expect(viewer.controller!.pageNumber, 2);
      expect(find.text('第 2 / 2 页'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await _captureDocument(binding, 'native-media-pdf-page-2');
      final zoom = viewer.controller!.currentZoom;
      await tester.tap(find.byTooltip('放大文档'));
      await tester.pumpAndSettle();
      expect(viewer.controller!.currentZoom, greaterThan(zoom));
      await _captureDocument(binding, 'native-media-pdf-zoomed');
      await _captureLongDocument(
        tester,
        binding,
        viewer.controller!,
        name: 'native-media-pdf-zoomed-full-document',
      );
      await tester.tap(find.byTooltip('缩小文档'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('上一页'));
      await tester.pumpAndSettle();
      expect(viewer.controller!.pageNumber, 1);
      await tester.tap(find.byKey(const ValueKey('media-return-button')));
      await tester.pumpAndSettle();
      expect(find.byType(PdfViewer), findsNothing);
      expect(find.text('媒体返回目标'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// PDF uses a transformed document, not Flutter ScrollPosition. Walk its real
/// visible document rect and stitch the rendered viewport at measured offsets.
Future<void> _captureLongDocument(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  PdfViewerController controller, {
  String name = 'native-media-pdf-full-document',
}) async {
  final original = controller.value.clone();
  final zoom = controller.currentZoom;
  final viewport = tester.getRect(find.byType(PdfViewer));
  final logicalWidth =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final documentHeight = controller.documentSize.height;
  final viewportHeight = controller.visibleRect.height;
  final centerX = controller.visibleRect.center.dx;
  final frames = <ui.Image>[];
  final offsets = <double>[];
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  var written = 0.0;
  var firstTop = 0.0;
  var pixelRatio = 1.0;
  Rect? bounds;
  try {
    for (var index = 0; index < 30; index++) {
      final top = (index * viewportHeight * .75).clamp(
        0.0,
        (documentHeight - viewportHeight).clamp(0.0, documentHeight),
      );
      await controller.goTo(
        controller.calcMatrixFor(
          Offset(centerX, top + viewportHeight / 2),
          zoom: zoom,
        ),
        duration: Duration.zero,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      final bytes = await binding.takeScreenshot('$name-scroll-$index');
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      frames.add(image);
      pixelRatio = image.width / logicalWidth;
      bounds ??= Rect.fromLTRB(
        viewport.left * pixelRatio,
        viewport.top * pixelRatio,
        viewport.right * pixelRatio,
        viewport.bottom * pixelRatio,
      );
      if (index == 0) {
        firstTop = controller.visibleRect.top;
        expect(firstTop, lessThanOrEqualTo(.5), reason: 'Include document top');
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Rect.fromLTWH(0, 0, image.width.toDouble(), bounds.top),
          Paint(),
        );
      }
      final offset =
          (controller.visibleRect.top - firstTop) * zoom * pixelRatio;
      offsets.add(offset);
      final start = (written - offset).clamp(0.0, bounds.height);
      final count = bounds.height - start;
      if (count > 0) {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, bounds.top + start, image.width.toDouble(), count),
          Rect.fromLTWH(0, bounds.top + written, image.width.toDouble(), count),
          Paint(),
        );
        written += count;
      }
      if (controller.visibleRect.bottom >= documentHeight - .5) break;
    }
    expect(
      controller.visibleRect.bottom,
      greaterThanOrEqualTo(documentHeight - .5),
    );
    expect(offsets.length, greaterThan(1));
    final last = frames.last;
    final bottom = last.height - bounds!.bottom;
    canvas.drawImageRect(
      last,
      Rect.fromLTWH(0, bounds.bottom, last.width.toDouble(), bottom),
      Rect.fromLTWH(0, bounds.top + written, last.width.toDouble(), bottom),
      Paint(),
    );
    final picture = recorder.endRecording();
    final stitched = await picture.toImage(
      last.width,
      (bounds.top + written + bottom).ceil(),
    );
    picture.dispose();
    final data = await stitched.toByteData(format: ui.ImageByteFormat.png);
    stitched.dispose();
    final directory = await getApplicationDocumentsDirectory();
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    await File('${directory.path}/$name.json').writeAsString(
      jsonEncode({
        'kind': 'actual-native-PDF-viewer-measured-scroll-stitch',
        'page_count': controller.pageCount,
        'document_height': documentHeight,
        'first_visible_top': firstTop,
        'last_visible_bottom': controller.visibleRect.bottom,
        'zoom': zoom,
        'pixel_ratio': pixelRatio,
        'pixel_offsets': offsets,
        'viewport_bounds': [
          bounds.left,
          bounds.top,
          bounds.width,
          bounds.height,
        ],
        'stitched_content_height': written,
        'header_footer': 'each retained once',
      }),
    );
  } finally {
    for (final image in frames) {
      image.dispose();
    }
    await controller.goTo(original, duration: Duration.zero);
    await tester.pumpAndSettle();
  }
}

Future<PdfViewer> _waitForReadyPdf(WidgetTester tester) async {
  for (var attempt = 0; attempt < 300; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final finder = find.byType(PdfViewer);
    if (finder.evaluate().isEmpty) continue;
    final viewer = tester.widget<PdfViewer>(finder);
    if (viewer.controller?.isReady == true) return viewer;
  }
  fail('PDFium did not make the viewer ready.');
}

Future<void> _captureDocument(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final directory = await getApplicationDocumentsDirectory();
  await File('${directory.path}/$name.png').writeAsBytes(bytes);
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = data!.buffer.asUint8List();
  // Require rendered document text, excluding the header and toolbar.
  var ink = 0;
  for (
    var y = (frame.image.height * .15).round();
    y < frame.image.height * .8;
    y++
  ) {
    for (
      var x = (frame.image.width * .1).round();
      x < frame.image.width * .6;
      x++
    ) {
      final index = (y * frame.image.width + x) * 4;
      if (pixels[index] < 100 &&
          pixels[index + 1] < 100 &&
          pixels[index + 2] < 100) {
        ink++;
      }
    }
  }
  frame.image.dispose();
  codec.dispose();
  expect(ink, greaterThan(100), reason: 'PDF document text must paint.');
}

class _PdfAssetConnector implements ProductAssetHttpConnector {
  String? authorization;
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    authorization =
        headers[HttpHeaders.authorizationHeader] ?? headers['Authorization'];
    return ProductAssetHttpResponse(
      statusCode: HttpStatus.ok,
      statusText: 'OK',
      contentType: 'application/pdf',
      body: buildTwoPageTestPdf(),
    );
  }
}

class _NoopJsonTransport implements ApiJsonTransport {
  const _NoopJsonTransport();

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => throw UnsupportedError('No JSON request expected.');

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnsupportedError('No JSON request expected.');
}
