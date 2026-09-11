import 'dart:ffi' show DynamicLibrary;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../support/fixture_api_transport.dart';
import '../support/momcozy_test_fonts.dart';

// Real native PDFium, with no provider requests. The local library is supplied
// explicitly so the ordinary widget suite never downloads native binaries.
void main() {
  final module = Platform.environment['PDFIUM_PATH'];
  setUpAll(() async {
    if (module == null) return;
    DynamicLibrary.open(module);
    await pdfrxInitialize();
    await loadMomCozyTestFonts();
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'native PDF preview, scroll and zoom $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final runtime = MomCozyApiRuntime(
            jsonTransport: FixtureApiJsonTransport({}),
            productAssetRepository: ProductAssetRepository(
              baseUri: Uri.parse('https://api.example.test'),
              connector: _PdfConnector(),
            ),
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('capture'),
              child: MomCozyRuntimeScope(
                apiRuntime: runtime,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: momCozyTheme(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: MediaViewerPage(
                      path: '/media-viewer',
                      title: '媒体',
                      summary: '',
                      icon: Icons.picture_as_pdf_outlined,
                      accent: MomCozyColors.primary,
                      routeExtra: {
                        'kind': 'pdf',
                        'url': '/v1/assets/local-pdf?kind=pdf',
                        'title': '文档预览 · Local document',
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          PdfViewerController? controller;
          for (var frame = 0; frame < 100; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            if (find.byType(PdfViewer).evaluate().isNotEmpty) {
              controller = tester
                  .widget<PdfViewer>(find.byType(PdfViewer))
                  .controller;
            }
            if (controller?.isReady ?? false) {
              break;
            }
          }
          expect(controller?.isReady, isTrue);
          expect(controller!.pages, hasLength(2));
          // Native rendering and dart:ui image decoding complete outside fake time.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1) {
            await expectLater(
              find.byKey(const ValueKey('capture')),
              matchesGoldenFile(
                '../goldens/design_system/media-pdf-loaded-${width.toInt()}.png',
              ),
            );
          }
          final before = controller.value.clone();
          await tester.drag(find.byType(PdfViewer), const Offset(0, -350));
          await tester.pumpAndSettle();
          expect(controller.value, isNot(before));
          final zoom = controller.currentZoom;
          await tester.tap(find.byType(PdfViewer));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(find.byType(PdfViewer));
          await tester.pumpAndSettle();
          expect(controller.currentZoom, greaterThan(zoom));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
        },
        skip: module == null,
      );
    }
  }
}

class _PdfConnector implements ProductAssetHttpConnector {
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async => ProductAssetHttpResponse(
    statusCode: 200,
    statusText: 'OK',
    contentType: 'application/pdf',
    body: File('test/fixtures/media/local-preview.pdf').readAsBytesSync(),
  );
}
