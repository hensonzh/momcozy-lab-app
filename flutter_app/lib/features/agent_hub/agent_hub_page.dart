import 'dart:async';

import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
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

const _agentDefaultGreeting = '嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？';

final _agentHubInteractionStates = Expando<_AgentHubInteractionState>(
  'momcozy-agent-hub-interaction-state',
);

class _AgentHubInteractionState {
  AgentStreamRunState runState = const AgentStreamRunState();
  List<AgentHubHistoryMessage>? historyMessages;
  String composerText = '';
  List<AgentStreamImageInput> attachedImages = const <AgentStreamImageInput>[];
  bool autoVoiceEnabled = true;
  AgentStreamRequest? activeRequest;
}

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({
    super.key,
    this.stateCacheKey,
    this.state = const AgentStreamRunState(),
    this.historyMessages = const <AgentHubHistoryMessage>[],
    this.runner,
    this.cancelClient,
    this.actionClient,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.voiceInput,
    this.voiceInputController,
    this.voicePlaybackCoordinator,
    this.onArtifactAction,
    this.onNewSession,
    this.initialComposerText,
  });

  final Object? stateCacheKey;
  final AgentStreamRunState state;
  final List<AgentHubHistoryMessage> historyMessages;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;
  final AgentStreamActionClient? actionClient;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubVoiceInput? voiceInput;
  final AgentVoiceInputController? voiceInputController;
  final AgentVoicePlaybackCoordinator? voicePlaybackCoordinator;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentHubNewSessionHandler? onNewSession;
  final String? initialComposerText;

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage> {
  late AgentStreamRunState _state;
  late List<AgentHubHistoryMessage> _historyMessages;
  late final TextEditingController _composerController;
  _AgentHubInteractionState? _interactionState;
  StreamSubscription<AgentStreamRunState>? _runSubscription;
  AgentStreamRequest? _activeRequest;
  AgentVoiceState _voiceState = const AgentVoiceState();
  final List<AgentStreamImageInput> _attachedImages = <AgentStreamImageInput>[];
  final Set<String> _pendingActionIds = <String>{};
  final Map<String, String> _localActionStatuses = <String, String>{};
  final ScrollController _chatScrollController = ScrollController();
  bool _autoVoiceEnabled = true;
  bool _showLatestButton = false;
  bool _showPhotoMenu = false;

  @override
  void initState() {
    super.initState();
    _restoreCachedInteractionState();
    _applyInitialComposerText();
    _composerController.addListener(_persistInteractionState);
    _chatScrollController.addListener(_updateLatestButtonVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateLatestButtonVisibility();
    });
  }

  @override
  void didUpdateWidget(covariant AgentHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_interactionState == null &&
        oldWidget.state != widget.state &&
        (widget.runner == null || !_state.isActive)) {
      _state = widget.state;
    }
    if (_interactionState == null &&
        oldWidget.historyMessages != widget.historyMessages &&
        !_state.isActive) {
      _historyMessages = [...widget.historyMessages];
      _persistInteractionState();
    }
    if (oldWidget.initialComposerText != widget.initialComposerText) {
      _applyInitialComposerText();
    }
  }

  @override
  void dispose() {
    _cancelRunSubscription();
    _composerController.removeListener(_persistInteractionState);
    _chatScrollController
      ..removeListener(_updateLatestButtonVisibility)
      ..dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _restoreCachedInteractionState() {
    final stateCacheKey = widget.stateCacheKey;
    if (stateCacheKey == null) {
      _state = widget.state;
      _historyMessages = [...widget.historyMessages];
      _composerController = TextEditingController();
      return;
    }

    final interactionState = _agentHubInteractionStates[stateCacheKey] ??=
        _AgentHubInteractionState();
    _interactionState = interactionState;
    _state = interactionState.historyMessages == null
        ? widget.state
        : interactionState.runState;
    _historyMessages = [
      ...(interactionState.historyMessages ?? widget.historyMessages),
    ];
    _composerController = TextEditingController(
      text: interactionState.composerText,
    );
    _attachedImages.addAll(interactionState.attachedImages);
    _autoVoiceEnabled = interactionState.autoVoiceEnabled;
    _activeRequest = interactionState.activeRequest;
  }

  void _persistInteractionState() {
    final interactionState = _interactionState;
    if (interactionState == null) return;
    interactionState
      ..runState = _state
      ..historyMessages = [..._historyMessages]
      ..composerText = _composerController.text
      ..attachedImages = [..._attachedImages]
      ..autoVoiceEnabled = _autoVoiceEnabled
      ..activeRequest = _activeRequest;
  }

  void _applyInitialComposerText() {
    final text = widget.initialComposerText?.trim();
    if (text == null || text.isEmpty || _state.isActive) return;
    _composerController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _persistInteractionState();
  }

  void _updateLatestButtonVisibility() {
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    final shouldShow =
        position.maxScrollExtent > 160 &&
        position.pixels < position.maxScrollExtent - 40;
    if (shouldShow == _showLatestButton) return;
    setState(() {
      _showLatestButton = shouldShow;
    });
  }

  Future<void> _scrollToLatest() async {
    if (!_chatScrollController.hasClients) return;
    await _chatScrollController.animateTo(
      _chatScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    if (position.pixels > position.maxScrollExtent) {
      _chatScrollController.jumpTo(position.maxScrollExtent);
    }
    _updateLatestButtonVisibility();
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

    final requestMessage = message.isEmpty ? '请看这张图片' : message;
    final optimisticContent = message.isEmpty
        ? '图片 ${_attachedImages.length}'
        : message;
    final request = _requestWithImages(
      widget.requestBuilder(requestMessage),
      _attachedImages,
    );
    _composerController.clear();
    setState(() {
      _historyMessages.add(
        AgentHubHistoryMessage(
          role: AgentHubHistoryRole.user,
          content: optimisticContent,
        ),
      );
      _attachedImages.clear();
      _showPhotoMenu = false;
    });
    _persistInteractionState();
    await _startRun(request);
  }

  Future<void> _attachImage() async {
    final pickImage = widget.pickImage;
    if (pickImage == null || _state.isActive) return;
    final image = await pickImage();
    if (!mounted || image == null) return;
    setState(() {
      _attachedImages.add(image);
      _showPhotoMenu = false;
    });
    _persistInteractionState();
  }

  void _togglePhotoMenu() {
    if (widget.pickImage == null || _state.isActive) return;
    setState(() {
      _showPhotoMenu = !_showPhotoMenu;
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
      _persistInteractionState();
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
    _persistInteractionState();
  }

  void _startNewSession() {
    if (_state.isActive) return;
    _cancelRunSubscription();
    _composerController.clear();
    setState(() {
      _state = const AgentStreamRunState();
      _historyMessages.clear();
      _attachedImages.clear();
      _showPhotoMenu = false;
      _pendingActionIds.clear();
      _localActionStatuses.clear();
      _activeRequest = null;
      _voiceState = const AgentVoiceState();
    });
    _persistInteractionState();
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
      _pendingActionIds.clear();
      _localActionStatuses.clear();
    });
    _persistInteractionState();

    _runSubscription = runner
        .run(request)
        .listen(
          (nextState) {
            if (!mounted || !_state.isActive) return;
            setState(() {
              _state = nextState;
            });
            _persistInteractionState();
            _maybeStartAutoVoicePlayback(nextState);
          },
          onError: (Object error) {
            if (!mounted || !_state.isActive) return;
            setState(() {
              _state = _state.markDisconnected(error);
            });
            _persistInteractionState();
          },
        );
  }

  void _maybeStartAutoVoicePlayback(AgentStreamRunState nextState) {
    final coordinator = widget.voicePlaybackCoordinator;
    final text = nextState.textContent.trim();
    if (coordinator == null ||
        !_autoVoiceEnabled ||
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
    _persistInteractionState();
    _cancelRunSubscription();
    setState(() {
      _state = _state.applyCancelResult(acknowledged: true);
    });
    _persistInteractionState();
    _sendBestEffortServerCancel(activeState, activeRequest);
  }

  void _toggleAutoVoice() {
    setState(() {
      _autoVoiceEnabled = !_autoVoiceEnabled;
    });
    _persistInteractionState();
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

    final runId = activeState.runId;
    if (runId == null || runId.trim().isEmpty) return;

    unawaited(
      cancelClient.cancel(
        AgentStreamCancelRequest(
          threadId: activeState.threadId ?? activeRequest?.threadId ?? '',
          runId: runId,
          reason: 'user_cancelled',
        ),
      ),
    );
  }

  Future<void> _confirmAction(AgentActionCardView action) async {
    final actionClient = widget.actionClient;
    if (actionClient == null || _pendingActionIds.contains(action.id)) return;
    setState(() {
      _pendingActionIds.add(action.id);
      _localActionStatuses[action.id] = 'confirming';
    });

    final result = await actionClient.confirm(
      AgentStreamActionConfirmRequest(actionId: action.id),
    );
    if (!mounted) return;
    setState(() {
      _pendingActionIds.remove(action.id);
      _localActionStatuses[action.id] = result.accepted
          ? result.actionStatus ?? 'confirmed'
          : 'failed';
    });
  }

  Future<void> _rejectAction(AgentActionCardView action) async {
    final actionClient = widget.actionClient;
    if (actionClient == null || _pendingActionIds.contains(action.id)) return;
    setState(() {
      _pendingActionIds.add(action.id);
      _localActionStatuses[action.id] = 'rejecting';
    });

    final result = await actionClient.reject(
      AgentStreamActionRejectRequest(
        actionId: action.id,
        reason: 'user_rejected',
      ),
    );
    if (!mounted) return;
    setState(() {
      _pendingActionIds.remove(action.id);
      _localActionStatuses[action.id] = result.accepted
          ? result.actionStatus ?? 'rejected'
          : 'failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('agent-hub-page'),
      color: MomCozyColors.background,
      child: Column(
        children: [
          AgentHubTopBar(
            showControls: true,
            autoVoiceEnabled: _autoVoiceEnabled,
            isRunning: _state.isActive,
            onToggleAutoVoice: _toggleAutoVoice,
            onNewSession: _startNewSession,
          ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  key: const ValueKey('agent-chat-scroll-view'),
                  controller: _chatScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                  children: [
                    if (_historyMessages.isNotEmpty) ...[
                      AgentHubHistoryPanel(messages: _historyMessages),
                      const SizedBox(height: 18),
                    ],
                    AgentRunTranscript(
                      state: _state,
                      canRetry: _canRetry,
                      onRetry: _retryRun,
                      onArtifactAction: widget.onArtifactAction,
                      pendingActionIds: _pendingActionIds,
                      localActionStatuses: _localActionStatuses,
                      onConfirmAction: widget.actionClient == null
                          ? null
                          : _confirmAction,
                      onRejectAction: widget.actionClient == null
                          ? null
                          : _rejectAction,
                    ),
                  ],
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 24,
                  child: IgnorePointer(child: _AgentHubTopFade()),
                ),
                if (_showLatestButton)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('agent-scroll-latest-button'),
                      onPressed: _scrollToLatest,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      label: const Text('回到最新消息'),
                    ),
                  ),
              ],
            ),
          ),
          AgentComposerBar(
            controller: _composerController,
            canSend: _canSend,
            isRunning: _state.isActive,
            imageCount: _attachedImages.length,
            showPhotoMenu: _showPhotoMenu,
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
            onTogglePhotoMenu: _togglePhotoMenu,
            onAttachImage: _attachImage,
            onRemoveImages: _removeAttachedImages,
            onVoiceInput: _startVoiceInput,
          ),
        ],
      ),
    );
  }
}

