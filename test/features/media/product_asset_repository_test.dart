import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';

void main() {
  test(
    'loads authenticated product asset bytes from the configured API',
    () async {
      final connector = _FakeProductAssetConnector([
        ProductAssetHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          contentType: 'image/png',
          body: Uint8List.fromList(const [1, 2, 3]),
        ),
      ]);
      final repository = ProductAssetRepository(
        baseUri: Uri.parse('https://api.example.test/mobile'),
        tokenProvider: () => 'access-token',
        connector: connector,
      );
      final reference = ProductAssetReference.tryParse(
        '/v1/assets/asset-image?kind=image',
      )!;

      final content = await repository.load(reference);

      expect(content.bytes, [1, 2, 3]);
      expect(content.contentType, 'image/png');
      expect(
        connector.requests.single.uri,
        Uri.parse('https://api.example.test/mobile/v1/assets/asset-image'),
      );
      expect(
        connector.requests.single.headers['Authorization'],
        'Bearer access-token',
      );
      expect(connector.requests.single.maxBytes, 16 * 1024 * 1024);
    },
  );

  test('refreshes once after an unauthorized asset request', () async {
    var token = 'expired-token';
    var refreshCalls = 0;
    final connector = _FakeProductAssetConnector([
      ProductAssetHttpResponse(
        statusCode: 401,
        statusText: 'Unauthorized',
        contentType: 'application/json',
        body: Uint8List(0),
      ),
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'application/pdf',
        body: Uint8List.fromList(const [37, 80, 68, 70]),
      ),
    ]);
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      tokenProvider: () => token,
      onUnauthorized: () async {
        refreshCalls += 1;
        token = 'fresh-token';
        return true;
      },
      connector: connector,
    );
    final reference = ProductAssetReference.tryParse(
      '/v1/assets/asset-pdf?kind=pdf',
    )!;

    await repository.load(reference);

    expect(refreshCalls, 1);
    expect(connector.requests, hasLength(2));
    expect(
      connector.requests.last.headers['Authorization'],
      'Bearer fresh-token',
    );
  });

  test('rejects an unexpected content type and oversized payload', () async {
    final wrongTypeRepository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: _FakeProductAssetConnector([
        ProductAssetHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          contentType: 'text/html',
          body: Uint8List.fromList(const [1]),
        ),
      ]),
    );
    final image = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;

    await expectLater(
      wrongTypeRepository.load(image),
      throwsA(
        isA<ProductAssetLoadException>().having(
          (error) => error.code,
          'code',
          'content_type_mismatch',
        ),
      ),
    );

    final oversizedRepository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      maxImageBytes: 2,
      connector: _FakeProductAssetConnector([
        ProductAssetHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          contentType: 'image/png',
          body: Uint8List.fromList(const [1, 2, 3]),
        ),
      ]),
    );

    await expectLater(
      oversizedRepository.load(image),
      throwsA(
        isA<ProductAssetLoadException>().having(
          (error) => error.code,
          'code',
          'asset_too_large',
        ),
      ),
    );
  });

  test('builds a video network request without downloading the video', () {
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      tokenProvider: () => 'video-token',
      connector: _FakeProductAssetConnector(const []),
    );
    final video = ProductAssetReference.tryParse(
      '/v1/assets/asset-video?kind=video',
    )!;

    final request = repository.networkRequest(video);

    expect(
      request.uri,
      Uri.parse('https://api.example.test/v1/assets/asset-video'),
    );
    expect(request.headers['Authorization'], 'Bearer video-token');
    expect(request.headers['Accept'], 'video/*');
  });

  test('rebuilds a video request after refreshing authorization', () async {
    var token = 'expired-token';
    var refreshCalls = 0;
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      tokenProvider: () => token,
      onUnauthorized: () async {
        refreshCalls += 1;
        token = 'fresh-token';
        return true;
      },
      connector: _FakeProductAssetConnector(const []),
    );
    final video = ProductAssetReference.tryParse(
      '/v1/assets/asset-video?kind=video',
    )!;

    final request = await repository.refreshNetworkRequest(video);

    expect(refreshCalls, 1);
    expect(request?.headers['Authorization'], 'Bearer fresh-token');
    expect(request?.headers['Accept'], 'video/*');
  });

  test('loads the display image variant and reuses its memory cache', () async {
    final connector = _FakeProductAssetConnector([
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/webp',
        body: Uint8List.fromList(const [1, 2, 3]),
      ),
    ]);
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: connector,
    );
    final image = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;

    final first = await repository.load(
      image,
      variant: ProductAssetVariant.display,
    );
    final second = await repository.load(
      image,
      variant: ProductAssetVariant.display,
    );

    expect(identical(first, second), isTrue);
    expect(connector.requests, hasLength(1));
    expect(
      connector.requests.single.uri,
      Uri.parse(
        'https://api.example.test/v1/assets/asset-image?variant=display',
      ),
    );
  });

  test('coalesces concurrent loads for the same product asset', () async {
    final connector = _BlockingProductAssetConnector();
    final repository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: connector,
    );
    final image = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;

    final first = repository.load(image);
    final second = repository.load(image);
    await Future<void>.delayed(Duration.zero);

    expect(connector.calls, 1);
    connector.complete(
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/png',
        body: Uint8List.fromList(const [1, 2, 3]),
      ),
    );
    final results = await Future.wait([first, second]);

    expect(identical(results[0], results[1]), isTrue);
  });

  test('reuses persistent cache across repository instances', () async {
    final cache = _FakePersistentProductAssetCache();
    final reference = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;
    final firstConnector = _FakeProductAssetConnector([
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/png',
        body: Uint8List.fromList(const [1, 2, 3]),
      ),
    ]);
    final firstRepository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: firstConnector,
      persistentCache: cache,
    );

    await firstRepository.load(reference);
    final secondConnector = _FakeProductAssetConnector(const []);
    final secondRepository = ProductAssetRepository(
      baseUri: Uri.parse('https://api.example.test'),
      connector: secondConnector,
      persistentCache: cache,
    );
    final cached = await secondRepository.load(reference);

    expect(cached.bytes, [1, 2, 3]);
    expect(secondConnector.requests, isEmpty);
  });
}

