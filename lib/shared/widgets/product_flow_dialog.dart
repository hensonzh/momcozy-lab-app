import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../design_system/momcozy_design_system.dart';

/// Product forms with a stable header and scrollable content.
class ProductFlowDialog extends StatelessWidget {
  const ProductFlowDialog({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.child,
    this.maxHeight = 720,
    this.minHeight = 0,
    this.scrollController,
    this.showClose = true,
    this.alignment = Alignment.bottomCenter,
  }) : _expert = false;
  const ProductFlowDialog.expert({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
    required this.child,
  }) : maxHeight = 650,
       minHeight = 0,
       scrollController = null,
       showClose = true,
       alignment = Alignment.center,
       _expert = true;
  final bool _expert;
  final String title, closeLabel;
  final VoidCallback? onClose;
  final Widget child;
  final double maxHeight;
  final double minHeight;
  final ScrollController? scrollController;
  final bool showClose;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Dialog(
    alignment: alignment,
    insetPadding: EdgeInsets.all(_expert ? 12 : 18),
    backgroundColor: _expert ? MomCozyColors.expertSurface : MomCozyColors.card,
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_expert ? 18 : 24),
      side: BorderSide(
        color: _expert ? MomCozyColors.expertBorder : MomCozyColors.border,
      ),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _expert ? 360 : 440,
        minHeight: math.min(
          minHeight,
          math.min(
            maxHeight,
            MediaQuery.sizeOf(context).height * (_expert ? .85 : .92),
          ),
        ),
        maxHeight: math.min(
          maxHeight,
          MediaQuery.sizeOf(context).height * (_expert ? .85 : .92),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: _expert ? 19 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showClose) const SizedBox(width: 8),
                if (showClose)
                  Tooltip(
                    message: closeLabel,
                    child: _expert
                        ? IconButton(
                            onPressed: onClose,
                            icon: const Icon(
                              Icons.close,
                              size: 24,
                              color: MomCozyColors.expertMuted,
                            ),
                          )
                        : TextButton(
                            onPressed: onClose,
                            style: TextButton.styleFrom(
                              foregroundColor: MomCozyColors.mutedForeground,
                              minimumSize: const Size(44, 44),
                            ),
                            child: const Text('关闭'),
                          ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _expert
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        child,
                      ],
                    )
                  : child,
            ),
          ),
        ],
      ),
    ),
  );
}