class AgentHubTopBar extends StatelessWidget {
  const AgentHubTopBar({
    super.key,
    required this.showControls,
    required this.autoVoiceEnabled,
    required this.isRunning,
    required this.onToggleAutoVoice,
    required this.onNewSession,
  });

  final bool showControls;
  final bool autoVoiceEnabled;
  final bool isRunning;
  final VoidCallback onToggleAutoVoice;
  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.background.withValues(alpha: 0.9),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: showControls
              ? [
                  IconButton(
                    key: const ValueKey('agent-auto-voice-button'),
                    onPressed: onToggleAutoVoice,
                    icon: Icon(
                      autoVoiceEnabled
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                      size: 16,
                    ),
                    tooltip: autoVoiceEnabled ? '关闭语音模式' : '开启语音模式',
                    color: autoVoiceEnabled
                        ? Colors.black
                        : MomCozyColors.background,
                    style: IconButton.styleFrom(
                      backgroundColor: autoVoiceEnabled
                          ? Colors.transparent
                          : const Color(0xff7a6670),
                      fixedSize: const Size.square(36),
                      minimumSize: const Size.square(36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('agent-new-session-button'),
                    onPressed: isRunning ? null : onNewSession,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    tooltip: '新建会话',
                    color: const Color(0xff3b2f36),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      fixedSize: const Size.square(36),
                      minimumSize: const Size.square(36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ]
              : const [SizedBox(width: 36, height: 56)],
        ),
      ),
    );
  }
}

