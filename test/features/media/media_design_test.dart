import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/presentation/media_viewer_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final kind in ['missing', 'image', 'pdf', 'video']) {
        testWidgets('media $kind unavailable and return $width / $scale', (
          tester,
        ) async {
          _size(tester, width);
          await tester.pumpWidget(_app(scale, kind: kind));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _golden('media-unavailable-$kind', width, scale);
          await tester.tap(find.byKey(const ValueKey('media-return-button')));
          await tester.pumpAndSettle();
          expect(find.text('返回首页'), findsOneWidget);
        });
      }
      testWidgets('image loading failure retry and zoom $width / $scale', (
        tester,
      ) async {
        _size(tester, width);
        final connector = _Connector();
        final pending = Completer<ProductAssetHttpResponse>();
        connector.response = () => pending.future;
        final repository = ProductAssetRepository(
          baseUri: Uri.parse('https://api.example.test'),
          connector: connector,
        );
        await tester.pumpWidget(
          _app(scale, kind: 'image', repository: repository),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const ValueKey('media-viewer-loading')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _golden('media-image-loading', width, scale);
        pending.complete(_failure());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('media-viewer-retry')),
          findsOneWidget,
        );
        await _golden('media-image-retry', width, scale);
        final bytes = File('assets/images/mom/milk-hero.png').readAsBytesSync();
        connector.response = () async => ProductAssetHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          contentType: 'image/png',
          body: bytes,
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(bytes),
            tester.element(find.byType(MediaViewerPage)),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
        await tester.pumpAndSettle();
        expect(connector.calls, 2);
        final viewer = find.byKey(
          const ValueKey('media-image-interactive-viewer'),
        );
        expect(viewer, findsOneWidget);
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await _golden('media-image-loaded', width, scale);
        final transform = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!;
        await tester.tap(viewer);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewer);
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), 2.5);
        await tester.tap(viewer);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewer);
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  double scale, {
  required String kind,
  ProductAssetRepository? repository,
}) {
  final router = GoRouter(
    initialLocation: '/media-viewer',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('返回首页')),
      ),
      GoRoute(
        path: '/media-viewer',
        builder: (_, _) => Scaffold(
          body: MediaViewerPage(
            path: '/media-viewer',
            title: '媒体',
            summary: '',
            icon: Icons.image_outlined,
            accent: MomCozyColors.primary,
            routeExtra: kind == 'missing'
                ? null
                : {
                    'kind': kind,
                    'url': repository == null
                        ? 'invalid'
                        : '/v1/assets/asset-image?kind=image',
                    'title': '喂养姿势与照护指南 · Feeding positions and care',
                  },
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  final app = MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: momCozyTheme(),
    routerConfig: router,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  );
  return RepaintBoundary(
    key: const ValueKey('media-capture'),
    child: repository == null
        ? app
        : MomCozyRuntimeScope(
            apiRuntime: MomCozyApiRuntime(
              jsonTransport: FixtureApiJsonTransport({}),
              productAssetRepository: repository,
            ),
            child: app,
          ),
  );
}

Future<void> _golden(String name, double width, double scale) async {
  if (scale == 1) {
    await expectLater(
      find.byKey(const ValueKey('media-capture')),
      matchesGoldenFile(
        '../../goldens/design_system/$name-${width.toInt()}.png',
      ),
    );
  }
}

ProductAssetHttpResponse _failure() => ProductAssetHttpResponse(
  statusCode: 503,
  statusText: 'Unavailable',
  contentType: 'application/json',
  body: Uint8List(0),
);

class _Connector implements ProductAssetHttpConnector {
  late Future<ProductAssetHttpResponse> Function() response;
  int calls = 0;
  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) {
    calls++;
    return response();
  }
}
