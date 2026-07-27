import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/core/agent_stream/agent_stream_client.dart';
import 'package:app/features/agent_hub/domain/agent_image_input.dart';

class AgentSentImages extends StatelessWidget {
  const AgentSentImages({super.key, required this.images, this.loadImageBytes});

  final List<AgentStreamImageInput> images;
  final AgentHubImageBytesLoader? loadImageBytes;

  @override
  Widget build(BuildContext context) {
    final multiple = images.length > 1;
    final itemWidth = multiple ? 108.0 : 176.0;
    final itemHeight = multiple ? 108.0 : 132.0;
    return SizedBox(
      width: multiple ? 222 : itemWidth,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var index = 0; index < images.length; index++)
            GestureDetector(
              key: ValueKey('agent-sent-image-$index'),
              onTap: () => _showSentImage(
                context,
                images[index],
                loadImageBytes: loadImageBytes,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: _AgentDataUrlImage(
                    image: images[index],
                    loadImageBytes: loadImageBytes,
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AgentComposerImageAttachment extends StatelessWidget {
  const AgentComposerImageAttachment({
    super.key,
    required this.image,
    required this.removeButtonKey,
    required this.onRemove,
    this.loadImageBytes,
  });

  final AgentStreamImageInput image;
  final Key removeButtonKey;
  final VoidCallback? onRemove;
  final AgentHubImageBytesLoader? loadImageBytes;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MomCozyColors.muted,
                  border: Border.all(
                    color: MomCozyColors.border.withValues(alpha: 0.72),
                  ),
                ),
                child: _AgentDataUrlImage(
                  image: image,
                  loadImageBytes: loadImageBytes,
                  fit: BoxFit.cover,
                  cacheWidth: 192,
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              key: removeButtonKey,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 14),
              tooltip: '移除图片',
              color: Colors.white,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(24),
                minimumSize: const Size.square(24),
                maximumSize: const Size.square(24),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.black.withValues(alpha: 0.52),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showSentImage(
  BuildContext context,
  AgentStreamImageInput image, {
  AgentHubImageBytesLoader? loadImageBytes,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: _AgentDataUrlImage(
                      image: image,
                      loadImageBytes: loadImageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const ValueKey('agent-sent-image-close'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AgentDataUrlImage extends StatefulWidget {
  const _AgentDataUrlImage({
    required this.image,
    this.loadImageBytes,
    required this.fit,
    this.cacheWidth,
  });

  final AgentStreamImageInput image;
  final AgentHubImageBytesLoader? loadImageBytes;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  State<_AgentDataUrlImage> createState() => _AgentDataUrlImageState();
}

class _AgentDataUrlImageState extends State<_AgentDataUrlImage> {
  late Uint8List? _bytes;
  Future<Uint8List>? _assetBytes;

  @override
  void initState() {
    super.initState();
    _prepareImage();
  }

  @override
  void didUpdateWidget(covariant _AgentDataUrlImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.dataUrl != widget.image.dataUrl ||
        oldWidget.image.assetId != widget.image.assetId ||
        oldWidget.loadImageBytes != widget.loadImageBytes) {
      _prepareImage();
    }
  }

  void _prepareImage() {
    _bytes = _decodeDataUrl(widget.image.dataUrl);
    _assetBytes = null;
    final assetId = widget.image.assetId.trim();
    final loader = widget.loadImageBytes;
    if (_bytes == null && assetId.isNotEmpty && loader != null) {
      _assetBytes = loader(assetId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) return _memoryImage(bytes);
    final assetBytes = _assetBytes;
    if (assetBytes == null) return const _AgentImageFallback();
    return FutureBuilder<Uint8List>(
      future: assetBytes,
      builder: (context, snapshot) {
        final loadedBytes = snapshot.data;
        if (loadedBytes != null) return _memoryImage(loadedBytes);
        if (snapshot.hasError) return const _AgentImageFallback();
        return const ColoredBox(
          color: MomCozyColors.muted,
          child: Center(
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }

  Widget _memoryImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      key: const ValueKey('agent-image-bytes'),
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _AgentImageFallback(),
    );
  }
}

class _AgentImageFallback extends StatelessWidget {
  const _AgentImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: MomCozyColors.muted,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 20,
          color: MomCozyColors.mutedForeground,
        ),
      ),
    );
  }
}

Uint8List? _decodeDataUrl(String dataUrl) {
  final marker = dataUrl.indexOf(',');
  if (marker < 0 || !dataUrl.substring(0, marker).contains(';base64')) {
    return null;
  }
  try {
    return base64Decode(dataUrl.substring(marker + 1));
  } catch (_) {
    return null;
  }
}
