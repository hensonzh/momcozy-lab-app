import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_image_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('deletes an abandoned uploaded image idempotently', () async {
    final transport = FixtureApiJsonTransport(const {});
    final repository = AgentImageAssetRepository(
      mutationTransport: transport,
      baseUri: Uri.parse('https://api.example.test'),
      connector: _FakeContentConnector(),
    );

    await repository.discard(' file-001 ');

    expect(transport.lastMethod, 'DELETE');
    expect(transport.lastPath, '/v1/files/file-001');
    expect(transport.lastHeaders, {
      'Idempotency-Key': 'agent-image-discard-file-001',
    });
  });

  test(
    'loads persisted image bytes through the owner-scoped content route',
    () async {
      final connector = _FakeContentConnector(
        response: ProductAssetHttpResponse(
          statusCode: 200,
          statusText: 'OK',
          contentType: 'image/png',
          body: Uint8List.fromList(const [1, 2, 3]),
        ),
      );
      final repository = AgentImageAssetRepository(
        mutationTransport: FixtureApiJsonTransport(const {}),
        baseUri: Uri.parse('https://api.example.test/base'),
        tokenProvider: () => 'access-token',
        connector: connector,
      );

      final bytes = await repository.loadBytes('file-001');

      expect(bytes, [1, 2, 3]);
      expect(connector.uri?.path, '/base/v1/files/file-001/content');
      expect(connector.headers, {
        'X-Momcozy-Client': 'flutter',
        'Accept': 'image/*',
        'Authorization': 'Bearer access-token',
      });
    },
  );
}

class _FakeContentConnector implements ProductAssetHttpConnector {
  _FakeContentConnector({ProductAssetHttpResponse? response})
    : response =
          response ??
          ProductAssetHttpResponse(
            statusCode: 200,
            statusText: 'OK',
            contentType: 'image/png',
            body: Uint8List(0),
          );

  final ProductAssetHttpResponse response;
  Uri? uri;
  Map<String, String>? headers;

  @override
  Future<ProductAssetHttpResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required int maxBytes,
  }) async {
    this.uri = uri;
    this.headers = headers;
    return response;
  }
}
