import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({
    super.key,
    this.state = const AgentStreamRunState(),
    this.runner,
    this.cancelClient,
    this.requestBuilder = buildDefaultAgentHubRequest,
  });

  final AgentStreamRunState state;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;
  final AgentHubRequestBuilder requestBuilder;

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage> {
  late AgentStreamRunState _state = widget.state;
  late final TextEditingController _composerController =
      TextEditingController();
  StreamSubscription<AgentStreamRunState>? _runSubscription;
  AgentStreamRequest? _activeRequest;

  @override
  void didUpdateWidget(covariant AgentHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state &&
        (widget.runner == null || !_state.isActive)) {
      _state = widget.state;
    }
  }

  @override
  void dispose() {
    _cancelRunSubscription();
    _composerController.dispose();
    super.dispose();
  }

  bool get _canSend =>
      widget.runner != null &&
      !_state.isActive &&
      _composerController.text.trim().isNotEmpty;

  Future<void> _sendMessage() async {
    final runner = widget.runner;
    final message = _composerController.text.trim();
    if (runner == null || message.isEmpty || _state.isActive) return;

    await _runSubscription?.cancel();
    _runSubscription = null;
    final request = widget.requestBuilder(message);
    _activeRequest = request;
    _composerController.clear();
    setState(() {
      _state = const AgentStreamRunState().start();
    });

    _runSubscription = runner
        .run(request)
        .listen(
          (nextState) {
            if (!mounted || !_state.isActive) return;
            setState(() {
              _state = nextState;
            });
          },
          onError: (Object error) {
            if (!mounted || !_state.isActive) return;
            setState(() {
              _state = _state.markDisconnected(error);
            });
          },
        );
  }

  void _cancelRun() {
    if (!_state.isActive) return;
    final activeState = _state;
    final activeRequest = _activeRequest;
    setState(() {
      _state = _state.requestCancel();
    });
    _cancelRunSubscription();
    setState(() {
      _state = _state.applyCancelResult(acknowledged: true);
    });
    _sendBestEffortServerCancel(activeState, activeRequest);
  }

  void _cancelRunSubscription() {
    final subscription = _runSubscription;
    _runSubscription = null;
    if (subscription == null) return;
    unawaited(subscription.cancel().catchError((Object _) {}));
  }

  void _sendBestEffortServerCancel(
    AgentStreamRunState activeState,
    AgentStreamRequest? activeRequest,
  ) {
    final cancelClient = widget.cancelClient;
    if (cancelClient == null) return;

    final threadId = activeState.threadId ?? activeRequest?.threadId;
    if (threadId == null || threadId.trim().isEmpty) return;

    unawaited(
      cancelClient.cancel(
        AgentStreamCancelRequest(
          threadId: threadId,
          runId: activeState.runId,
          userId: activeRequest?.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      key: const ValueKey('agent-hub-page'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '智能体',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AgentRunPhaseBadge(phase: _state.phase),
          ],
        ),
        const SizedBox(height: 18),
        AgentRunTranscript(state: _state),
        const SizedBox(height: 16),
        AgentComposerBar(
          controller: _composerController,
          canSend: _canSend,
          isRunning: _state.isActive,
          onChanged: (_) => setState(() {}),
          onSend: _sendMessage,
          onCancel: _cancelRun,
        ),
      ],
    );
  }
}

class AgentRunPhaseBadge extends StatelessWidget {
  const AgentRunPhaseBadge({super.key, required this.phase});

  final AgentStreamRunPhase phase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = _phaseForeground(colorScheme);
    final background = _phaseBackground(colorScheme);

