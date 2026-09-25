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
          expect(find.text('Back to home'), findsOneWidget);
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
        await _golden('media-image-zoomed', width, scale);
        final beforePan = transform.value.getTranslation();
        await tester.drag(viewer, const Offset(60, 40));
        await tester.pumpAndSettle();
        expect(transform.value.getTranslation(), isNot(beforePan));
        expect(transform.value.getMaxScaleOnAxis(), 2.5);
        await _golden('media-image-panned', width, scale);
        await tester.tap(viewer);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(viewer);
        await tester.pumpAndSettle();
        expect(transform.value.getMaxScaleOnAxis(), 1);
        await _golden('media-image-reset', width, scale);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
      testWidgets('PDF loading failure retry and return $width / $scale', (
        tester,
      ) async {
        _size(tester, width);
        final pending = Completer<ProductAssetHttpResponse>();
        final retry = Completer<ProductAssetHttpResponse>();
        final connector = _Connector()..response = () => pending.future;
        await tester.pumpWidget(
          _app(
            scale,
            kind: 'pdf',
            repository: ProductAssetRepository(
              baseUri: Uri.parse('https://api.example.test'),
              connector: connector,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const ValueKey('media-viewer-loading')),
          findsOneWidget,
        );
        await _golden('media-pdf-loading', width, scale);
        pending.complete(_failure());
        await tester.pumpAndSettle();
        expect(find.text('Could not load PDF'), findsOneWidget);
        await _golden('media-pdf-retry', width, scale);
        connector.response = () => retry.future;
        await tester.tap(find.byKey(const ValueKey('media-viewer-retry')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(connector.calls, 2);
        expect(
          find.byKey(const ValueKey('media-viewer-loading')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('media-return-button')));
        await tester.pumpAndSettle();
        retry.complete(_failure());
        await tester.pumpAndSettle();
        expect(find.text('Back to home'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final kind in ['missing', 'image', 'pdf']) {
    testWidgets('short large $kind keeps header and recovery reachable', (
      tester,
    ) async {
      _size(tester, 320, height: 568);
      final connector = _Connector()..response = () async => _failure();
      await tester.pumpWidget(
        _app(
          2,
          kind: kind,
          repository: kind == 'missing'
              ? null
              : ProductAssetRepository(
                  baseUri: Uri.parse('https://api.example.test'),
                  connector: connector,
                ),
        ),
      );
      await tester.pumpAndSettle();
      final back = find.byKey(const ValueKey('media-return-button'));
      expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(44));
      if (kind != 'missing') {
        expect(find.byTooltip('Feeding positions and care'), findsOneWidget);
        final retry = find.byKey(const ValueKey('media-viewer-retry'));
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        expect(find.text('Reload'), findsOneWidget);
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        expect(tester.getBottomRight(retry).dy, lessThanOrEqualTo(568));
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(connector.calls, 2);
      } else {
        expect(
          find.text('Open an image, video, or document from a resource card.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await _golden('media-short-$kind', 320, 2);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text('Back to home'), findsOneWidget);
    });
  }
  for (final kind in ['image', 'pdf']) {
    for (final status in [401, 403, 200]) {
      testWidgets(
        '$kind authorization or unsupported content $status remains retryable',
        (tester) async {
          _size(tester, 320);
          final connector = _Connector()
            ..response = () async => ProductAssetHttpResponse(
              statusCode: status,
              statusText: 'Fixture',
              contentType: 'text/plain',
              body: Uint8List.fromList([
                110,
                111,
                116,
                32,
                109,
                101,
                100,
                105,
                97,
              ]),
            );
          var refreshed = 0;
          final repository = ProductAssetRepository(
            baseUri: Uri.parse('https://api.example.test'),
            connector: connector,
            tokenProvider: () => 'fixture-token',
            onUnauthorized: () async {
              refreshed++;
              return true;
            },
          );
          await tester.pumpWidget(_app(2, kind: kind, repository: repository));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('media-viewer-retry')),
            findsOneWidget,
          );
          expect(refreshed, status == 401 ? 1 : 0);
          expect(connector.calls, status == 401 ? 2 : 1);
          await tester.tap(find.byKey(const ValueKey('media-return-button')));
          await tester.pumpAndSettle();
          expect(find.text('Back to home'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

void _size(WidgetTester tester, double width, {double height = 844}) {
  tester.view.physicalSize = Size(width, height);
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
        builder: (_, _) => const Scaffold(body: Text('Back to home')),
      ),
      GoRoute(
        path: '/media-viewer',
        builder: (_, _) => Scaffold(
          body: MediaViewerPage(
            path: '/media-viewer',
            title: 'Media',
            summary: '',
            icon: Icons.image_outlined,
            accent: MomCozyColors.primary,
            routeExtra: kind == 'missing'
                ? null
                : {
                    'kind': kind,
                    'url': repository == null
                        ? 'invalid'
                        : '/v1/assets/asset-$kind?kind=$kind',
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
  {
    await expectLater(
      find.byKey(const ValueKey('media-capture')),
      matchesGoldenFile(
        '../../goldens/design_system/$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
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
