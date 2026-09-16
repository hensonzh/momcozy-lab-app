import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';

/// Local message actions. Retry is supplied only when the existing run permits it.
class AgentMessageMenu extends StatefulWidget {
  const AgentMessageMenu({
    super.key,
    required this.text,
    required this.child,
    this.enabled = true,
    this.onRetry,
  });

  final String text;
  final Widget child;
  final bool enabled;
  final VoidCallback? onRetry;

  @override
  State<AgentMessageMenu> createState() => _AgentMessageMenuState();
}

enum _MessageAction { copy, retry }

class _AgentMessageMenuState extends State<AgentMessageMenu> {
  final _focus = FocusNode(debugLabel: 'Agent message');
  bool _open = false;

  bool get _available =>
      widget.enabled &&
      (widget.text.trim().isNotEmpty || widget.onRetry != null);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (!_available || _open) return;
    final text = widget.text;
    final retry = widget.onRetry;
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    _focus.requestFocus();
    _open = true;
    final action = await showMenu<_MessageAction>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      requestFocus: true,
      semanticLabel: '消息操作',
      color: MomHomeTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: MomHomeTokens.ink.withValues(alpha: .12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: MomHomeTokens.border),
      ),
      constraints: const BoxConstraints(minWidth: 176, maxWidth: 280),
      popUpAnimationStyle: MomCozyMotion.animationStyle(context),
      items: [
        if (text.trim().isNotEmpty)
          _item(_MessageAction.copy, '复制', Icons.content_copy_rounded),
        if (retry != null)
          _item(_MessageAction.retry, '重试', Icons.refresh_rounded),
      ],
    );
    _open = false;
    // The conversation may change while the route is open.
    if (!mounted || !_available || text != widget.text) return;
    if (action == _MessageAction.retry) {
      if (retry == widget.onRetry) retry?.call();
    } else if (action == _MessageAction.copy) {
      try {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) _feedback('已复制');
      } catch (_) {
        if (mounted) _feedback('复制失败，请重试');
      }
    }
  }

  PopupMenuItem<_MessageAction> _item(
    _MessageAction action,
    String label,
    IconData icon,
  ) => PopupMenuItem(
    key: ValueKey('agent-message-${action.name}'),
    value: action,
    height: MomCozyTapTargets.minimum,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MomHomeTokens.teal),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: MomHomeTokens.text(14, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  void _feedback(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: MomHomeTokens.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          message,
          style: MomHomeTokens.text(14, color: MomHomeTokens.surface),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: _available
        ? {
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): _show,
            const SingleActivator(LogicalKeyboardKey.contextMenu): _show,
          }
        : {},
    child: Focus(
      focusNode: _focus,
      canRequestFocus: _available,
      child: Semantics(
        customSemanticsActions: _available
            ? {CustomSemanticsAction(label: '消息操作'): _show}
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: _available ? _show : null,
          onSecondaryTap: _available ? _show : null,
          child: widget.child,
        ),
      ),
    ),
  );
}
