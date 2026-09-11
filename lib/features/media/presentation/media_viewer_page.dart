import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_image.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_video_player.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../../../shared/widgets/product_feedback.dart';

class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.path,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accent,
    this.routeUri,
    this.routeExtra,
  });

  final String path;
  final String title;
  final String summary;
  final IconData icon;
  final Color accent;
  final Uri? routeUri;
  final Object? routeExtra;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  void _returnFromMediaViewer() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final media = _MediaViewerRouteState.from(
      routeUri: widget.routeUri,
      routeExtra: widget.routeExtra,
    );
    final headerTitle = media?.title ?? '媒体';

    return ColoredBox(
      key: ValueKey('route-page-${widget.path}'),
      color: MomCozyColors.background,
      child: Column(
        children: [
          _MediaViewerHeader(
            title: headerTitle,
            onBack: _returnFromMediaViewer,
          ),
          Expanded(
            child: media == null
                ? const _MediaViewerMissingResource()
                : _MediaViewerContent(media: media),
          ),
        ],
      ),
    );
  }
}

class _MediaViewerHeader extends StatelessWidget {
  const _MediaViewerHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomCozyColors.background,
        border: Border(bottom: BorderSide(color: MomCozyColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MomCozyLayout.headerHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MomCozySpacing.pageGutter,
              vertical: MomCozySpacing.xs,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: MomCozyTapTargets.minimum,
                  child: IconButton(
                    key: const ValueKey('media-return-button'),
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: MomCozyIconSizes.standard,
                    ),
                    color: MomCozyColors.foreground,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: MomCozySpacing.content),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaViewerMissingResource extends StatelessWidget {
  const _MediaViewerMissingResource();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SingleChildScrollView(
        child: ProductEmptyView(title: '缺少资源参数，请从资料卡片进入。'),
      ),
    );
  }
}

class _MediaViewerContent extends StatelessWidget {
  const _MediaViewerContent({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    return switch (media.kind) {
      'image' => _ImageViewerStage(media: media),
      'video' => _VideoViewerStage(media: media),
      _ => _PdfViewerStage(media: media),
    };
  }
}

class _PdfViewerStage extends StatefulWidget {
  const _PdfViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_PdfViewerStage> createState() => _PdfViewerStageState();
}

class _PdfViewerStageState extends State<_PdfViewerStage> {
  ProductAssetReference? _reference;
  ProductAssetRepository? _repository;
  Future<ProductAssetContent>? _content;
  var _documentRevision = 0;
  final _pdfController = PdfViewerController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncContent();
  }

