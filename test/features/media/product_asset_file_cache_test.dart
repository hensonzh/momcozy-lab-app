import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_file_cache.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';

void main() {
  test('persists product assets across cache instances', () async {
    final root = await Directory.systemTemp.createTemp('product-asset-cache-');
    addTearDown(() => root.delete(recursive: true));
    final reference = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;
    final content = ProductAssetContent(
      reference: reference,
      contentType: 'image/webp',
      bytes: Uint8List.fromList(const [1, 2, 3]),
    );
    final first = ProductAssetFileCache(directoryProvider: () async => root);

    await first.write(content, variant: ProductAssetVariant.display);
    final second = ProductAssetFileCache(directoryProvider: () async => root);
    final cached = await second.read(
      reference,
      variant: ProductAssetVariant.display,
    );

    expect(cached?.contentType, 'image/webp');
    expect(cached?.bytes, [1, 2, 3]);
  });

  test('ignores expired persistent entries', () async {
    final root = await Directory.systemTemp.createTemp('product-asset-cache-');
    addTearDown(() => root.delete(recursive: true));
    var now = DateTime.utc(2026, 7, 20, 8);
    final cache = ProductAssetFileCache(
      directoryProvider: () async => root,
      maxAge: const Duration(hours: 1),
      now: () => now,
    );
    final reference = ProductAssetReference.tryParse(
      '/v1/assets/asset-image?kind=image',
    )!;
    await cache.write(
      ProductAssetContent(
        reference: reference,
        contentType: 'image/png',
        bytes: Uint8List.fromList(const [1]),
      ),
      variant: ProductAssetVariant.original,
    );

    now = now.add(const Duration(hours: 2));

    expect(
      await cache.read(reference, variant: ProductAssetVariant.original),
      isNull,
    );
  });
}
