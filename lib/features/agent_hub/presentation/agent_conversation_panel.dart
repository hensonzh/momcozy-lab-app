import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_settings_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_settings_widgets.dart';
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
  var dismissed = false;
  void dismissOnce() {
    if (dismissed) return;
    dismissed = true;
    onDismissed();
  }

  final barrierLabel = MaterialLocalizations.of(
    context,
  ).modalBarrierDismissLabel;
  await showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: const Color(0x520f0a0d),
    transitionDuration: MomCozyMotion.duration(
      context,
      const Duration(milliseconds: 240),
    ),
    pageBuilder: (context, animation, secondaryAnimation) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      final panelWidth = math.min(360.0, screenWidth - 24);
      return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) dismissOnce();
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
      if (MediaQuery.disableAnimationsOf(context)) return child;
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
  dismissOnce();
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
    return Theme(
      data: momSettingsTheme(Theme.of(context)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -300) {
            Navigator.of(context).pop();
          }
        },
        child: Material(
          color: MomHomeTokens.background,
          elevation: 18,
          shadowColor: const Color(0x520f0a0d),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(MomHomeTokens.cardRadius),
            bottomRight: Radius.circular(MomHomeTokens.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: MomHomeTokens.surface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '会话历史',
                            style: MomHomeTokens.text(
                              20,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 44,
                          child: IconButton(
                            key: const ValueKey(
                              'agent-conversation-close-button',
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: '关闭会话历史',
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: MomHomeTokens.rose,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _buildContent(context, canSwitch: canSwitch)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(String message, {bool error = false, Key? key}) => Semantics(
    liveRegion: true,
    child: Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFF8ECD8) : MomHomeTokens.neutralSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: MomHomeTokens.text(13, height: 1.55)),
    ),
  );

  Widget _buildContent(BuildContext context, {required bool canSwitch}) {
    final conversations = _conversations;
    final notices = <Widget>[
      if (!canSwitch) _notice('回复完成后可切换会话'),
      if (_switchFailed)
        _notice(
          '无法打开该会话，请重试',
          error: true,
          key: const ValueKey('agent-conversation-switch-error'),
        ),
    ];
    if (conversations == null || conversations.isEmpty) {
      final Widget status;
      if (conversations == null && _loadError == null) {
        status = Semantics(
          liveRegion: true,
          child: MomSettingsCard(
            key: const ValueKey('agent-conversation-loading'),
            children: [
              Text(
                '正在加载会话',
                style: MomHomeTokens.text(16, weight: FontWeight.w700),
              ),
              const LinearProgressIndicator(),
            ],
          ),
        );
      } else if (conversations == null) {
        status = MomSettingsCard(
          children: [
            Text(
              '暂时无法加载会话',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        );
      } else {
        status = MomSettingsCard(
          children: [
            Text(
              '还没有历史会话',
              style: MomHomeTokens.text(16, weight: FontWeight.w700),
            ),
            Text(
              '你可以关闭此面板，继续和 Cozymate 聊聊。',
              style: MomHomeTokens.text(
                13,
                color: MomHomeTokens.secondary,
                height: 1.55,
              ),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(MomHomeTokens.inset),
        children: [
          for (final notice in notices) ...[
            notice,
            const SizedBox(height: MomHomeTokens.gap),
          ],
          status,
        ],
      );
    }

    return ListView.separated(
      key: const ValueKey('agent-conversation-list'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: notices.length + conversations.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: MomHomeTokens.gap),
      itemBuilder: (context, index) {
        if (index < notices.length) return notices[index];
        final conversation = conversations[index - notices.length];
        final isCurrent = conversation.id == widget.activeThreadId;
        final isLoading = conversation.id == _loadingThreadId;
        final enabled = _loadingThreadId == null && (canSwitch || isCurrent);
        return _ConversationCard(
          conversation: conversation,
          current: isCurrent,
          loading: isLoading,
          enabled: enabled,
          onTap: enabled ? () => _select(conversation) : null,
        );
      },
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.current,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });
  final AgentConversationSummary conversation;
  final bool current;
  final bool loading;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    return Semantics(
      selected: current,
      button: true,
      enabled: enabled,
      child: Material(
        color: current ? MomHomeTokens.mint : MomHomeTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MomHomeTokens.cardRadius),
          side: const BorderSide(color: MomHomeTokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('agent-conversation-${conversation.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    conversation.title,
                    maxLines: largeText ? null : 2,
                    overflow: largeText ? null : TextOverflow.ellipsis,
                    style: MomHomeTokens.text(
                      14,
                      weight: FontWeight.w700,
                      color: enabled || loading
                          ? MomHomeTokens.ink
                          : MomHomeTokens.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatUpdatedAt(conversation.updatedAt),
                    style: MomHomeTokens.text(
                      12,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(height: 6),
                    Text(
                      '✓ 当前会话',
                      style: MomHomeTokens.text(
                        12,
                        weight: FontWeight.w700,
                        color: MomHomeTokens.teal,
                      ),
                    ),
                  ],
                  if (loading) ...[
                    const SizedBox(height: 6),
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '正在打开…',
                              style: MomHomeTokens.text(
                                12,
                                color: MomHomeTokens.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatUpdatedAt(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day} $hour:$minute';
}
