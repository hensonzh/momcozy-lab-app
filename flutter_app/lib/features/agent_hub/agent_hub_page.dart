import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);
typedef AgentHubImagePicker = Future<AgentStreamImageInput?> Function();
typedef AgentHubVoiceInput = Future<String?> Function();
typedef AgentArtifactActionHandler =
    void Function(AgentArtifactActionView action);
typedef AgentHubNewSessionHandler = void Function();

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({
    super.key,
    this.state = const AgentStreamRunState(),
    this.historyMessages = const <AgentHubHistoryMessage>[],
    this.runner,
    this.cancelClient,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.voiceInput,
    this.voiceInputController,
    this.voicePlaybackCoordinator,
    this.onArtifactAction,
    this.onNewSession,
  });

  final AgentStreamRunState state;
  final List<AgentHubHistoryMessage> historyMessages;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubVoiceInput? voiceInput;
  final AgentVoiceInputController? voiceInputController;
  final AgentVoicePlaybackCoordinator? voicePlaybackCoordinator;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentHubNewSessionHandler? onNewSession;

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage> {
  late AgentStreamRunState _state = widget.state;
  late List<AgentHubHistoryMessage> _historyMessages = [
    ...widget.historyMessages,
  ];
  late final TextEditingController _composerController =
      TextEditingController();
  StreamSubscription<AgentStreamRunState>? _runSubscription;
  AgentStreamRequest? _activeRequest;
  AgentVoiceState _voiceState = const AgentVoiceState();
  final List<AgentStreamImageInput> _attachedImages = <AgentStreamImageInput>[];

  @override
  void didUpdateWidget(covariant AgentHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state &&
        (widget.runner == null || !_state.isActive)) {
      _state = widget.state;
    }
    if (oldWidget.historyMessages != widget.historyMessages &&
        !_state.isActive) {
      _historyMessages = [...widget.historyMessages];
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
      (_composerController.text.trim().isNotEmpty ||
          _attachedImages.isNotEmpty);

  bool get _canRetry =>
      widget.runner != null && _state.canRetry && _activeRequest != null;

  Future<void> _sendMessage() async {
    final runner = widget.runner;
    final message = _composerController.text.trim();
    if (runner == null ||
        (message.isEmpty && _attachedImages.isEmpty) ||
        _state.isActive) {
      return;
    }

    final request = _requestWithImages(
      widget.requestBuilder(message),
      _attachedImages,
    );
    _composerController.clear();
    setState(() {
      _attachedImages.clear();
    });
    await _startRun(request);
  }

  Future<void> _attachImage() async {
    final pickImage = widget.pickImage;
    if (pickImage == null || _state.isActive) return;
    final image = await pickImage();
    if (!mounted || image == null) return;
    setState(() {
      _attachedImages.add(image);
    });
  }

  Future<void> _startVoiceInput() async {
    if ((widget.voiceInputController == null && widget.voiceInput == null) ||
        _state.isActive ||
        _voiceState.isInputActive) {
      return;
    }

    setState(() {
      _voiceState = _voiceState.startListening();
    });

    try {
      setState(() {
        _voiceState = _voiceState.startTranscribing(
          draft: _composerController.text,
        );
      });
      final result = await _captureVoiceInput();
      if (!mounted) return;
      setState(() {
        if (result.status == AgentVoiceInputResultStatus.permissionDenied) {
          _voiceState = _voiceState.markPermissionDenied(
            result.permissionState ?? AgentVoiceInputPermissionState.denied,
          );
          return;
        }

        final text = result.text;
        if (text != null && text.isNotEmpty) {
          _composerController.text = text;
          _composerController.selection = TextSelection.collapsed(
            offset: _composerController.text.length,
          );
        }
        _voiceState = _voiceState.applyTranscription(text ?? '');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _voiceState = _voiceState.fail(error);
      });
    }
  }

  Future<AgentVoiceInputResult> _captureVoiceInput() async {
    final controller = widget.voiceInputController;
    if (controller != null) {
      return controller.captureAndTranscribe();
    }

    return AgentVoiceInputResult.fromText(await widget.voiceInput?.call());
  }

  void _removeAttachedImages() {
    setState(() {
      _attachedImages.clear();
    });
  }

  void _startNewSession() {
    if (_state.isActive) return;
    _cancelRunSubscription();
    _composerController.clear();
    setState(() {
      _state = const AgentStreamRunState();
      _historyMessages.clear();
      _attachedImages.clear();
      _activeRequest = null;
      _voiceState = const AgentVoiceState();
    });
    widget.onNewSession?.call();
  }

  Future<void> _retryRun() async {
    final request = _activeRequest;
    if (request == null || widget.runner == null || !_state.canRetry) return;
    await _startRun(request);
  }

  Future<void> _startRun(AgentStreamRequest request) async {
    final runner = widget.runner;
    if (runner == null || _state.isActive) return;

    _cancelRunSubscription();
    _activeRequest = request;
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
            _maybeStartAutoVoicePlayback(nextState);
          },
          onError: (Object error) {
            if (!mounted || !_state.isActive) return;
            setState(() {
              _state = _state.markDisconnected(error);
            });
          },
        );
  }

  void _maybeStartAutoVoicePlayback(AgentStreamRunState nextState) {
    final coordinator = widget.voicePlaybackCoordinator;
    final text = nextState.textContent.trim();
    if (coordinator == null ||
        nextState.phase != AgentStreamRunPhase.finished ||
        text.isEmpty) {
      return;
    }

    final playbackId =
        nextState.messageId ?? nextState.runId ?? nextState.threadId ?? '';
    final result = coordinator.request(
      id: playbackId,
      source: AgentVoicePlaybackSource.autoReply,
    );
    final handle = result.handle;
    if (!mounted ||
        result.status != AgentVoicePlaybackRequestStatus.started ||
        handle == null) {
      return;
    }
    setState(() {
      _voiceState = _voiceState.startPlayback(handle.id);
    });
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
            IconButton(
              key: const ValueKey('agent-new-session-button'),
              onPressed: _state.isActive ? null : _startNewSession,
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: '新会话',
            ),
            const SizedBox(width: 4),
            AgentRunPhaseBadge(phase: _state.phase),
          ],
        ),
        const SizedBox(height: 18),
        if (_historyMessages.isNotEmpty) ...[
          AgentHubHistoryPanel(messages: _historyMessages),
          const SizedBox(height: 16),
        ],
        AgentRunTranscript(
          state: _state,
          canRetry: _canRetry,
          onRetry: _retryRun,
          onArtifactAction: widget.onArtifactAction,
        ),
        const SizedBox(height: 16),
        AgentComposerBar(
          controller: _composerController,
          canSend: _canSend,
          isRunning: _state.isActive,
          imageCount: _attachedImages.length,
          canAttachImage: widget.pickImage != null && !_state.isActive,
          canUseVoice:
              (widget.voiceInputController != null ||
                  widget.voiceInput != null) &&
              !_state.isActive &&
              !_voiceState.isInputActive,
          voicePhase: _voiceState.phase,
          onChanged: (_) => setState(() {}),
          onSend: _sendMessage,
          onCancel: _cancelRun,
          onAttachImage: _attachImage,
          onRemoveImages: _removeAttachedImages,
          onVoiceInput: _startVoiceInput,
        ),
      ],
    );
  }
}