class _AgentHubTopFade extends StatelessWidget {
  const _AgentHubTopFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: ValueKey('agent-top-fade'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [MomCozyColors.background, Color(0x00fff8f6)],
        ),
      ),
    );
  }
}

AgentStreamRequest _requestWithImages(
  AgentStreamRequest request,
  List<AgentStreamImageInput> images,
) {
  if (images.isEmpty) return request;
  return AgentStreamRequest(
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
    return Column(
      key: const ValueKey('agent-history-panel'),
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          _AgentHistoryBubble(
            key: ValueKey('agent-history-$index'),
            message: messages[index],
          ),
          if (index != messages.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _AgentHistoryBubble extends StatelessWidget {
  const _AgentHistoryBubble({super.key, required this.message});

  final AgentHubHistoryMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentHubHistoryRole.user;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: isUser ? const Color(0xff75545f) : const Color(0xff3f3038),
      fontWeight: FontWeight.w500,
    );

    if (!isUser) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AgentAssistantAvatar(),
          const SizedBox(width: 10),
          Expanded(child: Text(message.content, style: textStyle)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 294),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xfff8f0f1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(7),
              ),
              border: Border.all(color: const Color(0x73eadde2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(message.content, style: textStyle),
            ),
          ),
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
          borderRadius: BorderRadius.circular(MomCozyRadii.pill),
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
      AgentStreamRunPhase.waitingForConfirmation => '待确认',
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
      AgentStreamRunPhase.waitingForConfirmation => Icons.fact_check_outlined,
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
      AgentStreamRunPhase.waitingForConfirmation => colorScheme.tertiary,
      AgentStreamRunPhase.cancelRequested ||
      AgentStreamRunPhase.cancelled => colorScheme.onSurfaceVariant,
      _ => colorScheme.primary,
    };
  }

  Color _phaseBackground(ColorScheme colorScheme) {
    return switch (phase) {
      AgentStreamRunPhase.error || AgentStreamRunPhase.disconnected =>
        colorScheme.errorContainer.withValues(alpha: 0.5),
      AgentStreamRunPhase.waitingForConfirmation =>
        colorScheme.tertiaryContainer.withValues(alpha: 0.58),
      AgentStreamRunPhase.cancelRequested ||
      AgentStreamRunPhase.cancelled => MomCozyColors.muted,
      _ => MomCozyColors.roseSoft.withValues(alpha: 0.86),
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
    this.pendingActionIds = const <String>{},
    this.localActionStatuses = const <String, String>{},
    this.onConfirmAction,
    this.onRejectAction,
  });

  final AgentStreamRunState state;
  final bool canRetry;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;
  final Set<String> pendingActionIds;
  final Map<String, String> localActionStatuses;
  final ValueChanged<AgentActionCardView>? onConfirmAction;
  final ValueChanged<AgentActionCardView>? onRejectAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDefaultGreeting = state.textContent.trim().isEmpty;
    final text = isDefaultGreeting
        ? _agentDefaultGreeting
        : state.textContent.trim();
    final workSteps = _workStepsFromEvents(state.events);
    final artifactCards = _artifactCardsFromEvents(state.events);
    final actionCards = _actionCardsFromEvents(
      state.events,
      localActionStatuses,
    );

    return Row(
      key: const ValueKey('agent-run-transcript'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AgentAssistantAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDefaultGreeting ? 260 : double.infinity,
                  ),
                  child: Text(
                    text,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.40,
                      color:
                          state.phase == AgentStreamRunPhase.error ||
                              state.phase == AgentStreamRunPhase.disconnected
                          ? const Color(0xffb64b4b)
                          : const Color(0xff3f3038),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
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
                          color: MomCozyColors.mutedForeground,
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
              if (actionCards.isNotEmpty) ...[
                const SizedBox(height: 16),
                AgentActionPanel(
                  actions: actionCards,
                  pendingActionIds: pendingActionIds,
                  onConfirm: onConfirmAction,
                  onReject: onRejectAction,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String? get _supportingText {
    if (state.phase == AgentStreamRunPhase.streaming) return '正在生成回复';
    if (state.phase == AgentStreamRunPhase.waitingForConfirmation) {
      return '等待确认后继续';
    }
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
      AgentStreamRunPhase.waitingForConfirmation => Icons.fact_check_outlined,
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
      AgentStreamRunPhase.waitingForConfirmation => colorScheme.tertiary,
      _ => colorScheme.primary,
    };
  }
}

class _AgentAssistantAvatar extends StatelessWidget {
  const _AgentAssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff754c5e).withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          MomCozyAssets.agentAvatar,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
        ),
      ),
    );
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
            color: MomCozyColors.foreground,
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
                    color: MomCozyColors.mutedForeground,
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
            color: MomCozyColors.foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final card in cards) ...[
          DecoratedBox(
            key: ValueKey('agent-artifact-card-${card.id}'),
            decoration: BoxDecoration(
              color: MomCozyColors.roseSoft.withValues(alpha: 0.54),
              borderRadius: BorderRadius.circular(MomCozyRadii.control),
              border: Border.all(
                color: MomCozyColors.border.withValues(alpha: 0.74),
              ),
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
                            color: MomCozyColors.foreground,
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
                        color: MomCozyColors.mutedForeground,
                      ),
                    ),
                  ],
                  for (final row in card.rows) ...[
                    const SizedBox(height: 8),
                    Text(
                      row,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: MomCozyColors.mutedForeground,
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

class AgentActionPanel extends StatelessWidget {
  const AgentActionPanel({
    super.key,
    required this.actions,
    this.pendingActionIds = const <String>{},
    this.onConfirm,
    this.onReject,
  });

  final List<AgentActionCardView> actions;
  final Set<String> pendingActionIds;
  final ValueChanged<AgentActionCardView>? onConfirm;
  final ValueChanged<AgentActionCardView>? onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      key: const ValueKey('agent-action-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '待处理动作',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final action in actions) ...[
          DecoratedBox(
            key: ValueKey('agent-action-card-${action.id}'),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.38),
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
                        action.icon,
                        size: 18,
                        color: action.color(colorScheme),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action.title,
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        action.statusLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: action.color(colorScheme),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if (action.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      action.subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (action.canConfirm) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: ValueKey('agent-action-confirm-${action.id}'),
                          onPressed:
                              pendingActionIds.contains(action.id) ||
                                  onConfirm == null
                              ? null
                              : () => onConfirm?.call(action),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('确认'),
                        ),
                        OutlinedButton.icon(
                          key: ValueKey('agent-action-reject-${action.id}'),
                          onPressed:
                              pendingActionIds.contains(action.id) ||
                                  onReject == null
                              ? null
                              : () => onReject?.call(action),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('拒绝'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (action != actions.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class AgentActionCardView {
  const AgentActionCardView({
    required this.id,
    required this.title,
    required this.status,
    this.subtitle,
  });

  final String id;
  final String title;
  final String status;
  final String? subtitle;

  bool get canConfirm {
    return status == 'proposed' || status == 'confirmation_required';
  }

  String get statusLabel {
    return switch (status) {
      'confirming' => '确认中',
      'rejecting' => '拒绝中',
      'proposed' => '待确认',
      'confirmation_required' => '待确认',
      'confirmed' => '已确认',
      'queued' => '已提交',
      'applied' => '已应用',
      'rejected' => '已拒绝',
      'failed' => '失败',
      _ => status,
    };
  }

  IconData get icon {
    return switch (status) {
      'applied' => Icons.check_circle_outline_rounded,
      'rejected' => Icons.block_rounded,
      'failed' => Icons.error_outline_rounded,
      'confirming' || 'rejecting' || 'queued' => Icons.sync_rounded,
      _ => Icons.fact_check_outlined,
    };
  }

  Color color(ColorScheme colorScheme) {
    return switch (status) {
      'failed' => colorScheme.error,
      'applied' || 'confirmed' || 'queued' => colorScheme.primary,
      'rejected' => colorScheme.onSurfaceVariant,
      _ => colorScheme.tertiary,
    };
  }
}

class AgentComposerBar extends StatefulWidget {
  const AgentComposerBar({
    super.key,
    required this.controller,
    required this.canSend,
    required this.isRunning,
    required this.imageCount,
    required this.showPhotoMenu,
    required this.canAttachImage,
    required this.canUseVoice,
    required this.voicePhase,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    required this.onTogglePhotoMenu,
    required this.onAttachImage,
    required this.onRemoveImages,
    required this.onVoiceInput,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isRunning;
  final int imageCount;
  final bool showPhotoMenu;
  final bool canAttachImage;
  final bool canUseVoice;
  final AgentVoicePhase voicePhase;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onTogglePhotoMenu;
  final VoidCallback onAttachImage;
  final VoidCallback onRemoveImages;
  final VoidCallback onVoiceInput;

  @override
  State<AgentComposerBar> createState() => _AgentComposerBarState();
}

class _AgentComposerBarState extends State<AgentComposerBar> {
  static const double _controlSize = 32;
  static const double _surfaceMinHeight = 48;
  static const double _surfaceHorizontalInset = 12;
  static const double _surfaceVerticalInset = 8;
  static const double _controlGap = 8;
  static const double _inputLeftInset =
      _surfaceHorizontalInset + _controlSize + _controlGap;
  static const double _inputRightInset =
      _surfaceHorizontalInset + (_controlSize * 2) + (_controlGap * 2);
  static const double _expandedInputHorizontalInset = 20;
  static const double _expandedInputTopInset = 14;
  static const double _expandedInputBottomInset =
      _surfaceVerticalInset + _controlSize + 18;
  static const double _lineWrapGuard = 10;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AgentComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isRunning = widget.isRunning;
    final canSend = widget.canSend;
    final imageCount = widget.imageCount;
    final showPhotoMenu = widget.showPhotoMenu;
    final canAttachImage = widget.canAttachImage;
    final canUseVoice = widget.canUseVoice;
    final voicePhase = widget.voicePhase;
    final onChanged = widget.onChanged;
    final onSend = widget.onSend;
    final onCancel = widget.onCancel;
    final onTogglePhotoMenu = widget.onTogglePhotoMenu;
    final onAttachImage = widget.onAttachImage;
    final onRemoveImages = widget.onRemoveImages;
    final onVoiceInput = widget.onVoiceInput;
    const inputTextStyle = TextStyle(
      fontFamily: MomCozyTypography.fontFamily,
      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
      fontSize: 14,
      height: 1.6,
    );

    return Padding(
      key: const ValueKey('agent-composer-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: MomCozyColors.background),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showPhotoMenu) ...[
              Padding(
                key: const ValueKey('agent-photo-menu'),
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MomCozyColors.card.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.62),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff754c5e).withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const ValueKey('agent-photo-camera-button'),
                            onPressed: canAttachImage ? onAttachImage : null,
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: 18,
                            ),
                            label: const Text('拍照'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('agent-photo-upload-button'),
                            onPressed: canAttachImage ? onAttachImage : null,
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: const Text('上传'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (imageCount > 0) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: MomCozyColors.card.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff754c5e).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    key: const ValueKey('agent-image-attachment-chip'),
                    children: [
                      const SizedBox(width: 10),
                      Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '图片 $imageCount',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: MomCozyColors.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('agent-remove-image-button'),
                        onPressed: isRunning ? null : onRemoveImages,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: '移除图片',
                      ),
                    ],
                  ),
                ),
              ),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final expandedTextLayout = _shouldUseExpandedTextLayout(
                  context,
                  constraints.maxWidth,
                  inputTextStyle,
                );
                final inputPadding = expandedTextLayout
                    ? const EdgeInsets.fromLTRB(
                        _expandedInputHorizontalInset,
                        _expandedInputTopInset,
                        _expandedInputHorizontalInset,
                        _expandedInputBottomInset,
                      )
                    : const EdgeInsets.fromLTRB(
                        _inputLeftInset,
                        _surfaceVerticalInset,
                        _inputRightInset,
                        _surfaceVerticalInset,
                      );
                Widget positionControl({
                  required Widget child,
                  double? left,
                  double? right,
                }) {
                  assert((left == null) != (right == null));

                  if (expandedTextLayout) {
                    return Positioned(
                      left: left,
                      right: right,
                      bottom: _surfaceVerticalInset,
                      child: child,
                    );
                  }

                  return Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: left ?? 0,
                        right: right ?? 0,
                      ),
                      child: Align(
                        alignment: left == null
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                  );
                }

                final composerInput = TextField(
                  key: const ValueKey('agent-composer-input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  enabled: !isRunning,
                  style: inputTextStyle,
                  onChanged: onChanged,
                  scrollPadding: const EdgeInsets.only(bottom: 96),
                  decoration: InputDecoration(
                    hintText: '和 CozyMate 聊聊...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      fontFamily: MomCozyTypography.fontFamily,
                      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                      fontSize: 14,
                      height: 1.6,
                      color: MomCozyColors.mutedForeground.withValues(
                        alpha: 0.82,
                      ),
                    ),
                  ),
                );
                final inputFrame = Padding(
                  key: const ValueKey('agent-composer-input-frame'),
                  padding: inputPadding,
                  child: composerInput,
                );
                final controlButtonStyle = IconButton.styleFrom(
                  fixedSize: const Size.square(_controlSize),
                  minimumSize: const Size.square(_controlSize),
                  maximumSize: const Size.square(_controlSize),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                );

                return DecoratedBox(
                  key: const ValueKey('agent-composer-surface'),
                  decoration: BoxDecoration(
                    color: MomCozyColors.card.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: MomCozyColors.border.withValues(alpha: 0.64),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff754c5e).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _surfaceMinHeight,
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        inputFrame,
                        positionControl(
                          left: _surfaceHorizontalInset,
                          child: IconButton(
                            key: const ValueKey('agent-image-button'),
                            onPressed: canAttachImage
                                ? onTogglePhotoMenu
                                : null,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 20,
                            ),
                            tooltip: '添加图片',
                            color: MomCozyColors.mutedForeground,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: _controlSize,
                              height: _controlSize,
                            ),
                            padding: EdgeInsets.zero,
                            style: controlButtonStyle,
                          ),
                        ),
                        positionControl(
                          right:
                              _surfaceHorizontalInset +
                              _controlSize +
                              _controlGap,
                          child: IconButton(
                            key: const ValueKey('agent-voice-button'),
                            onPressed: canUseVoice ? onVoiceInput : null,
                            icon: Icon(_voiceIcon, size: 20),
                            tooltip: _voiceTooltip,
                            color: voicePhase == AgentVoicePhase.listening
                                ? colorScheme.primary
                                : MomCozyColors.mutedForeground,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: _controlSize,
                              height: _controlSize,
                            ),
                            padding: EdgeInsets.zero,
                            style: controlButtonStyle,
                          ),
                        ),
                        positionControl(
                          right: _surfaceHorizontalInset,
                          child: IconButton(
                            key: ValueKey(
                              isRunning
                                  ? 'agent-stop-button'
                                  : 'agent-send-button',
                            ),
                            onPressed: isRunning
                                ? onCancel
                                : (canSend ? onSend : null),
                            icon: DecoratedBox(
                              key: const ValueKey('agent-send-button-visual'),
                              decoration: BoxDecoration(
                                color: isRunning || canSend
                                    ? colorScheme.primary
                                    : MomCozyColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: _controlSize,
                                child: Center(
                                  child: Icon(
                                    isRunning
                                        ? Icons.stop_rounded
                                        : Icons.send_rounded,
                                    size: isRunning ? 18 : 16,
                                    color: isRunning || canSend
                                        ? colorScheme.onPrimary
                                        : MomCozyColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                            tooltip: isRunning ? '停止' : '发送',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: _controlSize,
                              height: _controlSize,
                            ),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              overlayColor: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              fixedSize: const Size.square(_controlSize),
                              minimumSize: const Size.square(_controlSize),
                              maximumSize: const Size.square(_controlSize),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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

  bool _shouldUseExpandedTextLayout(
    BuildContext context,
    double surfaceWidth,
    TextStyle style,
  ) {
    final text = widget.controller.text;
    if (text.contains('\n')) return true;
    return _visualLineCountForWidth(
          context,
          _compactInputTextWidth(surfaceWidth),
          style,
        ) >
        1;
  }

  double _compactInputTextWidth(double surfaceWidth) {
    return surfaceWidth - _inputLeftInset - _inputRightInset - _lineWrapGuard;
  }

  int _visualLineCountForWidth(
    BuildContext context,
    double maxWidth,
    TextStyle style,
  ) {
    final text = widget.controller.text.isEmpty ? ' ' : widget.controller.text;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      maxLines: 100,
    )..layout(maxWidth: maxWidth.clamp(1.0, double.infinity));
    return painter.computeLineMetrics().length.clamp(1, 100);
  }

  IconData get _voiceIcon {
    return switch (widget.voicePhase) {
      AgentVoicePhase.listening => Icons.graphic_eq_rounded,
      AgentVoicePhase.transcribing => Icons.hourglass_bottom_rounded,
      AgentVoicePhase.playing => Icons.volume_up_outlined,
      AgentVoicePhase.permissionDenied => Icons.mic_off_outlined,
      AgentVoicePhase.error => Icons.mic_off_outlined,
      _ => Icons.mic_none_rounded,
    };
  }

  String get _voiceTooltip {
    return switch (widget.voicePhase) {
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
    return switch (widget.voicePhase) {
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
  if (event.type != 'artifact.created' && event.type != 'artifact.updated') {
    return null;
  }

  final payload = event.payload;
  final rawRichText = _mapField(event.raw, 'rich_text', 'richText');
  final payloadRichText = _mapField(payload, 'rich_text', 'richText');
  final richText = rawRichText.isNotEmpty ? rawRichText : payloadRichText;
  final rawArtifact = _mapField(event.raw, 'artifact');
  final payloadArtifact = _mapField(payload, 'artifact');
  final artifact = rawArtifact.isNotEmpty ? rawArtifact : payloadArtifact;
  final rawCardJson = _mapField(artifact, 'card_json', 'cardJson');
  final cardJson = rawCardJson.isNotEmpty ? rawCardJson : payload;
  final artifactId =
      stringField(event.raw, 'artifact_id') ??
      stringField(payload, 'artifact_id') ??
      stringField(event.raw, 'artifactId') ??
      stringField(artifact, 'id') ??
      event.mergeKey;

  final title =
      _firstNonEmpty([
        _stringField(richText, 'title'),
        _stringField(cardJson, 'title'),
        _stringField(payload, 'title'),
        _artifactSubject(event),
      ]) ??
      '结果卡片';
  final content = _firstNonEmpty([
    _stringField(richText, 'content'),
    _stringField(payload, 'content'),
    _stringField(payload, 'summary'),
  ]);
  final status = _firstNonEmpty([
    _stringField(cardJson, 'status_label', 'statusLabel'),
    _stringField(payload, 'status_label', 'statusLabel'),
  ]);
  final rows = <String>[
    ..._stringList(cardJson['steps']),
    ..._stringList(payload['steps']),
    ..._richTextCardRows(richText['card']),
  ];
  final actions = <AgentArtifactActionView>[
    ..._buttonActions(richText['button']),
    ..._referenceActionsFromRichText(richText),
    ..._semanticActions(richText['action'], event),
    ..._semanticActions(payload['actions'], event),
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

List<AgentActionCardView> _actionCardsFromEvents(
  List<AgentStreamEvent> events,
  Map<String, String> localStatuses,
) {
  final cards = <String, AgentActionCardView>{};
  for (final event in events) {
    final card = _actionCardFromEvent(event);
    if (card != null) cards[card.id] = card;
  }

  for (final entry in localStatuses.entries) {
    final existing = cards[entry.key];
    if (existing == null) continue;
    cards[entry.key] = AgentActionCardView(
      id: existing.id,
      title: existing.title,
      status: entry.value,
      subtitle: existing.subtitle,
    );
  }

  return List<AgentActionCardView>.unmodifiable(cards.values);
}

AgentActionCardView? _actionCardFromEvent(AgentStreamEvent event) {
  if (!event.type.startsWith('action.')) return null;

  final actionId =
      stringField(event.raw, 'action_id') ??
      stringField(event.raw, 'actionId') ??
      stringField(event.payload, 'action_id') ??
      stringField(event.payload, 'actionId');
  if (actionId == null || actionId.trim().isEmpty) return null;

  final preview = _mapField(event.payload, 'preview_payload', 'previewPayload');
  final title =
      _firstNonEmpty([
        _stringField(event.payload, 'title'),
        _stringField(preview, 'title'),
        _stringField(preview, 'summary'),
        _stringField(event.payload, 'action_type', 'actionType'),
        stringField(event.raw, 'action_type') ??
            stringField(event.raw, 'actionType'),
        '需要确认后继续',
      ]) ??
      '需要确认后继续';
  final subtitle = _firstNonEmpty([
    _stringField(event.payload, 'summary'),
    _stringField(preview, 'description'),
    _stringField(preview, 'message'),
    _stringField(event.payload, 'target_type', 'targetType'),
  ]);

  return AgentActionCardView(
    id: actionId.trim(),
    title: title,
    status: _actionStatus(event),
    subtitle: subtitle,
  );
}

String _actionStatus(AgentStreamEvent event) {
  final statusFromType = switch (event.type) {
    'action.proposed' => 'proposed',
    'action.confirmation_required' => 'confirmation_required',
    'action.queued' => 'queued',
    'action.applied' => 'applied',
    'action.failed' => 'failed',
    'action.rejected' => 'rejected',
    _ => null,
  };
  if (statusFromType != null) return statusFromType;

  final explicit = _firstNonEmpty([
    _stringField(event.payload, 'action_status', 'actionStatus'),
    _stringField(event.payload, 'status'),
    stringField(event.raw, 'status'),
  ]);
  if (explicit != null) return explicit;

  return 'proposed';
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
          kind == 'artifact' ? '打开${_artifactSubject(event)}' : null,
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
    'artifact' => Icons.fact_check_outlined,
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
    'run.progress' => _progressStep(event),
    'tool.started' ||
    'tool.progress' ||
    'tool.completed' ||
    'tool.failed' => _toolStep(event),
    'artifact.created' || 'artifact.updated' => _artifactStep(event),
    'action.proposed' ||
    'action.confirmation_required' ||
    'action.queued' ||
    'action.applied' ||
    'action.failed' ||
    'action.rejected' => _actionStep(event),
    'run.failed' || 'error' => AgentRunWorkStep(
      id: event.mergeKey,
      title: '处理遇到问题',
      status: AgentRunWorkStepStatus.failed,
    ),
    _ => null,
  };
}

AgentRunWorkStep? _progressStep(AgentStreamEvent event) {
  final title =
      _firstNonEmpty([
        _stringField(event.payload, 'label'),
        _stringField(event.payload, 'message'),
      ]) ??
      '正在处理';
  return AgentRunWorkStep(
    id: event.mergeKey,
    title: title,
    status: AgentRunWorkStepStatus.running,
  );
}

AgentRunWorkStep _toolStep(AgentStreamEvent event) {
  final subject = _toolSubject(event);
  final failed = _toolFailed(event);
  final completed = event.type == 'tool.completed' && !failed;
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
  if (event.type == 'tool.failed') {
    return true;
  }
  if (event.raw['is_error'] == true || event.raw['error'] is Map) return true;
  final status =
      stringField(event.raw, 'status')?.toLowerCase() ??
      stringField(event.payload, 'status')?.toLowerCase();
  return status == 'error' || status == 'failed';
}

AgentRunWorkStep _artifactStep(AgentStreamEvent event) {
  final artifactId =
      stringField(event.raw, 'artifact_id') ??
      stringField(event.payload, 'artifact_id') ??
      stringField(event.raw, 'artifactId');
  return AgentRunWorkStep(
    id: artifactId == null || artifactId.isEmpty
        ? event.mergeKey
        : 'artifact:$artifactId',
    title: '已生成${_artifactSubject(event)}',
    status: AgentRunWorkStepStatus.completed,
  );
}

AgentRunWorkStep _actionStep(AgentStreamEvent event) {
  final actionId =
      stringField(event.raw, 'action_id') ??
      stringField(event.payload, 'action_id') ??
      stringField(event.raw, 'confirmation_id');
  final status = _actionStatus(event);
  return AgentRunWorkStep(
    id: actionId == null || actionId.isEmpty
        ? event.mergeKey
        : 'action:$actionId',
    title: switch (status) {
      'queued' => '动作已提交',
      'applied' => '动作已应用',
      'rejected' => '动作已拒绝',
      'failed' => '动作处理失败',
      _ => '需要确认后继续',
    },
    status: switch (status) {
      'queued' || 'applied' => AgentRunWorkStepStatus.completed,
      'rejected' => AgentRunWorkStepStatus.completed,
      'failed' => AgentRunWorkStepStatus.failed,
      _ => AgentRunWorkStepStatus.waiting,
    },
  );
}

String _toolSubject(AgentStreamEvent event) {
  final label = _stringField(event.payload, 'label');
  if (label != null && label.trim().isNotEmpty) return label.trim();
  return switch (_firstNonEmpty([
    stringField(event.raw, 'tool_name'),
    stringField(event.payload, 'tool_name'),
    stringField(event.raw, 'tool_call_name'),
  ])) {
    'pump_session_summary_query' => '泵奶记录',
    'growth_record_query' => '成长记录',
    'feeding_record_query' => '喂养记录',
    'schedule_query' => '计划信息',
    _ => '相关信息',
  };
}

String _artifactSubject(AgentStreamEvent event) {
  return switch (_firstNonEmpty([
    stringField(event.raw, 'artifact_type'),
    stringField(event.payload, 'artifact_type'),
  ])) {
    'milk_analysis_card' => '分析卡片',
    'milk_plan_card' => '结果卡片',
    'rich_text' || 'rich_text_card' => '说明内容',
    _ => '结果卡片',
  };
}
