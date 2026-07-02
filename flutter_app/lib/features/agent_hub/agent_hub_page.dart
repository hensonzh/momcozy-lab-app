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

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({
    super.key,
    this.state = const AgentStreamRunState(),
    this.runner,
    this.cancelClient,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.voiceInput,
  });

  final AgentStreamRunState state;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubVoiceInput? voiceInput;

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage> {
  late AgentStreamRunState _state = widget.state;
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
    final voiceInput = widget.voiceInput;
    if (voiceInput == null || _state.isActive || _voiceState.isInputActive) {
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
      final text = (await voiceInput())?.trim();
      if (!mounted) return;
      setState(() {
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

  void _removeAttachedImages() {
    setState(() {
      _attachedImages.clear();
    });
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
        AgentRunTranscript(
          state: _state,
          canRetry: _canRetry,
          onRetry: _retryRun,
        ),
        const SizedBox(height: 16),
        AgentComposerBar(
          controller: _composerController,
          canSend: _canSend,
          isRunning: _state.isActive,
          imageCount: _attachedImages.length,
          canAttachImage: widget.pickImage != null && !_state.isActive,
          canUseVoice:
              widget.voiceInput != null &&
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
  });

  final AgentStreamRunState state;
  final bool canRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = state.textContent.trim().isEmpty
        ? '我在。'
        : state.textContent.trim();
    final workSteps = _workStepsFromEvents(state.events);

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
                    color: voicePhase == AgentVoicePhase.error
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
      AgentVoicePhase.error => Icons.mic_off_outlined,
      _ => Icons.mic_none_rounded,
    };
  }

  String get _voiceTooltip {
    return switch (voicePhase) {
      AgentVoicePhase.listening => '正在听',
      AgentVoicePhase.transcribing => '正在转写',
      AgentVoicePhase.error => '语音失败',
      _ => '语音输入',
    };
  }

  String? get _voiceStatusLabel {
    return switch (voicePhase) {
      AgentVoicePhase.listening => '正在听',
      AgentVoicePhase.transcribing => '正在整理语音',
      AgentVoicePhase.error => '语音输入失败',
      _ => null,
    };
  }
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
    'TOOL_CALL_RESULT' => _toolStep(event),
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
  final completed = event.type == 'TOOL_CALL_RESULT';
  return AgentRunWorkStep(
    id: event.mergeKey,
    title: completed ? '$subject已读取' : '正在读取$subject',
    status: completed
        ? AgentRunWorkStepStatus.completed
        : AgentRunWorkStepStatus.running,
  );
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