    return Semantics(
      label: _phaseLabel,
      child: Container(
        key: const ValueKey('agent-run-phase-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_phaseIcon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              _phaseLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _phaseLabel {
    return switch (phase) {
      AgentStreamRunPhase.idle => '准备就绪',
      AgentStreamRunPhase.streaming => '正在回复',
      AgentStreamRunPhase.finished => '已完成',
      AgentStreamRunPhase.error => '需要重试',
      AgentStreamRunPhase.disconnected => '连接中断',
      AgentStreamRunPhase.cancelRequested => '正在停止',
      AgentStreamRunPhase.cancelled => '已停止',
    };
  }

  IconData get _phaseIcon {
    return switch (phase) {
      AgentStreamRunPhase.idle => Icons.bolt_outlined,
      AgentStreamRunPhase.streaming => Icons.sync_rounded,
      AgentStreamRunPhase.finished => Icons.check_circle_outline_rounded,
      AgentStreamRunPhase.error => Icons.error_outline_rounded,
      AgentStreamRunPhase.disconnected => Icons.wifi_off_rounded,
      AgentStreamRunPhase.cancelRequested => Icons.stop_circle_outlined,
      AgentStreamRunPhase.cancelled => Icons.pause_circle_outline_rounded,
    };
  }

  Color _phaseForeground(ColorScheme colorScheme) {
    return switch (phase) {
      AgentStreamRunPhase.error ||
      AgentStreamRunPhase.disconnected => colorScheme.error,
      AgentStreamRunPhase.finished => colorScheme.primary,
      AgentStreamRunPhase.cancelRequested ||
      AgentStreamRunPhase.cancelled => colorScheme.onSurfaceVariant,
      _ => colorScheme.primary,
    };
  }

  Color _phaseBackground(ColorScheme colorScheme) {
    return switch (phase) {
      AgentStreamRunPhase.error || AgentStreamRunPhase.disconnected =>
        colorScheme.errorContainer.withValues(alpha: 0.5),
      AgentStreamRunPhase.cancelRequested ||
      AgentStreamRunPhase.cancelled => colorScheme.surfaceContainerHighest,
      _ => colorScheme.primaryContainer.withValues(alpha: 0.58),
    };
  }
}

class AgentRunTranscript extends StatelessWidget {
  const AgentRunTranscript({super.key, required this.state});

  final AgentStreamRunState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = state.textContent.trim().isEmpty
        ? '我在。'
        : state.textContent.trim();

    return DecoratedBox(
      key: const ValueKey('agent-run-transcript'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: textTheme.bodyLarge?.copyWith(
                height: 1.42,
                color: colorScheme.onSurface,
              ),
            ),
            if (_supportingText != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _supportingIcon,
                    size: 18,
                    color: _supportingColor(colorScheme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _supportingText!,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? get _supportingText {
    if (state.phase == AgentStreamRunPhase.streaming) return '正在生成回复';
    if (state.phase == AgentStreamRunPhase.disconnected) {
      return state.errorMessage ?? '连接中断';
    }
    if (state.phase == AgentStreamRunPhase.error) {
      return state.errorMessage ?? '回复失败';
    }
    if (state.phase == AgentStreamRunPhase.cancelled) return '已停止本次回复';
    return null;
  }

  IconData get _supportingIcon {
    return switch (state.phase) {
      AgentStreamRunPhase.streaming => Icons.more_horiz_rounded,
      AgentStreamRunPhase.disconnected => Icons.wifi_off_rounded,
      AgentStreamRunPhase.error => Icons.error_outline_rounded,
      AgentStreamRunPhase.cancelled => Icons.pause_circle_outline_rounded,
      _ => Icons.info_outline_rounded,
    };
  }

  Color _supportingColor(ColorScheme colorScheme) {
    return switch (state.phase) {
      AgentStreamRunPhase.disconnected ||
      AgentStreamRunPhase.error => colorScheme.error,
      _ => colorScheme.primary,
    };
  }
}

class AgentComposerBar extends StatelessWidget {
  const AgentComposerBar({
    super.key,
    required this.controller,
    required this.canSend,
    required this.isRunning,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isRunning;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('agent-composer-input'),
                controller: controller,
                minLines: 1,
                maxLines: 4,
                enabled: !isRunning,
                onChanged: onChanged,
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
                decoration: InputDecoration(
                  hintText: '说说今天的情况',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            IconButton.filled(
              key: ValueKey(
                isRunning ? 'agent-stop-button' : 'agent-send-button',
              ),
              onPressed: isRunning ? onCancel : (canSend ? onSend : null),
              icon: Icon(
                isRunning ? Icons.stop_rounded : Icons.arrow_upward_rounded,
              ),
              tooltip: isRunning ? '停止' : '发送',
            ),
          ],
        ),
      ),
    );
  }
}