class _FakeProductAssetConnector implements ProductAssetHttpConnector {
  _FakeProductAssetConnector(List<ProductAssetHttpResponse> responses)
    : _responses = List.of(responses);

  final List<ProductAssetHttpResponse> _responses;
  final requests = <_RecordedProductAssetRequest>[];

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    requests.add(
      _RecordedProductAssetRequest(
        uri: uri,
        headers: Map<String, String>.from(headers),
        maxBytes: maxBytes,
      ),
    );
    return _responses.removeAt(0);
  }
}

class _RecordedProductAssetRequest {
  const _RecordedProductAssetRequest({
    required this.uri,
    required this.headers,
    required this.maxBytes,
  });

  final Uri uri;
  final Map<String, String> headers;
  final int maxBytes;
}

class _BlockingProductAssetConnector implements ProductAssetHttpConnector {
  final _response = Completer<ProductAssetHttpResponse>();
  int calls = 0;

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) {
    calls += 1;
    return _response.future;
  }

  void complete(ProductAssetHttpResponse response) {
    _response.complete(response);
  }
}

class _FakePersistentProductAssetCache implements ProductAssetPersistentCache {
  final _entries = <String, ProductAssetContent>{};

  @override
  Future<ProductAssetContent?> read(
    ProductAssetReference reference, {
    required ProductAssetVariant variant,
  }) async {
    return _entries['${reference.assetId}:${reference.kind.name}:${variant.name}'];
  }

  @override
  Future<void> write(
    ProductAssetContent content, {
    required ProductAssetVariant variant,
  }) async {
    final reference = content.reference;
    _entries['${reference.assetId}:${reference.kind.name}:${variant.name}'] =
        content;
  }
}