AgentStreamRequest _requestWithImages(
  AgentStreamRequest request,
  List<AgentStreamImageInput> images,
) {
  if (images.isEmpty) return request;
  return AgentStreamRequest(
    userId: request.userId,
    message: request.message,
    threadId: request.threadId,
    locale: request.locale,
    images: [...request.images, ...images],
    metadata: request.metadata,
  );
}

enum AgentHubHistoryRole { user, assistant }

class AgentHubHistoryMessage {
  const AgentHubHistoryMessage({required this.role, required this.content});

  final AgentHubHistoryRole role;
  final String content;

  String get roleLabel {
    return switch (role) {
      AgentHubHistoryRole.user => '我',
      AgentHubHistoryRole.assistant => '智能体',
    };
  }
}

class AgentHubHistoryPanel extends StatelessWidget {
  const AgentHubHistoryPanel({super.key, required this.messages});

  final List<AgentHubHistoryMessage> messages;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      key: const ValueKey('agent-history-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史会话',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < messages.length; index++) ...[
              Row(
                key: ValueKey('agent-history-$index'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messages[index].roleLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      messages[index].content,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (index != messages.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
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
  const AgentRunTranscript({
    super.key,
    required this.state,
    this.canRetry = false,
    this.onRetry,
    this.onArtifactAction,
  });

  final AgentStreamRunState state;
  final bool canRetry;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = state.textContent.trim().isEmpty
        ? '我在。'
        : state.textContent.trim();
    final workSteps = _workStepsFromEvents(state.events);
    final artifactCards = _artifactCardsFromEvents(state.events);

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
            if (canRetry) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('agent-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
            if (workSteps.isNotEmpty) ...[
              const SizedBox(height: 16),
              AgentRunWorkPanel(steps: workSteps),
            ],
            if (artifactCards.isNotEmpty) ...[
              const SizedBox(height: 16),
              AgentArtifactPanel(
                cards: artifactCards,
                onAction: onArtifactAction,
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
      return _safeAgentErrorText(state.errorMessage) ?? '连接中断';
    }
    if (state.phase == AgentStreamRunPhase.error) {
      return _safeAgentErrorText(state.errorMessage) ?? '回复失败';
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

class AgentRunWorkPanel extends StatelessWidget {
  const AgentRunWorkPanel({super.key, required this.steps});

  final List<AgentRunWorkStep> steps;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('agent-work-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '处理进度',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final step in steps) ...[
          Row(
            key: ValueKey('agent-work-step-${step.id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(step.icon, size: 18, color: step.color(colorScheme)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                step.statusLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: step.color(colorScheme),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (step != steps.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class AgentRunWorkStep {
  const AgentRunWorkStep({
    required this.id,
    required this.title,
    required this.status,
  });

  final String id;
  final String title;
  final AgentRunWorkStepStatus status;

  String get statusLabel {
    return switch (status) {
      AgentRunWorkStepStatus.running => '进行中',
      AgentRunWorkStepStatus.completed => '完成',
      AgentRunWorkStepStatus.waiting => '待确认',
      AgentRunWorkStepStatus.failed => '失败',
    };
  }

  IconData get icon {
    return switch (status) {
      AgentRunWorkStepStatus.running => Icons.sync_rounded,
      AgentRunWorkStepStatus.completed => Icons.check_circle_outline_rounded,
      AgentRunWorkStepStatus.waiting => Icons.fact_check_outlined,
      AgentRunWorkStepStatus.failed => Icons.error_outline_rounded,
    };
  }

  Color color(ColorScheme colorScheme) {
    return switch (status) {
      AgentRunWorkStepStatus.failed => colorScheme.error,
      AgentRunWorkStepStatus.waiting => colorScheme.tertiary,
      _ => colorScheme.primary,
    };
  }
}

enum AgentRunWorkStepStatus { running, completed, waiting, failed }

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({super.key, required this.cards, this.onAction});

  final List<AgentArtifactCardView> cards;
  final AgentArtifactActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('agent-artifact-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '结果卡片',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final card in cards) ...[
          DecoratedBox(
            key: ValueKey('agent-artifact-card-${card.id}'),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.48,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.dashboard_customize_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          card.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (card.statusLabel != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          card.statusLabel!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (card.content != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.content!,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  for (final row in card.rows) ...[
                    const SizedBox(height: 8),
                    Text(
                      row,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (card.actions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (
                          var index = 0;
                          index < card.actions.length;
                          index++
                        )
                          OutlinedButton.icon(
                            key: ValueKey(
                              'agent-artifact-action-${card.id}-$index',
                            ),
                            onPressed: () =>
                                onAction?.call(card.actions[index]),
                            icon: Icon(card.actions[index].icon),
                            label: Text(card.actions[index].label),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (card != cards.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class AgentArtifactCardView {
  const AgentArtifactCardView({
    required this.id,
    required this.title,
    this.content,
    this.statusLabel,
    this.rows = const <String>[],
    this.actions = const <AgentArtifactActionView>[],
  });

  final String id;
  final String title;
  final String? content;
  final String? statusLabel;
  final List<String> rows;
  final List<AgentArtifactActionView> actions;
}

class AgentArtifactActionView {
  const AgentArtifactActionView({
    required this.label,
    required this.icon,
    required this.kind,
    this.value,
    this.routePath,
  });

  final String label;
  final IconData icon;
  final String kind;
  final String? value;
  final String? routePath;
}

class AgentComposerBar extends StatelessWidget {
  const AgentComposerBar({
    super.key,
    required this.controller,
    required this.canSend,
    required this.isRunning,
    required this.imageCount,
    required this.canAttachImage,
    required this.canUseVoice,
    required this.voicePhase,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    required this.onAttachImage,
    required this.onRemoveImages,
    required this.onVoiceInput,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isRunning;
  final int imageCount;
  final bool canAttachImage;
  final bool canUseVoice;
  final AgentVoicePhase voicePhase;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onAttachImage;
  final VoidCallback onRemoveImages;
  final VoidCallback onVoiceInput;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageCount > 0) ...[
              Row(
                key: const ValueKey('agent-image-attachment-chip'),
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '图片 $imageCount',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('agent-remove-image-button'),
                    onPressed: isRunning ? null : onRemoveImages,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '移除图片',
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                IconButton(
                  key: const ValueKey('agent-image-button'),
                  onPressed: canAttachImage ? onAttachImage : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: '添加图片',
                ),
                IconButton(
                  key: const ValueKey('agent-voice-button'),
                  onPressed: canUseVoice ? onVoiceInput : null,
                  icon: Icon(_voiceIcon),
                  tooltip: _voiceTooltip,
                ),
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
            if (_voiceStatusLabel != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _voiceStatusLabel!,
                  key: const ValueKey('agent-voice-status'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        voicePhase == AgentVoicePhase.error ||
                            voicePhase == AgentVoicePhase.permissionDenied
                        ? colorScheme.error
                        : colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _voiceIcon {
    return switch (voicePhase) {
      AgentVoicePhase.listening => Icons.graphic_eq_rounded,
      AgentVoicePhase.transcribing => Icons.hourglass_bottom_rounded,
      AgentVoicePhase.playing => Icons.volume_up_outlined,
      AgentVoicePhase.permissionDenied => Icons.mic_off_outlined,
      AgentVoicePhase.error => Icons.mic_off_outlined,
      _ => Icons.mic_none_rounded,
    };
  }

  String get _voiceTooltip {
    return switch (voicePhase) {
      AgentVoicePhase.listening => '正在听',
      AgentVoicePhase.transcribing => '正在转写',
      AgentVoicePhase.playing => '正在播放语音',
      AgentVoicePhase.cancelled => '语音播放已停止',
      AgentVoicePhase.permissionDenied => '麦克风权限未开启',
      AgentVoicePhase.error => '语音失败',
      _ => '语音输入',
    };
  }

  String? get _voiceStatusLabel {
    return switch (voicePhase) {
      AgentVoicePhase.listening => '正在听',
      AgentVoicePhase.transcribing => '正在整理语音',
      AgentVoicePhase.playing => '正在播放语音',
      AgentVoicePhase.cancelled => '语音播放已停止',
      AgentVoicePhase.permissionDenied => '麦克风权限未开启',
      AgentVoicePhase.error => '语音输入失败',
      _ => null,
    };
  }
}

List<AgentArtifactCardView> _artifactCardsFromEvents(
  List<AgentStreamEvent> events,
) {
  final cards = <String, AgentArtifactCardView>{};
  for (final event in events) {
    final card = _artifactCardFromEvent(event);
    if (card != null) cards[card.id] = card;
  }
  return List<AgentArtifactCardView>.unmodifiable(cards.values);
}

AgentArtifactCardView? _artifactCardFromEvent(AgentStreamEvent event) {
  if (event.type != 'ARTIFACT_CREATED' && event.type != 'ARTIFACT_UPDATED') {
    return null;
  }

  final richText = _mapField(event.raw, 'rich_text', 'richText');
  final artifact = _mapField(event.raw, 'artifact');
  final cardJson = _mapField(artifact, 'card_json', 'cardJson');
  final artifactId =
      stringField(event.raw, 'artifact_id') ??
      stringField(event.raw, 'artifactId') ??
      stringField(artifact, 'id') ??
      event.mergeKey;

  final title =
      _firstNonEmpty([
        _stringField(richText, 'title'),
        _stringField(cardJson, 'title'),
        _artifactSubject(event),
      ]) ??
      '结果卡片';
  final content = _firstNonEmpty([_stringField(richText, 'content')]);
  final status = _firstNonEmpty([
    _stringField(cardJson, 'status_label', 'statusLabel'),
  ]);
  final rows = <String>[
    ..._stringList(cardJson['steps']),
    ..._richTextCardRows(richText['card']),
  ];
  final actions = <AgentArtifactActionView>[
    ..._buttonActions(richText['button']),
    ..._referenceActionsFromRichText(richText),
    ..._semanticActions(richText['action'], event),
  ];

  if (title.trim().isEmpty &&
      (content == null || content.trim().isEmpty) &&
      rows.isEmpty &&
      actions.isEmpty) {
    return null;
  }

  return AgentArtifactCardView(
    id: artifactId,
    title: title,
    content: content,
    statusLabel: status,
    rows: rows,
    actions: actions,
  );
}

List<String> _richTextCardRows(Object? rawCards) {
  if (rawCards is! List) return const <String>[];
  final rows = <String>[];
  for (final rawCard in rawCards) {
    if (rawCard is! Map) continue;
    final card = Map<String, Object?>.from(rawCard);
    final title = _firstNonEmpty([
      _stringField(card, 'title'),
      _stringField(card, 'label'),
    ]);
    if (title != null) rows.add(title);
    final content = card['content'];
    if (content is List) {
      for (final rawRow in content) {
        if (rawRow is! Map) continue;
        final row = Map<String, Object?>.from(rawRow);
        final rowTitle = _stringField(row, 'title');
        final rowContent = _stringField(row, 'content', 'value');
        final combined = _combineLabelValue(rowTitle, rowContent);
        if (combined != null) rows.add(combined);
      }
    }
  }
  return rows;
}

List<AgentArtifactActionView> _buttonActions(Object? rawButtons) {
  if (rawButtons is! List) return const <AgentArtifactActionView>[];
  return rawButtons
      .whereType<Map>()
      .map((rawButton) => Map<String, Object?>.from(rawButton))
      .map((button) {
        final kind = _firstNonEmpty([
          _stringField(button, 'type', 'kind'),
          _stringField(button, 'action'),
        ]);
        final value = _firstNonEmpty([
          _stringField(button, 'value'),
          _stringField(button, 'url'),
          _stringField(button, 'href'),
          _stringField(button, 'route'),
          _stringField(button, 'path'),
        ]);
        final label = _firstNonEmpty([
          _stringField(button, 'text'),
          _stringField(button, 'label'),
          _stringField(button, 'title'),
          '打开',
        ]);
        return AgentArtifactActionView(
          label: label ?? '打开',
          icon: _actionIcon(kind),
          kind: kind ?? 'button',
          value: value,
          routePath: _actionRoutePath(kind: kind, value: value),
        );
      })
      .toList(growable: false);
}

List<AgentArtifactActionView> _referenceActionsFromRichText(
  Map<String, Object?> richText,
) {
  return <AgentArtifactActionView>[
    ..._referenceActions(richText['citation']),
    ..._referenceActions(richText['citations']),
    ..._referenceActions(richText['reference']),
    ..._referenceActions(richText['references']),
  ];
}

List<AgentArtifactActionView> _referenceActions(Object? rawReferences) {
  final references = switch (rawReferences) {
    List value => value,
    Map value => [value],
    _ => const <Object?>[],
  };

  return references
      .whereType<Map>()
      .map((rawReference) => Map<String, Object?>.from(rawReference))
      .map((reference) {
        final value = _firstNonEmpty([
          _stringField(reference, 'url'),
          _stringField(reference, 'href'),
          _stringField(reference, 'value'),
        ]);
        final title =
            _firstNonEmpty([
              _stringField(reference, 'title'),
              _stringField(reference, 'label'),
              _stringField(reference, 'displayText'),
              _hostFromUrl(value),
            ]) ??
            '参考来源';
        return AgentArtifactActionView(
          label: _citationLabel(reference['index'], title),
          icon: _actionIcon('citation'),
          kind: 'citation',
          value: value,
        );
      })
      .toList(growable: false);
}

List<AgentArtifactActionView> _semanticActions(
  Object? rawActions,
  AgentStreamEvent event,
) {
  if (rawActions is! List) return const <AgentArtifactActionView>[];
  return rawActions
      .whereType<Map>()
      .map((rawAction) => Map<String, Object?>.from(rawAction))
      .map((action) {
        final kind = _stringField(action, 'kind', 'type');
        final value = _firstNonEmpty([
          _stringField(action, 'value'),
          _stringField(action, 'url'),
          _stringField(action, 'href'),
          _stringField(action, 'route'),
          _stringField(action, 'path'),
        ]);
        final label = _firstNonEmpty([
          _stringField(action, 'label'),
          _stringField(action, 'text'),
          kind == 'ag_ui_artifact' ? '打开${_artifactSubject(event)}' : null,
          '打开',
        ]);
        return AgentArtifactActionView(
          label: label ?? '打开',
          icon: _actionIcon(kind),
          kind: kind ?? 'action',
          value: value,
          routePath: _actionRoutePath(kind: kind, value: value),
        );
      })
      .toList(growable: false);
}

IconData _actionIcon(String? kind) {
  return switch (kind) {
    'doc' || 'document' || 'pdf' => Icons.description_outlined,
    'media' || 'image' || 'video' || 'open' => Icons.open_in_new_rounded,
    'citation' || 'reference' => Icons.link_rounded,
    'ag_ui_artifact' => Icons.fact_check_outlined,
    _ => Icons.touch_app_outlined,
  };
}

String? _actionRoutePath({required String? kind, required String? value}) {
  if (_isMediaActionKind(kind)) return '/media-viewer';
  return _safeSameOriginPath(value);
}

bool _isMediaActionKind(String? kind) {
  return switch (kind) {
    'doc' || 'document' || 'pdf' || 'media' || 'image' || 'video' => true,
    _ => false,
  };
}

String? _safeSameOriginPath(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path.isEmpty ? normalized : uri.path;
  if (!path.startsWith('/')) return null;
  return path;
}

String _citationLabel(Object? rawIndex, String title) {
  final index = switch (rawIndex) {
    int value => value.toString(),
    String value => value.trim(),
    _ => '',
  };
  return index.isEmpty ? title : '[$index] $title';
}

String? _hostFromUrl(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  final host = uri?.host.replaceFirst(RegExp(r'^www\.'), '');
  return host == null || host.isEmpty ? null : host;
}

Map<String, Object?> _mapField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  final value = map[key] ?? (alias == null ? null : map[alias]);
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String? _stringField(Map<String, Object?> map, String key, [String? alias]) {
  return stringField(map, key) ??
      (alias == null ? null : stringField(map, alias));
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _combineLabelValue(String? label, String? value) {
  final normalizedLabel = label?.trim();
  final normalizedValue = value?.trim();
  if (normalizedLabel != null &&
      normalizedLabel.isNotEmpty &&
      normalizedValue != null &&
      normalizedValue.isNotEmpty) {
    return '$normalizedLabel: $normalizedValue';
  }
  if (normalizedLabel != null && normalizedLabel.isNotEmpty) {
    return normalizedLabel;
  }
  if (normalizedValue != null && normalizedValue.isNotEmpty) {
    return normalizedValue;
  }
  return null;
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

String? _safeAgentErrorText(String? errorMessage) {
  final normalized = errorMessage?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final lower = normalized.toLowerCase();
  if (lower.contains('timeoutexception') || lower.contains('timeout')) {
    return '请求超时，请稍后重试';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('offline')) {
    return '网络不可用，请检查连接后重试';
  }
  return normalized;
}

List<AgentRunWorkStep> _workStepsFromEvents(List<AgentStreamEvent> events) {
  final steps = <String, AgentRunWorkStep>{};

  for (final event in events) {
    final step = _workStepFromEvent(event);
    if (step != null) steps[step.id] = step;
  }

  return List<AgentRunWorkStep>.unmodifiable(steps.values);
}

AgentRunWorkStep? _workStepFromEvent(AgentStreamEvent event) {
  return switch (event.type) {
    'CUSTOM' => _customStatusStep(event),
    'TOOL_CALL_START' ||
    'TOOL_CALL_ARGS' ||
    'TOOL_CALL_END' ||
    'TOOL_CALL_RESULT' ||
    'TOOL_CALL_ERROR' ||
    'TOOL_CALL_FAILED' => _toolStep(event),
    'ARTIFACT_CREATED' => _artifactStep(event),
    'CONFIRMATION_REQUIRED' => _confirmationStep(event),
    'RUN_ERROR' || 'RUN_FAILED' || 'ERROR' => AgentRunWorkStep(
      id: event.mergeKey,
      title: '处理遇到问题',
      status: AgentRunWorkStepStatus.failed,
    ),
    _ => null,
  };
}

AgentRunWorkStep? _customStatusStep(AgentStreamEvent event) {
  if (stringField(event.raw, 'name') != 'momcozy.agent.status') return null;
  return AgentRunWorkStep(
    id: event.mergeKey,
    title: '正在读取相关信息',
    status: AgentRunWorkStepStatus.running,
  );
}

AgentRunWorkStep _toolStep(AgentStreamEvent event) {
  final subject = _toolSubject(event);
  final failed = _toolFailed(event);
  final completed = event.type == 'TOOL_CALL_RESULT' && !failed;
  return AgentRunWorkStep(
    id: event.mergeKey,
    title: failed
        ? '$subject暂时无法读取'
        : completed
        ? '$subject已读取'
        : '正在读取$subject',
    status: completed
        ? AgentRunWorkStepStatus.completed
        : failed
        ? AgentRunWorkStepStatus.failed
        : AgentRunWorkStepStatus.running,
  );
}

bool _toolFailed(AgentStreamEvent event) {
  if (event.type == 'TOOL_CALL_ERROR' || event.type == 'TOOL_CALL_FAILED') {
    return true;
  }
  if (event.raw['is_error'] == true || event.raw['error'] is Map) return true;
  final status = stringField(event.raw, 'status')?.toLowerCase();
  return status == 'error' || status == 'failed';
}

AgentRunWorkStep _artifactStep(AgentStreamEvent event) {
  final artifactId =
      stringField(event.raw, 'artifact_id') ??
      stringField(event.raw, 'artifactId');
  return AgentRunWorkStep(
    id: artifactId == null || artifactId.isEmpty
        ? event.mergeKey
        : 'artifact:$artifactId',
    title: '已生成${_artifactSubject(event)}',
    status: AgentRunWorkStepStatus.completed,
  );
}

AgentRunWorkStep _confirmationStep(AgentStreamEvent event) {
  final confirmationId = stringField(event.raw, 'confirmation_id');
  return AgentRunWorkStep(
    id: confirmationId == null || confirmationId.isEmpty
        ? event.mergeKey
        : 'confirmation:$confirmationId',
    title: '需要确认后继续',
    status: AgentRunWorkStepStatus.waiting,
  );
}

String _toolSubject(AgentStreamEvent event) {
  return switch (stringField(event.raw, 'tool_call_name')) {
    'pump_session_summary_query' => '泵奶记录',
    'growth_record_query' => '成长记录',
    'feeding_record_query' => '喂养记录',
    'schedule_query' => '计划信息',
    _ => '相关信息',
  };
}

String _artifactSubject(AgentStreamEvent event) {
  return switch (stringField(event.raw, 'artifact_type')) {
    'milk_analysis_card' => '分析卡片',
    'rich_text' || 'rich_text_card' => '说明内容',
    _ => '结果卡片',
  };
}
