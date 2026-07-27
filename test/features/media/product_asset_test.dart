import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/media/domain/product_asset.dart';

void main() {
  group('ProductAssetReference', () {
    test('parses the production asset route into a typed reference', () {
      final reference = ProductAssetReference.tryParse(
        '/v1/assets/asset_856e6c6bf6b6992c?kind=image',
        title: 'Air1 核心部件',
      );

      expect(reference, isNotNull);
      expect(reference!.assetId, 'asset_856e6c6bf6b6992c');
      expect(reference.kind, ProductAssetKind.image);
      expect(reference.title, 'Air1 核心部件');
      expect(reference.requestPath, '/v1/assets/asset_856e6c6bf6b6992c');
    });

    test('accepts an absolute production URL and an explicit kind', () {
      final reference = ProductAssetReference.tryParse(
        'https://api.example.test/v1/assets/asset-guide',
        kind: 'pdf',
      );

      expect(reference?.assetId, 'asset-guide');
      expect(reference?.kind, ProductAssetKind.pdf);
    });

    test('rejects retired and malformed asset routes', () {
      expect(
        ProductAssetReference.tryParse(
          '/skill-assets/device-guidance/air1/guide.pdf',
          kind: 'pdf',
        ),
        isNull,
      );
      expect(
        ProductAssetReference.tryParse('/v1/assets/../../private.pdf?kind=pdf'),
        isNull,
      );
      expect(ProductAssetReference.tryParse('/v1/assets/asset-guide'), isNull);
    });
  });

  group('ProductAssetKind', () {
    test('maps supported content types without guessing unknown files', () {
      expect(
        ProductAssetKind.fromContentType('image/png'),
        ProductAssetKind.image,
      );
      expect(
        ProductAssetKind.fromContentType('application/pdf; charset=binary'),
        ProductAssetKind.pdf,
      );
      expect(
        ProductAssetKind.fromContentType('video/mp4'),
        ProductAssetKind.video,
      );
      expect(ProductAssetKind.fromContentType('text/html'), isNull);
    });
  });
}
