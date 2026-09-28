@Tags(['golden'])
library;

import 'dart:ffi' show DynamicLibrary;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      testWidgets('native PDF preview, scroll and zoom $width / $scale', (
        tester,
      ) async {
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
                    title: 'Media',
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
        await _waitForDocumentPaint(tester);
        {
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile(
              '../goldens/design_system/media-pdf-loaded-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
            ),
          );
        }
        expect(find.text('Page 1 of 2'), findsOneWidget);
        for (final label in [
          'Previous page',
          'Next page',
          'Zoom out',
          'Zoom in',
        ]) {
          final size = tester.getSize(find.byTooltip(label));
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Previous page',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Next page'));
        await tester.pumpAndSettle();
        expect(controller.pageNumber, 2);
        expect(find.text('Page 2 of 2'), findsOneWidget);
        await _capturePdf(tester, 'page-2', width, scale);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Next page',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Previous page'));
        await tester.pumpAndSettle();
        expect(controller.pageNumber, 1);
        final originalZoom = controller.currentZoom;
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
        expect(controller.currentZoom, greaterThan(originalZoom));
        await _capturePdf(tester, 'zoomed', width, scale);
        await tester.tap(find.byTooltip('Zoom out'));
        await tester.pumpAndSettle();
        expect(controller.currentZoom, closeTo(originalZoom, .001));
        await _capturePdf(tester, 'reset', width, scale);
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
      }, skip: module == null);
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

Future<void> _waitForDocumentPaint(WidgetTester tester) async {
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    final painted = await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture')),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      var rose = 0;
      final bytes = data!.buffer.asUint8List();
      for (
        var i = image.width * 90 * 4;
        i + 3 < image.width * (image.height - 200) * 4;
        i += 4
      ) {
        final r = bytes[i], g = bytes[i + 1], b = bytes[i + 2];
        if (r > 140 && r > g * 1.4 && b > g && b < 170) rose++;
      }
      image.dispose();
      return rose > 40;
    });
    if (painted == true) return;
  }
  fail('PDF page content did not paint: fixture rose rule is missing.');
}

Future<void> _capturePdf(
  WidgetTester tester,
  String state,
  double width,
  double scale,
) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const ValueKey('capture')),
    matchesGoldenFile(
      '../goldens/design_system/media-pdf-$state-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
    ),
  );
}
