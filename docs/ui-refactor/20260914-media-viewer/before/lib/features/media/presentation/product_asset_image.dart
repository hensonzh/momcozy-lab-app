import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';

typedef ProductAssetImageLoadingBuilder = Widget Function(BuildContext context);
typedef ProductAssetImageErrorBuilder =
    Widget Function(BuildContext context, Object error, VoidCallback retry);
typedef ProductAssetImageLoadedBuilder =
    Widget Function(
      BuildContext context,
      ProductAssetContent content,
      Widget image,
    );

class ProductAssetImage extends StatefulWidget {
  const ProductAssetImage({
    super.key,
    required this.reference,
    required this.repository,
    this.variant = ProductAssetVariant.original,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.semanticLabel,
    this.cacheWidth,
    this.cacheHeight,
    this.loadingBuilder,
    this.errorBuilder,
    this.loadedBuilder,
  });

  final ProductAssetReference reference;
  final ProductAssetRepository? repository;
  final ProductAssetVariant variant;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final int? cacheWidth;
  final int? cacheHeight;
  final ProductAssetImageLoadingBuilder? loadingBuilder;
  final ProductAssetImageErrorBuilder? errorBuilder;
  final ProductAssetImageLoadedBuilder? loadedBuilder;

  @override
  State<ProductAssetImage> createState() => _ProductAssetImageState();
}

class _ProductAssetImageState extends State<ProductAssetImage> {
  late Future<ProductAssetContent> _content;

  @override
  void initState() {
    super.initState();
    _content = _load();
  }

  @override
  void didUpdateWidget(ProductAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.reference.assetId != widget.reference.assetId ||
        oldWidget.reference.kind != widget.reference.kind ||
        oldWidget.variant != widget.variant) {
      _content = _load();
    }
  }

  Future<ProductAssetContent> _load() {
    final repository = widget.repository;
    if (repository == null) {
      return Future<ProductAssetContent>.error(
        const ProductAssetLoadException(code: 'repository_unavailable'),
      );
    }
    return repository.load(widget.reference, variant: widget.variant);
  }

  void _retry() {
    setState(() {
      _content = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductAssetContent>(
      future: _content,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingBuilder?.call(context) ??
              const _DefaultProductAssetImageLoading();
        }
        final error = snapshot.error;
        if (error != null) {
          return widget.errorBuilder?.call(context, error, _retry) ??
              _DefaultProductAssetImageError(onRetry: _retry);
        }
        final content = snapshot.data;
        if (content == null) {
          return widget.loadingBuilder?.call(context) ??
              const _DefaultProductAssetImageLoading();
        }
        final image = Image.memory(
          content.bytes,
          key: const ValueKey('product-asset-image'),
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          gaplessPlayback: true,
          semanticLabel: widget.semanticLabel,
          cacheWidth: widget.cacheWidth,
          cacheHeight: widget.cacheHeight,
          errorBuilder: (context, error, stackTrace) {
            return widget.errorBuilder?.call(context, error, _retry) ??
                _DefaultProductAssetImageError(onRetry: _retry);
          },
        );
        return widget.loadedBuilder?.call(context, content, image) ?? image;
      },
    );
  }
}

class _DefaultProductAssetImageLoading extends StatelessWidget {
  const _DefaultProductAssetImageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('product-asset-image-loading'),
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _DefaultProductAssetImageError extends StatelessWidget {
  const _DefaultProductAssetImageError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('product-asset-image-error'),
      child: IconButton(
        key: const ValueKey('product-asset-image-retry'),
        tooltip: '重新加载',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    );
  }
}