  @override
  void didUpdateWidget(_PdfViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url ||
        oldWidget.media.kind != widget.media.kind) {
      _syncContent();
    }
  }

  void _syncContent() {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (_reference?.assetId == reference?.assetId &&
        _reference?.kind == reference?.kind &&
        identical(_repository, repository)) {
      return;
    }
    _reference = reference;
    _repository = repository;
    _documentRevision += 1;
    _content = _load();
  }

  Future<ProductAssetContent>? _load() {
    final reference = _reference;
    final repository = _repository;
    if (reference == null || repository == null) {
      return null;
    }
    return repository.load(reference);
  }

  void _retry() {
    setState(() {
      _documentRevision += 1;
      _content = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final reference = _reference;
    final content = _content;
    if (reference == null || content == null) {
      return const _MediaViewerLoadError(
        message: 'PDF 加载失败',
        darkBackground: false,
        icon: Icons.picture_as_pdf_outlined,
      );
    }
    return FutureBuilder<ProductAssetContent>(
      future: content,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MediaViewerLoadError(
            message: 'PDF 加载失败',
            darkBackground: false,
            icon: Icons.picture_as_pdf_outlined,
            onRetry: _retry,
          );
        }
        final loaded = snapshot.data;
        if (loaded == null) {
          return const ColoredBox(
            color: MomCozyColors.background,
            child: _MediaViewerLoading(label: '加载 PDF…', darkBackground: false),
          );
        }
        return KeyedSubtree(
          key: const ValueKey('media-pdf-viewer'),
          child: PdfViewer.data(
            loaded.bytes,
            key: ValueKey('media-pdf-document-$_documentRevision'),
            sourceName: reference.assetId,
            controller: _pdfController,
            params: PdfViewerParams(
              margin: MomCozySpacing.compact,
              backgroundColor: MomCozyColors.background,
              minScale: 0.1,
              maxScale: 4,
              panAxis: PanAxis.free,
              pageDropShadow: MomCozyShadows.documentPage,
              loadingBannerBuilder: (context, downloaded, total) {
                return const _MediaViewerLoading(
                  label: '正在打开 PDF…',
                  darkBackground: false,
                );
              },
              errorBannerBuilder: (context, error, stackTrace, documentRef) {
                return _MediaViewerLoadError(
                  message: 'PDF 加载失败',
                  darkBackground: false,
                  icon: Icons.picture_as_pdf_outlined,
                  onRetry: _retry,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ImageViewerStage extends StatefulWidget {
  const _ImageViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  State<_ImageViewerStage> createState() => _ImageViewerStageState();
}

class _ImageViewerStageState extends State<_ImageViewerStage> {
  static const _doubleTapScale = 2.5;

  final _transformationController = TransformationController();
  Offset? _doubleTapPosition;

  @override
  void didUpdateWidget(_ImageViewerStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.url != widget.media.url) {
      _transformationController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.01) {
      _transformationController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapPosition ?? Offset.zero;
    _transformationController.value =
        Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1)
          ..setTranslationRaw(
            -position.dx * (_doubleTapScale - 1),
            -position.dy * (_doubleTapScale - 1),
            0,
          );
  }

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      widget.media.url,
      kind: widget.media.kind,
      title: widget.media.title,
    );
    if (reference == null) {
      return const _MediaViewerLoadError(message: '图片加载失败');
    }
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;

    return ColoredBox(
      color: MomCozyColors.mediaBackground,
      child: ProductAssetImage(
        reference: reference,
        repository: repository,
        fit: BoxFit.contain,
        semanticLabel: widget.media.title,
        loadingBuilder: (context) {
          return const _MediaViewerLoading(label: '加载图片…');
        },
        errorBuilder: (context, error, retry) {
          return _MediaViewerLoadError(message: '图片加载失败', onRetry: retry);
        },
        loadedBuilder: (context, content, image) {
          return GestureDetector(
            key: const ValueKey('media-image-viewer'),
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) {
              _doubleTapPosition = details.localPosition;
            },
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              key: const ValueKey('media-image-interactive-viewer'),
              transformationController: _transformationController,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(child: image),
            ),
          );
        },
      ),
    );
  }
}

class _MediaViewerLoading extends StatelessWidget {
  const _MediaViewerLoading({required this.label, this.darkBackground = true});

  final String label;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('media-viewer-loading'),
      child: SingleChildScrollView(
        child: ProductLoadingView(
          label: label,
          foreground: darkBackground ? MomCozyColors.onMediaSecondary : null,
        ),
      ),
    );
  }
}

class _MediaViewerLoadError extends StatelessWidget {
  const _MediaViewerLoadError({
    required this.message,
    this.onRetry,
    this.darkBackground = true,
    this.icon = Icons.broken_image_outlined,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool darkBackground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final foreground = darkBackground
        ? MomCozyColors.onMediaSecondary
        : MomCozyColors.mutedForeground;
    return ColoredBox(
      color: darkBackground
          ? MomCozyColors.mediaBackground
          : MomCozyColors.background,
      child: Center(
        key: const ValueKey('media-viewer-load-error'),
        child: SingleChildScrollView(
          child: ProductEmptyView(
            title: message,
            icon: icon,
            foreground: foreground,
            action: onRetry == null
                ? null
                : IconButton(
                    key: const ValueKey('media-viewer-retry'),
                    tooltip: '重新加载',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    color: foreground,
                  ),
          ),
        ),
      ),
    );
  }
}

class _VideoViewerStage extends StatelessWidget {
  const _VideoViewerStage({required this.media});

  final _MediaViewerRouteState media;

  @override
  Widget build(BuildContext context) {
    final reference = ProductAssetReference.tryParse(
      media.url,
      kind: media.kind,
      title: media.title,
    );
    final repository = MomCozyRuntimeScope.maybeOf(
      context,
    )?.productAssetRepository;
    if (reference == null || repository == null) {
      return const _MediaViewerLoadError(
        message: '视频加载失败',
        icon: Icons.videocam_off_outlined,
      );
    }
    return ProductAssetVideoPlayer(
      reference: reference,
      repository: repository,
    );
  }
}

class _MediaViewerRouteState {
  const _MediaViewerRouteState({
    required this.kind,
    required this.url,
    required this.title,
  });

  final String kind;
  final String url;
  final String title;

  static const _supportedKinds = {'pdf', 'image', 'video'};

  static _MediaViewerRouteState? from({
    required Uri? routeUri,
    required Object? routeExtra,
  }) {
    final extra = routeExtra is Map ? routeExtra : null;
    final query = routeUri?.queryParameters ?? const <String, String>{};
    final kind = _normalizeKind(
      _stringFromMap(extra, 'kind') ?? _stringFromQuery(query, 'kind'),
    );
    final url = _nonEmpty(
      _stringFromMap(extra, 'url') ?? _stringFromQuery(query, 'url'),
    );
    if (kind == null || url == null) return null;
    final title =
        _nonEmpty(
          _stringFromMap(extra, 'title') ?? _stringFromQuery(query, 'title'),
        ) ??
        _defaultTitleForKind(kind);
    return _MediaViewerRouteState(kind: kind, url: url, title: title);
  }

  static String? _normalizeKind(String? value) {
    final normalized = _nonEmpty(value)?.toLowerCase();
    if (normalized == null || !_supportedKinds.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _stringFromMap(Map<Object?, Object?>? map, String key) {
    final value = map?[key];
    return value is String ? value : null;
  }

  static String? _stringFromQuery(Map<String, String> query, String key) {
    final value = query[key];
    return value;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultTitleForKind(String kind) {
    return switch (kind) {
      'image' => '图片',
      'video' => '视频',
      _ => 'PDF',
    };
  }
}
