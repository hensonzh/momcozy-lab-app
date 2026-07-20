import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_image.dart';

void main() {
  testWidgets('renders loaded product asset bytes as an in-memory image', (
    tester,
  ) async {
    final repository = _repository([
      _response(statusCode: 200, body: _onePixelPng),
    ]);

    await tester.pumpWidget(
      _host(
        ProductAssetImage(reference: _imageReference, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-asset-image')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-asset-image-loading')),
      findsNothing,
    );
  });

  testWidgets('shows a retry state and reloads a failed image', (tester) async {
    final connector = _FakeProductAssetConnector([
      _response(statusCode: 503, contentType: 'application/json'),
      _response(statusCode: 200, body: _onePixelPng),
    ]);
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: connector,
    );

    await tester.pumpWidget(
      _host(
        ProductAssetImage(reference: _imageReference, repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-asset-image-error')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('product-asset-image-retry')));
    await tester.pumpAndSettle();

    expect(connector.calls, 2);
    expect(find.byKey(const ValueKey('product-asset-image')), findsOneWidget);
  });

  testWidgets('requests a display variant and decodes to the target width', (
    tester,
  ) async {
    final connector = _FakeProductAssetConnector([
      _response(statusCode: 200, body: _onePixelPng),
    ]);
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: connector,
    );

    await tester.pumpWidget(
      _host(
        ProductAssetImage(
          reference: _imageReference,
          repository: repository,
          variant: ProductAssetVariant.display,
          cacheWidth: 720,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('product-asset-image')),
    );
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 720);
    expect(
      connector.uris.single,
      Uri.parse(
        'https://api.example.test/v1/assets/asset-image?variant=display',
      ),
    );
  });

  testWidgets('agent markdown cards request the display image variant', (
    tester,
  ) async {
    final connector = _FakeProductAssetConnector([
      _response(statusCode: 200, body: _onePixelPng),
    ]);
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: connector,
    );

    await tester.pumpWidget(
      _host(
        AgentMarkdownText(
          '![Air1 guide](/v1/assets/asset-image?kind=image)',
          productAssetRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      connector.uris.single,
      Uri.parse(
        'https://api.example.test/v1/assets/asset-image?variant=display',
      ),
    );
  });
}

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

final _imageReference = ProductAssetReference.tryParse(
  '/v1/assets/asset-image?kind=image',
)!;

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

ProductAssetRepository _repository(List<ProductAssetHttpResponse> responses) {
  return ProductAssetRepository(
    baseUri: Uri.parse('https://api.example.test'),
    connector: _FakeProductAssetConnector(responses),
  );
}

ProductAssetHttpResponse _response({
  required int statusCode,
  String contentType = 'image/png',
  Uint8List? body,
}) {
  return ProductAssetHttpResponse(
    statusCode: statusCode,
    statusText: statusCode == 200 ? 'OK' : 'Unavailable',
    contentType: contentType,
    body: body ?? Uint8List(0),
  );
}

class _FakeProductAssetConnector implements ProductAssetHttpConnector {
  _FakeProductAssetConnector(List<ProductAssetHttpResponse> responses)
    : _responses = List.of(responses);

  final List<ProductAssetHttpResponse> _responses;
  int calls = 0;
  final uris = <Uri>[];

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    calls += 1;
    uris.add(uri);
    return _responses.removeAt(0);
  }
}
