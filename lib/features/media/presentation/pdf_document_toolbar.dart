import 'package:flutter/material.dart';
import '../../../shared/design_system/mom_home_tokens.dart';

class PdfDocumentToolbar extends StatelessWidget {
  const PdfDocumentToolbar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onZoomIn,
    required this.onZoomOut,
  });
  final int page, pageCount;
  final VoidCallback onPrevious, onNext, onZoomIn, onZoomOut;

  @override
  Widget build(BuildContext context) {
    final ready = page > 0 && pageCount > 0;
    final pages = Row(
      children: [
        IconButton(
          style: _controlStyle,
          tooltip: 'Previous page',
          onPressed: ready && page > 1 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left, size: 22),
        ),
        Expanded(
          child: Text(
            ready ? 'Page $page of $pageCount' : 'Opening…',
            textAlign: TextAlign.center,
            style: MomHomeTokens.text(
              13,
              weight: FontWeight.w600,
              color: MomHomeTokens.secondary,
            ),
          ),
        ),
        IconButton(
          style: _controlStyle,
          tooltip: 'Next page',
          onPressed: ready && page < pageCount ? onNext : null,
          icon: const Icon(Icons.chevron_right, size: 22),
        ),
      ],
    );
    final zoom = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: _controlStyle,
          tooltip: 'Zoom out',
          onPressed: ready ? onZoomOut : null,
          icon: const Icon(Icons.zoom_out, size: 22),
        ),
        const SizedBox(width: 8),
        IconButton(
          style: _controlStyle,
          tooltip: 'Zoom in',
          onPressed: ready ? onZoomIn : null,
          icon: const Icon(Icons.zoom_in, size: 22),
        ),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomHomeTokens.surface,
        border: Border(top: BorderSide(color: MomHomeTokens.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [pages, const SizedBox(height: 8), zoom],
              )
            : Row(
                children: [
                  Expanded(child: pages),
                  const SizedBox(width: 14),
                  zoom,
                ],
              ),
      ),
    );
  }

  static final _controlStyle = IconButton.styleFrom(
    foregroundColor: MomHomeTokens.teal,
    backgroundColor: MomHomeTokens.mint,
    disabledForegroundColor: MomHomeTokens.secondary,
    disabledBackgroundColor: MomHomeTokens.neutralSurface,
    minimumSize: const Size.square(44),
    maximumSize: const Size.square(44),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
