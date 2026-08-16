import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/media/data/media_content_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';

void main() {
  test('loads an authenticated owned image only when requested', () async {
    final connector = _FakeBinaryConnector(
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/png',
        body: Uint8List.fromList([1, 2, 3]),
      ),
    );
    final repository = MediaContentRepository(
      baseUri: Uri.parse('https://api.example.com'),
      tokenProvider: () => 'access-token',
      connector: connector,
    );

    final bytes = await repository.loadImage(
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );

    expect(bytes, [1, 2, 3]);
    expect(
      connector.uri.path,
      '/v1/files/0ea4b76d-2bc4-4ab8-91b7-3b24df53c518/content',
    );
    expect(connector.headers['Authorization'], 'Bearer access-token');
    expect(connector.headers['Accept'], 'image/*');
    expect(connector.maxBytes, 10 * 1024 * 1024);
  });

  test('deduplicates and exposes a loaded full image synchronously', () async {
    const fileId = '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518';
    final connector = _FakeBinaryConnector(
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/png',
        body: Uint8List.fromList([1, 2, 3]),
      ),
    );
    final repository = MediaContentRepository(
      baseUri: Uri.parse('https://api.example.com'),
      connector: connector,
    );

    final first = repository.loadImage(fileId);
    final concurrent = repository.loadImage(fileId);

    expect(identical(first, concurrent), isTrue);
    expect(await first, [1, 2, 3]);
    expect(repository.cachedImage(fileId), [1, 2, 3]);
    expect(await repository.loadImage(fileId), [1, 2, 3]);
    expect(connector.requestCount, 1);
  });

  test('uses the supported content resource for image previews', () async {
    final connector = _FakeBinaryConnector(
      ProductAssetHttpResponse(
        statusCode: 200,
        statusText: 'OK',
        contentType: 'image/webp',
        body: Uint8List.fromList([4, 5, 6]),
      ),
    );
    final repository = MediaContentRepository(
      baseUri: Uri.parse('https://api.example.com'),
      tokenProvider: () => 'access-token',
      connector: connector,
    );

    final first = repository.loadImageThumbnail(
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );
    final second = repository.loadImageThumbnail(
      '0ea4b76d-2bc4-4ab8-91b7-3b24df53c518',
    );

    expect(identical(first, second), isTrue);
    expect(await first, [4, 5, 6]);
    expect(
      repository.cachedImageThumbnail('0ea4b76d-2bc4-4ab8-91b7-3b24df53c518'),
      [4, 5, 6],
    );
    expect(connector.requestCount, 1);
    expect(
      connector.uri.path,
      '/v1/files/0ea4b76d-2bc4-4ab8-91b7-3b24df53c518/content',
    );
    expect(connector.maxBytes, 10 * 1024 * 1024);
  });
}

class _FakeBinaryConnector implements ProductAssetHttpConnector {
  _FakeBinaryConnector(this.response);

  final ProductAssetHttpResponse response;
  late Uri uri;
  Map<String, String> headers = const {};
  int maxBytes = 0;
  int requestCount = 0;

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    requestCount += 1;
    this.uri = uri;
    this.headers = headers;
    this.maxBytes = maxBytes;
    return response;
  }
}
