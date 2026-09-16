import 'package:flutter/material.dart';
import '../../../shared/design_system/momcozy_design_system.dart';

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
          tooltip: '上一页',
          onPressed: ready && page > 1 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            ready ? '第 $page / $pageCount 页' : '正在打开…',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: MomCozyColors.foreground,
            ),
          ),
        ),
        IconButton(
          tooltip: '下一页',
          onPressed: ready && page < pageCount ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
    final zoom = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '缩小文档',
          onPressed: ready ? onZoomOut : null,
          icon: const Icon(Icons.zoom_out),
        ),
        IconButton(
          tooltip: '放大文档',
          onPressed: ready ? onZoomIn : null,
          icon: const Icon(Icons.zoom_in),
        ),
      ],
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MomCozyColors.background,
        border: Border(top: BorderSide(color: MomCozyColors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: MediaQuery.textScalerOf(context).scale(1) > 1.4
            ? Column(mainAxisSize: MainAxisSize.min, children: [pages, zoom])
            : Row(
                children: [
                  Expanded(child: pages),
                  const SizedBox(width: 8),
                  zoom,
                ],
              ),
      ),
    );
  }
}
