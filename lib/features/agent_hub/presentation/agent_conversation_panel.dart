import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';

typedef AgentConversationSelected = Future<bool> Function(String threadId);

Future<void> showAgentConversationPanel({
  required BuildContext context,
  required AgentConversationRepository repository,
  required String? activeThreadId,
  required ValueListenable<bool> canSwitchListenable,
  required AgentConversationSelected onSelected,
  required VoidCallback onDismissed,
}) async {
  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: MomCozyColors.overlay,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final panelWidth = math.min(360.0, screenWidth * 0.82);
      return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) onDismissed();
        },
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('agent-conversation-panel'),
            width: panelWidth,
            height: double.infinity,
            child: _AgentConversationPanel(
              repository: repository,
              activeThreadId: activeThreadId,
              canSwitchListenable: canSwitchListenable,
              onSelected: onSelected,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
  onDismissed();
}

class _AgentConversationPanel extends StatefulWidget {
  const _AgentConversationPanel({
    required this.repository,
    required this.activeThreadId,
    required this.canSwitchListenable,
    required this.onSelected,
  });

  final AgentConversationRepository repository;
  final String? activeThreadId;
  final ValueListenable<bool> canSwitchListenable;
  final AgentConversationSelected onSelected;

  @override
  State<_AgentConversationPanel> createState() =>
      _AgentConversationPanelState();
}

class _AgentConversationPanelState extends State<_AgentConversationPanel> {
  List<AgentConversationSummary>? _conversations;
  Object? _loadError;
  bool _switchFailed = false;
  String? _loadingThreadId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _conversations = null;
      _loadError = null;
    });
    try {
      final conversations = await widget.repository.listConversations();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _select(AgentConversationSummary conversation) async {
    if (_loadingThreadId != null) return;
    if (conversation.id == widget.activeThreadId) {
      Navigator.of(context).pop();
      return;
    }
    if (!widget.canSwitchListenable.value) return;

    setState(() {
      _loadingThreadId = conversation.id;
      _switchFailed = false;
    });
    try {
      final switched = await widget.onSelected(conversation.id);
      if (!mounted) return;
      if (switched) {
        Navigator.of(context).pop();
      } else {
        setState(() => _switchFailed = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _switchFailed = true);
    } finally {
      if (mounted) setState(() => _loadingThreadId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.canSwitchListenable,
      builder: (context, canSwitch, child) =>
          _buildPanel(context, canSwitch: canSwitch),
    );
  }

  Widget _buildPanel(BuildContext context, {required bool canSwitch}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -300) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: MomCozyColors.background,
        elevation: 18,
        shadowColor: MomCozyColors.overlay,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(MomCozyRadii.sheet),
          bottomRight: Radius.circular(MomCozyRadii.sheet),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '会话历史',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: MomCozyColors.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('agent-conversation-close-button'),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭会话历史',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: MomCozyColors.border),
              if (!canSwitch)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Text(
                    '回复完成后可切换会话',
                    style: TextStyle(
                      color: MomCozyColors.mutedForeground,
                      fontSize: MomCozyTypography.captionSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Expanded(child: _buildContent(context, canSwitch: canSwitch)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool canSwitch}) {
    final conversations = _conversations;
    if (conversations == null && _loadError == null) {
      return const ProductLoadingView(
        key: ValueKey('agent-conversation-loading'),
      );
    }
    if (conversations == null) {
      return Center(
        child: ProductEmptyView(
          icon: Icons.cloud_off_outlined,
          title: '暂时无法加载会话',
          action: TextButton(onPressed: _load, child: const Text('重试')),
        ),
      );
    }
    if (conversations.isEmpty) {
      return const Center(
        child: ProductEmptyView(
          icon: Icons.chat_bubble_outline_rounded,
          title: '还没有历史会话',
        ),
      );
    }

    return Column(
      children: [
        if (_switchFailed)
          const Padding(
            key: ValueKey('agent-conversation-switch-error'),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              '无法打开该会话，请重试',
              style: TextStyle(
                color: MomCozyColors.danger,
                fontSize: MomCozyTypography.captionSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('agent-conversation-list'),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: conversations.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final isCurrent = conversation.id == widget.activeThreadId;
              final isLoading = conversation.id == _loadingThreadId;
              return Semantics(
                selected: isCurrent,
                button: true,
                child: Material(
                  color: isCurrent
                      ? MomCozyColors.roseSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(MomCozyRadii.control),
                  child: InkWell(
                    key: ValueKey('agent-conversation-${conversation.id}'),
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    onTap: isLoading || (!canSwitch && !isCurrent)
                        ? null
                        : () => _select(conversation),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: isCurrent
                                ? MomCozyColors.primaryDark
                                : MomCozyColors.mutedForeground,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  conversation.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MomCozyColors.foreground,
                                    fontSize: MomCozyTypography.bodySize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatUpdatedAt(conversation.updatedAt),
                                  style: const TextStyle(
                                    color: MomCozyColors.mutedForeground,
                                    fontSize: MomCozyTypography.labelSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
