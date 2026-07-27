import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/app/momcozy_api_runtime.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/media/data/product_asset_repository.dart';
import 'package:pdfrx/pdfrx.dart';

import '../test/support/test_pdf_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders and navigates a two-page authenticated PDF',
    (tester) async {
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test'),
        connector: _PdfAssetConnector(),
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
          router: createMomCozyRouter(initialLocation: location),
        ),
      );
      final viewer = await _waitForReadyPdf(tester);

      expect(viewer.controller!.pageCount, 2);
      await viewer.controller!.goToPage(pageNumber: 2, duration: Duration.zero);
      await tester.pump(const Duration(milliseconds: 300));
      expect(viewer.controller!.pageNumber, 2);

      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final screenshot = await binding.takeScreenshot('media-pdf-page-2');
      expect(await _screenshotColorCount(screenshot), greaterThan(8));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
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

Future<int> _screenshotColorCount(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = data!.buffer.asUint8List();
  final colors = <int>{};
  for (var index = 0; index + 3 < pixels.length; index += 1600) {
    colors.add(
      (pixels[index] << 16) | (pixels[index + 1] << 8) | pixels[index + 2],
    );
  }
  frame.image.dispose();
  codec.dispose();
  return colors.length;
}

class _PdfAssetConnector implements ProductAssetHttpConnector {
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
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
