enum ProductAssetKind {
  image,
  pdf,
  video;

  static ProductAssetKind? parse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'image' => ProductAssetKind.image,
      'pdf' => ProductAssetKind.pdf,
      'video' => ProductAssetKind.video,
      _ => null,
    };
  }

  static ProductAssetKind? fromContentType(String? value) {
    final normalized = value?.split(';').first.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.startsWith('image/')) return ProductAssetKind.image;
    if (normalized == 'application/pdf') return ProductAssetKind.pdf;
    if (normalized.startsWith('video/')) return ProductAssetKind.video;
    return null;
  }

  String get routeValue => name;

  String get defaultTitle => switch (this) {
    ProductAssetKind.image => '图片',
    ProductAssetKind.pdf => 'PDF',
    ProductAssetKind.video => '视频',
  };

  String get acceptHeader => switch (this) {
    ProductAssetKind.image => 'image/*',
    ProductAssetKind.pdf => 'application/pdf',
    ProductAssetKind.video => 'video/*',
  };
}

enum ProductAssetVariant { original, display }

class ProductAssetReference {
  const ProductAssetReference({
    required this.assetId,
    required this.kind,
    this.title,
  });

  static final _assetIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

  final String assetId;
  final ProductAssetKind kind;
  final String? title;

  String get requestPath => '/v1/assets/${Uri.encodeComponent(assetId)}';

  String get effectiveTitle => title ?? kind.defaultTitle;

  static ProductAssetReference? tryParse(
    String value, {
    String? kind,
    String? title,
  }) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return null;
    final segments = uri.pathSegments;
    var routeIndex = -1;
    for (var index = 0; index + 2 < segments.length; index += 1) {
      if (segments[index] == 'v1' && segments[index + 1] == 'assets') {
        routeIndex = index;
        break;
      }
    }
    if (routeIndex < 0 || routeIndex + 3 != segments.length) return null;

    final assetId = segments[routeIndex + 2].trim();
    if (!_assetIdPattern.hasMatch(assetId)) return null;
    final explicitKind = kind?.trim();
    final parsedKind = ProductAssetKind.parse(
      explicitKind?.isNotEmpty == true
          ? explicitKind
          : uri.queryParameters['kind'],
    );
    if (parsedKind == null) return null;
    final normalizedTitle = title?.trim();
    return ProductAssetReference(
      assetId: assetId,
      kind: parsedKind,
      title: normalizedTitle?.isNotEmpty == true ? normalizedTitle : null,
    );
  }
}
