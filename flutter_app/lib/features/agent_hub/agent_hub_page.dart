import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);
typedef AgentHubImagePicker = Future<AgentStreamImageInput?> Function();
typedef AgentHubVoiceInput = Future<String?> Function();
typedef AgentArtifactActionHandler =
    void Function(AgentArtifactActionView action);
typedef AgentHubNewSessionHandler = void Function();

const _agentDefaultGreeting = '嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？';
const _agentDefaultGreetingPlaybackId = 'agent-default-greeting';

String _agentAssistantTextForState(AgentStreamRunState state) {
  final text = state.textContent.trim();
  if (text.isNotEmpty) return text;

  return switch (state.phase) {
    AgentStreamRunPhase.idle => _agentDefaultGreeting,
    AgentStreamRunPhase.streaming => '我已经收到你的消息啦～',
    AgentStreamRunPhase.cancelRequested => '我正在停止这次回复。',
    AgentStreamRunPhase.cancelled => '已停止本次回复。',
    AgentStreamRunPhase.waitingForConfirmation => '需要你确认后继续。',
    AgentStreamRunPhase.finished => '我已经处理完成，但这次没有返回可见内容。',
    AgentStreamRunPhase.error ||
    AgentStreamRunPhase.disconnected => '这次没有拿到回复，可能是连接中断了。你再发一次就好。',
  };
}

class _PendingAutoVoiceReplay {
  const _PendingAutoVoiceReplay({required this.state, this.attempts = 0});

  final AgentStreamRunState state;
  final int attempts;

  _PendingAutoVoiceReplay incrementAttempts() {
    return _PendingAutoVoiceReplay(state: state, attempts: attempts + 1);
  }
}

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
  Map<String, String> localActionStatuses = const <String, String>{};
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
    this.interactionStateStore,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.voiceInput,
    this.voiceInputController,
    this.voicePlaybackCoordinator,
    this.onArtifactAction,
    this.onNewSession,
    this.initialComposerText,
    this.initialAutoSend = false,
  });

  final Object? stateCacheKey;
  final AgentStreamRunState state;
  final List<AgentHubHistoryMessage> historyMessages;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;
  final AgentStreamActionClient? actionClient;
  final AgentHubInteractionStateStore? interactionStateStore;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubVoiceInput? voiceInput;
  final AgentVoiceInputController? voiceInputController;
  final AgentVoicePlaybackCoordinator? voicePlaybackCoordinator;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentHubNewSessionHandler? onNewSession;
  final String? initialComposerText;
  final bool initialAutoSend;

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
  Timer? _persistentWriteTimer;
  AgentHubInteractionSnapshot? _pendingPersistentSnapshot;
  _PendingAutoVoiceReplay? _pendingAutoVoiceReplay;
  VoidCallback? _unsubscribeVoicePlaybackIdle;
  bool _consumedInitialAutoSend = false;

  @override
  void initState() {
    super.initState();
    _restoreCachedInteractionState();
    _restorePersistedInteractionState();
    _applyInitialComposerText();
    _scheduleInitialAutoSendIfNeeded();
    _composerController.addListener(_persistInteractionState);
    _chatScrollController.addListener(_updateLatestButtonVisibility);
    _syncVoicePlaybackIdleSubscription();
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
      _consumedInitialAutoSend = false;
      _applyInitialComposerText();
      _scheduleInitialAutoSendIfNeeded();
    } else if (oldWidget.initialAutoSend != widget.initialAutoSend) {
      _scheduleInitialAutoSendIfNeeded();
    }
    if (oldWidget.voicePlaybackCoordinator != widget.voicePlaybackCoordinator) {
      _syncVoicePlaybackIdleSubscription();
    }
  }

  @override
  void dispose() {
    _cancelRunSubscription();
    _unsubscribeVoicePlaybackIdle?.call();
    _flushPersistentInteractionState();
    _composerController.removeListener(_persistInteractionState);
    _chatScrollController
      ..removeListener(_updateLatestButtonVisibility)
      ..dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _syncVoicePlaybackIdleSubscription() {
    _unsubscribeVoicePlaybackIdle?.call();
    _unsubscribeVoicePlaybackIdle = null;

    final coordinator = widget.voicePlaybackCoordinator;
    if (coordinator == null) return;
    _unsubscribeVoicePlaybackIdle = coordinator.subscribeIdle(() {
      scheduleMicrotask(_tryRunPendingAutoVoiceReplay);
    });
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
    final restoredRunState = interactionState.historyMessages == null
        ? widget.state
        : interactionState.runState;
    _state = restoredRunState.isActive
        ? restoredRunState.markDisconnected('连接中断，请重试')
        : restoredRunState;
    _historyMessages = [
      ...(interactionState.historyMessages ?? widget.historyMessages),
    ];
    _composerController = TextEditingController(
      text: interactionState.composerText,
    );
    _attachedImages.addAll(interactionState.attachedImages);
    _autoVoiceEnabled = interactionState.autoVoiceEnabled;
    _activeRequest = interactionState.activeRequest;
    _localActionStatuses.addAll(interactionState.localActionStatuses);
    interactionState.runState = _state;
  }

  void _persistInteractionState() {
    final interactionState = _interactionState;
    if (interactionState != null) {
      interactionState
        ..runState = _state
        ..historyMessages = [..._historyMessages]
        ..composerText = _composerController.text
        ..attachedImages = [..._attachedImages]
        ..autoVoiceEnabled = _autoVoiceEnabled
        ..activeRequest = _activeRequest
        ..localActionStatuses = {..._localActionStatuses};
    }
    _schedulePersistentInteractionStateWrite(_buildInteractionSnapshot());
  }

  Future<void> _restorePersistedInteractionState() async {
    final store = widget.interactionStateStore;
    if (store == null) return;
    final snapshot = await store.read();
    if (!mounted || snapshot == null || !snapshot.hasContent) return;
    if (_hasLocalInteraction()) return;
    setState(() {
      _applyInteractionSnapshot(snapshot);
    });
    _persistInteractionState();
  }

  bool _hasLocalInteraction() {
    return _state.events.isNotEmpty ||
        _state.textContent.trim().isNotEmpty ||
        _state.provisionalTextContent.trim().isNotEmpty ||
        _state.threadId?.trim().isNotEmpty == true ||
        _state.runId?.trim().isNotEmpty == true ||
        _historyMessages.isNotEmpty ||
        _composerController.text.trim().isNotEmpty ||
        _attachedImages.isNotEmpty ||
        _activeRequest != null ||
        _localActionStatuses.isNotEmpty;
  }

  void _applyInteractionSnapshot(AgentHubInteractionSnapshot snapshot) {
    final restoredState = snapshot.runState.isActive
        ? snapshot.runState.markDisconnected('连接已中断，可继续接收。')
        : snapshot.runState;
    _state = restoredState;
    _historyMessages = snapshot.historyMessages
        .map(_historyMessageFromSnapshot)
        .toList(growable: false);
    _composerController
      ..text = snapshot.composerText
      ..selection = TextSelection.collapsed(
        offset: snapshot.composerText.length,
      );
    _attachedImages
      ..clear()
      ..addAll(snapshot.attachedImages);
    _autoVoiceEnabled = snapshot.autoVoiceEnabled;
    _activeRequest = snapshot.activeRequest;
    _localActionStatuses
      ..clear()
      ..addAll(snapshot.localActionStatuses);
  }

  AgentHubInteractionSnapshot _buildInteractionSnapshot() {
    return AgentHubInteractionSnapshot(
      runState: _state,
      historyMessages: _historyMessages
          .map(_historySnapshotFromMessage)
          .toList(growable: false),
      composerText: _composerController.text,
      attachedImages: [..._attachedImages],
      autoVoiceEnabled: _autoVoiceEnabled,
      activeRequest: _activeRequest,
      localActionStatuses: {..._localActionStatuses},
    );
  }

  void _schedulePersistentInteractionStateWrite(
    AgentHubInteractionSnapshot snapshot,
  ) {
    if (widget.interactionStateStore == null) return;
    _pendingPersistentSnapshot = snapshot;
    _persistentWriteTimer?.cancel();
    _persistentWriteTimer = Timer(
      const Duration(milliseconds: 250),
      _flushPersistentInteractionState,
    );
  }

  void _flushPersistentInteractionState() {
    final store = widget.interactionStateStore;
    final snapshot = _pendingPersistentSnapshot;
    _persistentWriteTimer?.cancel();
    _persistentWriteTimer = null;
    _pendingPersistentSnapshot = null;
    if (store == null || snapshot == null) return;
    final operation = snapshot.hasContent
        ? store.write(snapshot)
        : store.clear();
    unawaited(_ignorePersistentWriteError(operation));
  }

  Future<void> _ignorePersistentWriteError(Future<void> operation) async {
    try {
      await operation;
    } catch (_) {
      // State persistence is recoverability aid; UI should not fail on it.
    }
  }

  void _applyInitialComposerText() {
    final text = widget.initialComposerText?.trim();
    if (text == null || text.isEmpty || _state.isActive) return;
    _composerController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _persistInteractionState();
  }

  void _scheduleInitialAutoSendIfNeeded() {
    if (_consumedInitialAutoSend ||
        !widget.initialAutoSend ||
        widget.runner == null ||
        _state.isActive ||
        widget.initialComposerText?.trim().isNotEmpty != true) {
      return;
    }
    _consumedInitialAutoSend = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isComposerLocked ||
          _composerController.text.trim().isEmpty) {
        return;
      }
      unawaited(_sendMessage());
    });
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

  bool _isNearLatest([double threshold = 80]) {
    if (!_chatScrollController.hasClients) return true;
    final position = _chatScrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
  }

  void _scheduleScrollToLatest({bool smooth = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrollToLatest(smooth: smooth));
    });
  }

  Future<void> _scrollToLatest({bool smooth = true}) async {
    if (!_chatScrollController.hasClients) return;
    if (smooth) {
      await _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _chatScrollController.jumpTo(
        _chatScrollController.position.maxScrollExtent,
      );
    }
    if (!_chatScrollController.hasClients) return;
    final position = _chatScrollController.position;
    if (position.pixels > position.maxScrollExtent) {
      _chatScrollController.jumpTo(position.maxScrollExtent);
    }
    _updateLatestButtonVisibility();
  }

  bool get _isComposerLocked =>
      _state.phase == AgentStreamRunPhase.waitingForConfirmation ||
      _state.phase == AgentStreamRunPhase.cancelRequested;

  bool get _canSend =>
      widget.runner != null &&
      !_isComposerLocked &&
      (_composerController.text.trim().isNotEmpty ||
          _attachedImages.isNotEmpty);

  bool get _canRetry =>
      widget.runner != null && _state.canRetry && _activeRequest != null;

  Future<void> _sendMessage() async {
    final runner = widget.runner;
    final message = _composerController.text.trim();
    if (runner == null ||
        (message.isEmpty && _attachedImages.isEmpty) ||
        _isComposerLocked) {
      return;
    }

    _cancelCurrentBubblePlaybackForNewTurn();

    final requestMessage = message.isEmpty ? '请看这张图片' : message;
    final optimisticContent = message.isEmpty
        ? '图片 ${_attachedImages.length}'
        : message;
    final interruptedState = _state.isActive ? _state : null;
    final interruptedRequest = _state.isActive ? _activeRequest : null;
    final request = _requestWithImages(
      widget.requestBuilder(requestMessage),
      _attachedImages,
    );
    final archivedAssistantMessage = _currentAssistantHistoryMessage();
    if (interruptedState != null) {
      _cancelRunSubscription();
      _sendBestEffortServerCancel(interruptedState, interruptedRequest);
    }
    _composerController.clear();
    setState(() {
      if (archivedAssistantMessage != null) {
        _historyMessages.add(archivedAssistantMessage);
      }
      _historyMessages.add(
        AgentHubHistoryMessage(
          role: AgentHubHistoryRole.user,
          content: optimisticContent,
        ),
      );
      _attachedImages.clear();
      _showPhotoMenu = false;
      _pendingAutoVoiceReplay = null;
    });
    _persistInteractionState();
    _scheduleScrollToLatest();
    await _startRun(request);
  }

  AgentHubHistoryMessage? _currentAssistantHistoryMessage() {
    final text = _agentAssistantTextForState(_state).trim();
    if (text.isEmpty) return null;
    return AgentHubHistoryMessage(
      role: AgentHubHistoryRole.assistant,
      content: text,
      runState: _state.phase == AgentStreamRunPhase.idle ? null : _state,
    );
  }

  Future<void> _attachImage() async {
    final pickImage = widget.pickImage;
    if (pickImage == null || _isComposerLocked) return;
    final image = await pickImage();
    if (!mounted || image == null) return;
    setState(() {
      _attachedImages.add(image);
      _showPhotoMenu = false;
    });
    _persistInteractionState();
  }

  void _togglePhotoMenu() {
    if (widget.pickImage == null || _isComposerLocked) return;
    setState(() {
      _showPhotoMenu = !_showPhotoMenu;
    });
  }

  Future<void> _startVoiceInput() async {
    if ((widget.voiceInputController == null && widget.voiceInput == null) ||
        _isComposerLocked ||
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
      _pendingAutoVoiceReplay = null;
    });
    _persistInteractionState();
    _maybeStartGreetingVoicePlayback();
    widget.onNewSession?.call();
  }

  void _cancelCurrentBubblePlaybackForNewTurn() {
    const preservedSources = <AgentVoicePlaybackSource>{
      AgentVoicePlaybackSource.notification,
    };
    final coordinator = widget.voicePlaybackCoordinator;
    final activeSource = coordinator?.activeSource;
    final isPreservedPlayback =
        activeSource != null && preservedSources.contains(activeSource);
    final didCancel =
        coordinator?.cancel(preserveSources: preservedSources) ?? false;

    if (!_voiceState.isPlaybackActive) return;
    if (coordinator != null && isPreservedPlayback && !didCancel) return;

    setState(() {
      _voiceState = _voiceState.cancelPlayback();
    });
  }

  void _maybeStartGreetingVoicePlayback() {
    final coordinator = widget.voicePlaybackCoordinator;
    if (coordinator == null || !_autoVoiceEnabled) return;

    final result = coordinator.request(
      id: _agentDefaultGreetingPlaybackId,
      source: AgentVoicePlaybackSource.greeting,
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

  Future<void> _retryRun() async {
    final request = _activeRequest;
    if (request == null || widget.runner == null || !_state.canRetry) return;
    final runId = _state.runId?.trim();
    if (runId != null && runId.isNotEmpty) {
      await _startRun(
        request.resume(
          runId: runId,
          threadId: _state.threadId,
          afterSequence: _state.lastSequence ?? 0,
        ),
        initialState: _state.copyWith(phase: AgentStreamRunPhase.streaming),
        preserveActionState: true,
      );
      return;
    }
    await _startRun(request);
  }

  Future<void> _resumeCurrentRun({bool preserveActionState = false}) async {
    if (widget.runner == null) return;
    final runId = _state.runId?.trim();
    if (runId == null || runId.isEmpty) return;
    final baseRequest =
        _activeRequest ??
        AgentStreamRequest(message: '', threadId: _state.threadId);
    await _startRun(
      baseRequest.resume(
        runId: runId,
        threadId: _state.threadId,
        afterSequence: _state.lastSequence ?? 0,
      ),
      initialState: _state.copyWith(phase: AgentStreamRunPhase.streaming),
      preserveActionState: preserveActionState,
    );
  }

  Future<void> _startRun(
    AgentStreamRequest request, {
    AgentStreamRunState? initialState,
    bool preserveActionState = false,
  }) async {
    final runner = widget.runner;
    if (runner == null || (initialState == null && _isComposerLocked)) return;
    final requestWithThread = _requestWithConversationThread(request);

    _cancelRunSubscription();
    _activeRequest = requestWithThread;
    setState(() {
      _state = initialState ?? const AgentStreamRunState().start();
      if (initialState == null) {
        _pendingAutoVoiceReplay = null;
      }
      if (!preserveActionState) {
        _pendingActionIds.clear();
        _localActionStatuses.clear();
      }
    });
    _persistInteractionState();
    _scheduleScrollToLatest();

    _runSubscription = runner
        .run(requestWithThread, initialState: initialState)
        .listen(
          (nextState) {
            if (!mounted || !_state.isActive) return;
            final shouldFollowLatest = _isNearLatest() || nextState.isActive;
            final activeRequest = _activeRequest;
            if (activeRequest != null) {
              _activeRequest = _requestWithThreadId(
                activeRequest,
                nextState.threadId,
              );
            }
            setState(() {
              _state = nextState;
            });
            _persistInteractionState();
            _maybeStartAutoVoicePlayback(nextState);
            if (shouldFollowLatest) _scheduleScrollToLatest();
          },
          onError: (Object error) {
            if (!mounted || !_state.isActive) return;
            final shouldFollowLatest = _isNearLatest();
            setState(() {
              _state = _state.markDisconnected(error);
            });
            _persistInteractionState();
            if (shouldFollowLatest) _scheduleScrollToLatest();
          },
        );
  }

  AgentStreamRequest _requestWithConversationThread(
    AgentStreamRequest request,
  ) {
    return _requestWithThreadId(
      request,
      request.threadId ?? _state.threadId ?? _activeRequest?.threadId,
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

    final playbackId = _autoVoicePlaybackId(nextState);
    final result = coordinator.request(
      id: playbackId,
      source: AgentVoicePlaybackSource.autoReply,
    );
    if (result.status == AgentVoicePlaybackRequestStatus.blocked) {
      _queueBlockedAutoVoiceReplay(nextState);
      return;
    }
    final handle = result.handle;
    if (!mounted ||
        result.status != AgentVoicePlaybackRequestStatus.started ||
        handle == null) {
      return;
    }
    setState(() {
      _pendingAutoVoiceReplay = null;
      _voiceState = _voiceState.startPlayback(handle.id);
    });
  }

  String _autoVoicePlaybackId(AgentStreamRunState state) {
    return state.messageId ?? state.runId ?? state.threadId ?? '';
  }

  void _queueBlockedAutoVoiceReplay(AgentStreamRunState state) {
    final current = _pendingAutoVoiceReplay;
    final currentId = current == null
        ? null
        : _autoVoicePlaybackId(current.state);
    final nextId = _autoVoicePlaybackId(state);
    _pendingAutoVoiceReplay = _PendingAutoVoiceReplay(
      state: state,
      attempts: current != null && currentId == nextId ? current.attempts : 0,
    );
  }

  void _tryRunPendingAutoVoiceReplay() {
    if (!mounted || !_autoVoiceEnabled) return;
    final pending = _pendingAutoVoiceReplay;
    if (pending == null) return;
    if (pending.attempts >= 3 || pending.state.textContent.trim().isEmpty) {
      _pendingAutoVoiceReplay = null;
      return;
    }

    _pendingAutoVoiceReplay = pending.incrementAttempts();
    _maybeStartAutoVoicePlayback(pending.state);
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
      final nextEnabled = !_autoVoiceEnabled;
      if (!nextEnabled) {
        widget.voicePlaybackCoordinator?.cancel();
        _pendingAutoVoiceReplay = null;
        if (_voiceState.isPlaybackActive) {
          _voiceState = _voiceState.cancelPlayback();
        }
      }
      _autoVoiceEnabled = nextEnabled;
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
          ? _acceptedConfirmStatus(result.actionStatus)
          : 'failed';
      _applyActionResultEvents(result.events);
    });
    _persistInteractionState();
    if (result.accepted && _shouldResumeAfterActionResult()) {
      await _resumeCurrentRun(preserveActionState: true);
    }
  }

  String _acceptedConfirmStatus(String? actionStatus) {
    final normalized = actionStatus?.trim();
    if (normalized == null || normalized.isEmpty || normalized == 'confirmed') {
      return 'queued';
    }
    return normalized;
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
      _applyActionResultEvents(result.events);
    });
    _persistInteractionState();
    if (result.accepted && _shouldResumeAfterActionResult()) {
      await _resumeCurrentRun(preserveActionState: true);
    }
  }

  bool _shouldResumeAfterActionResult() {
    return switch (_state.phase) {
      AgentStreamRunPhase.finished ||
      AgentStreamRunPhase.cancelled ||
      AgentStreamRunPhase.error => false,
      _ => true,
    };
  }

  void _applyActionResultEvents(List<AgentStreamEvent> events) {
    if (events.isEmpty) return;
    var nextState = _state.phase == AgentStreamRunPhase.waitingForConfirmation
        ? _state.copyWith(phase: AgentStreamRunPhase.streaming)
        : _state;
    for (final event in events) {
      nextState = nextState.applyEvent(event);
    }
    _state = nextState;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const verticalTranscriptPadding = 14.0 + 24.0;
                final transcriptMinHeight =
                    constraints.maxHeight > verticalTranscriptPadding
                    ? constraints.maxHeight - verticalTranscriptPadding
                    : 0.0;

                return Stack(
                  children: [
                    CustomScrollView(
                      key: const ValueKey('agent-chat-scroll-view'),
                      controller: _chatScrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
                          sliver: SliverToBoxAdapter(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: transcriptMinHeight,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_historyMessages.isNotEmpty) ...[
                                    AgentHubHistoryPanel(
                                      messages: _historyMessages,
                                      onArtifactAction: widget.onArtifactAction,
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  AgentRunTranscript(
                                    state: _state,
                                    activeVoicePlaybackId:
                                        _voiceState.isPlaybackActive
                                        ? _voiceState.playbackId
                                        : null,
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
                            ),
                          ),
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
                );
              },
            ),
          ),
          AgentComposerBar(
            controller: _composerController,
            canSend: _canSend,
            isRunning: _state.isActive,
            isInputLocked: _isComposerLocked,
            imageCount: _attachedImages.length,
            showPhotoMenu: _showPhotoMenu,
            canAttachImage: widget.pickImage != null && !_isComposerLocked,
            canUseVoice:
                (widget.voiceInputController != null ||
                    widget.voiceInput != null) &&
                !_state.isActive &&
                !_isComposerLocked &&
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

AgentStreamRequest _requestWithThreadId(
  AgentStreamRequest request,
  String? threadId,
) {
  final normalizedThreadId = threadId?.trim();
  if (request.threadId?.trim().isNotEmpty == true ||
      normalizedThreadId == null ||
      normalizedThreadId.isEmpty) {
    return request;
  }

  return AgentStreamRequest(
    message: request.message,
    threadId: normalizedThreadId,
    locale: request.locale,
    images: request.images,
    metadata: request.metadata,
  );
}

enum AgentHubHistoryRole { user, assistant }

class AgentHubHistoryMessage {
  const AgentHubHistoryMessage({
    required this.role,
    required this.content,
    this.runState,
  });

  final AgentHubHistoryRole role;
  final String content;
  final AgentStreamRunState? runState;

  String get roleLabel {
    return switch (role) {
      AgentHubHistoryRole.user => '我',
      AgentHubHistoryRole.assistant => '智能体',
    };
  }
}

AgentHubHistoryMessage _historyMessageFromSnapshot(
  AgentHubHistorySnapshot snapshot,
) {
  return AgentHubHistoryMessage(
    role: snapshot.role == 'user'
        ? AgentHubHistoryRole.user
        : AgentHubHistoryRole.assistant,
    content: snapshot.content,
  );
}

AgentHubHistorySnapshot _historySnapshotFromMessage(
  AgentHubHistoryMessage message,
) {
  return AgentHubHistorySnapshot(
    role: message.role == AgentHubHistoryRole.user ? 'user' : 'assistant',
    content: message.content,
  );
}

class AgentHubHistoryPanel extends StatelessWidget {
  const AgentHubHistoryPanel({
    super.key,
    required this.messages,
    this.onArtifactAction,
  });

  final List<AgentHubHistoryMessage> messages;
  final AgentArtifactActionHandler? onArtifactAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('agent-history-panel'),
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          _AgentHistoryBubble(
            key: ValueKey('agent-history-$index'),
            message: messages[index],
            onArtifactAction: onArtifactAction,
          ),
          if (index != messages.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _AgentHistoryBubble extends StatelessWidget {
  const _AgentHistoryBubble({
    super.key,
    required this.message,
    this.onArtifactAction,
  });

  final AgentHubHistoryMessage message;
  final AgentArtifactActionHandler? onArtifactAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentHubHistoryRole.user;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.45,
      color: isUser ? const Color(0xff75545f) : const Color(0xff3f3038),
      fontWeight: FontWeight.w500,
    );

    if (!isUser) {
      final runState = message.runState;
      if (runState != null) {
        return AgentRunTranscript(
          state: runState,
          onArtifactAction: onArtifactAction,
        );
      }

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
    this.activeVoicePlaybackId,
    this.canRetry = false,
    this.onRetry,
    this.onArtifactAction,
    this.pendingActionIds = const <String>{},
    this.localActionStatuses = const <String, String>{},
    this.onConfirmAction,
    this.onRejectAction,
  });

  final AgentStreamRunState state;
  final String? activeVoicePlaybackId;
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
    final isDefaultGreeting =
        state.phase == AgentStreamRunPhase.idle &&
        state.textContent.trim().isEmpty;
    final text = _primaryText;
    final workSteps = _workStepsFromEvents(state.events);
    final artifactCards = _artifactCardsFromEvents(state.events);
    final actionCards = _actionCardsFromEvents(
      state.events,
      localActionStatuses,
    );
    final avatarMode = _avatarMode;
    final statusLineTitle = _statusLineTitle(workSteps);
    final shouldRenderPrimaryText = _shouldRenderPrimaryText;
    final primaryTextStyle = textTheme.bodyMedium?.copyWith(
      height: 1.40,
      color:
          state.phase == AgentStreamRunPhase.error ||
              state.phase == AgentStreamRunPhase.disconnected
          ? const Color(0xffb64b4b)
          : const Color(0xff3f3038),
      fontWeight: FontWeight.w400,
    );

    return Row(
      key: const ValueKey('agent-run-transcript'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AgentAssistantAvatar(mode: avatarMode),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusLineTitle != null) ...[
                AgentRunStatusLine(title: statusLineTitle),
                if (shouldRenderPrimaryText) const SizedBox(height: 8),
              ],
              if (shouldRenderPrimaryText)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDefaultGreeting ? 260 : double.infinity,
                    ),
                    child: AgentMarkdownText(text, style: primaryTextStyle),
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

  String get _primaryText {
    return _agentAssistantTextForState(state);
  }

  bool get _shouldRenderPrimaryText {
    if (state.phase == AgentStreamRunPhase.streaming &&
        state.textContent.trim().isEmpty) {
      return false;
    }
    return true;
  }

  String? _statusLineTitle(List<AgentRunWorkStep> workSteps) {
    if (state.phase != AgentStreamRunPhase.streaming ||
        state.textContent.trim().isNotEmpty) {
      return null;
    }
    for (final step in workSteps.reversed) {
      if (step.status == AgentRunWorkStepStatus.running ||
          step.status == AgentRunWorkStepStatus.waiting) {
        final title = step.title.trim();
        if (title.isNotEmpty) return title;
      }
    }
    return '我已经收到你的消息啦～';
  }

  String? get _supportingText {
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

  _AgentAssistantAvatarMode? get _avatarMode {
    final playbackId = activeVoicePlaybackId?.trim();
    final isDefaultGreeting =
        state.phase == AgentStreamRunPhase.idle &&
        state.textContent.trim().isEmpty;
    if (playbackId == _agentDefaultGreetingPlaybackId && isDefaultGreeting) {
      return _AgentAssistantAvatarMode.speaking;
    }
    final statePlaybackId = state.messageId?.trim().isNotEmpty == true
        ? state.messageId!.trim()
        : state.runId?.trim().isNotEmpty == true
        ? state.runId!.trim()
        : state.threadId?.trim();
    if (playbackId != null &&
        playbackId.isNotEmpty &&
        statePlaybackId != null &&
        statePlaybackId.isNotEmpty &&
        playbackId == statePlaybackId) {
      return _AgentAssistantAvatarMode.speaking;
    }
    if (state.isActive) return _AgentAssistantAvatarMode.thinking;
    return null;
  }
}

class AgentMarkdownText extends StatelessWidget {
  const AgentMarkdownText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trim();
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    if (!_containsMarkdown(normalized)) {
      return Text(normalized, style: baseStyle);
    }

    return MarkdownBody(
      data: normalized,
      fitContent: true,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: _momcozyMarkdownStyleSheet(context, baseStyle),
    );
  }

  MarkdownStyleSheet _momcozyMarkdownStyleSheet(
    BuildContext context,
    TextStyle? baseStyle,
  ) {
    final theme = Theme.of(context);
    final baseFontSize = baseStyle?.fontSize ?? 14;
    final paragraphStyle = theme.textTheme.bodyMedium
        ?.merge(baseStyle)
        .copyWith(height: 1.42);
    final mutedStyle = paragraphStyle?.copyWith(
      color: MomCozyColors.mutedForeground,
    );
    final headingBase = paragraphStyle?.copyWith(
      height: 1.28,
      color: MomCozyColors.foreground,
      fontWeight: FontWeight.w900,
    );
    final codeStyle = paragraphStyle?.copyWith(
      color: MomCozyColors.foreground,
      backgroundColor: MomCozyColors.muted.withValues(alpha: 0.52),
      fontFamily: 'monospace',
      fontSize: baseFontSize * 0.92,
      height: 1.36,
    );

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: paragraphStyle,
      pPadding: EdgeInsets.zero,
      a: paragraphStyle?.copyWith(
        color: MomCozyColors.primary,
        fontWeight: FontWeight.w800,
        decoration: TextDecoration.none,
      ),
      strong: paragraphStyle?.copyWith(
        color: MomCozyColors.foreground,
        fontWeight: FontWeight.w900,
      ),
      em: paragraphStyle?.copyWith(fontStyle: FontStyle.italic),
      del: mutedStyle?.copyWith(decoration: TextDecoration.lineThrough),
      h1: headingBase?.copyWith(fontSize: baseFontSize + 6),
      h2: headingBase?.copyWith(fontSize: baseFontSize + 4),
      h3: headingBase?.copyWith(fontSize: baseFontSize + 2),
      h4: headingBase?.copyWith(fontSize: baseFontSize + 1),
      h5: headingBase,
      h6: headingBase,
      h1Padding: const EdgeInsets.only(bottom: 6),
      h2Padding: const EdgeInsets.only(bottom: 6),
      h3Padding: const EdgeInsets.only(bottom: 4),
      h4Padding: const EdgeInsets.only(bottom: 4),
      h5Padding: const EdgeInsets.only(bottom: 4),
      h6Padding: const EdgeInsets.only(bottom: 4),
      code: codeStyle,
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MomCozyColors.border),
      ),
      blockSpacing: 10,
      listIndent: 20,
      listBullet: mutedStyle,
      listBulletPadding: const EdgeInsets.only(right: 6),
      blockquote: mutedStyle,
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      blockquoteDecoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: MomCozyColors.primary, width: 3),
        ),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: MomCozyColors.border, width: 1)),
      ),
      tableHead: paragraphStyle?.copyWith(
        color: MomCozyColors.foreground,
        fontWeight: FontWeight.w900,
      ),
      tableBody: paragraphStyle,
      tableBorder: TableBorder.all(color: MomCozyColors.border),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      tableHeadAlign: TextAlign.left,
      tableCellsDecoration: BoxDecoration(
        color: MomCozyColors.card.withValues(alpha: 0.75),
      ),
    );
  }

  static bool _containsMarkdown(String value) {
    return RegExp(
      r'(^|\n)\s{0,3}#{1,6}\s+|(^|\n)\s*[-*]\s+|(^|\n)\s*\d+\.\s+|\*\*.+?\*\*|`{1,3}|(^|\n)\s{0,3}>\s+|\[[^\]]+\]\([^)]+\)|(^|\n)\|.+\|($|\n)|(^|\n)---($|\n)',
      multiLine: true,
    ).hasMatch(value);
  }
}

class AgentRunStatusLine extends StatelessWidget {
  const AgentRunStatusLine({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: title,
      child: Container(
        key: const ValueKey('agent-run-status-line'),
        constraints: const BoxConstraints(maxWidth: double.infinity),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 14,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.18),
                    ),
                    child: const SizedBox.square(dimension: 12),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.86),
                    ),
                    child: const SizedBox.square(dimension: 6),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  height: 1.35,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AgentAssistantAvatarMode { thinking, speaking }

class _AgentAssistantAvatar extends StatelessWidget {
  const _AgentAssistantAvatar({this.mode});

  final _AgentAssistantAvatarMode? mode;

  @override
  Widget build(BuildContext context) {
    final isSpeaking = mode == _AgentAssistantAvatarMode.speaking;
    final isThinking = mode == _AgentAssistantAvatarMode.thinking;
    final ringColor = isSpeaking
        ? const Color(0xffaa647d)
        : const Color(0xff8bbdb5);

    return SizedBox.square(
      key: const ValueKey('agent-assistant-avatar'),
      dimension: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (isThinking || isSpeaking)
            Positioned(
              left: -2,
              right: -2,
              top: -2,
              bottom: -2,
              child: DecoratedBox(
                key: ValueKey(
                  isSpeaking
                      ? 'agent-assistant-avatar-speaking'
                      : 'agent-assistant-avatar-thinking',
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor.withValues(alpha: 0.54),
                    width: isSpeaking ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(
                        alpha: isSpeaking ? 0.24 : 0.16,
                      ),
                      blurRadius: isSpeaking ? 14 : 10,
                      spreadRadius: isSpeaking ? 2 : 1,
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          DecoratedBox(
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
                key: const ValueKey('agent-assistant-avatar-static'),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
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
    this.routeExtra,
  });

  final String label;
  final IconData icon;
  final String kind;
  final String? value;
  final String? routePath;
  final Object? routeExtra;
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
    required this.isInputLocked,
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
  final bool isInputLocked;
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
  bool _voiceMode = false;
  bool _voicePressed = false;
  String? _textDraftBeforeVoice;

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

  void _toggleVoiceMode() {
    if (_voicePressed) return;
    if (!_voiceMode && !widget.canUseVoice) return;
    setState(() {
      if (_voiceMode) {
        if (widget.controller.text.trim().isEmpty &&
            _textDraftBeforeVoice != null) {
          widget.controller.text = _textDraftBeforeVoice!;
          widget.controller.selection = TextSelection.collapsed(
            offset: widget.controller.text.length,
          );
        }
        _voiceMode = false;
        _textDraftBeforeVoice = null;
        return;
      }

      _textDraftBeforeVoice = widget.controller.text;
      if (widget.controller.text.isNotEmpty) {
        widget.controller.clear();
        widget.onChanged('');
      }
      _voiceMode = true;
    });
  }

  void _startVoiceHold() {
    if (!_voiceMode || !widget.canUseVoice || _voicePressed) return;
    setState(() {
      _voicePressed = true;
    });
  }

  void _finishVoiceHold({required bool submit}) {
    if (!_voicePressed) return;
    setState(() {
      _voicePressed = false;
      _voiceMode = false;
      _textDraftBeforeVoice = null;
    });
    if (submit) widget.onVoiceInput();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isRunning = widget.isRunning;
    final isInputLocked = widget.isInputLocked;
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
    final sendIsStop = isRunning && !canSend;
    final sendLooksActive = canSend || sendIsStop;
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
                        onPressed: isInputLocked ? null : onRemoveImages,
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

                final composerInput = _voiceMode
                    ? GestureDetector(
                        key: const ValueKey('agent-voice-hold-button'),
                        onTapDown: (_) => _startVoiceHold(),
                        onTapUp: (_) => _finishVoiceHold(submit: true),
                        onTapCancel: () => _finishVoiceHold(submit: false),
                        child: Semantics(
                          button: true,
                          label: _voicePressed ? '松开填入语音输入' : '按住说话',
                          child: Container(
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _voicePressed
                                  ? const Color(0xfff8eef3)
                                  : colorScheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(
                                MomCozyRadii.pill,
                              ),
                              border: Border.all(
                                color: _voicePressed
                                    ? const Color(0xffe5cdd8)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              _voicePressed ? '我在听，松开后文字填入输入框' : '按住说话',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: _voicePressed
                                        ? const Color(0xff563544)
                                        : MomCozyColors.foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      )
                    : TextField(
                        key: const ValueKey('agent-composer-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enabled: !isInputLocked,
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
                            fontFamilyFallback:
                                MomCozyTypography.fontFamilyFallback,
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
                            onPressed: canUseVoice || _voiceMode
                                ? _toggleVoiceMode
                                : null,
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
                              sendIsStop
                                  ? 'agent-stop-button'
                                  : 'agent-send-button',
                            ),
                            onPressed: sendIsStop
                                ? onCancel
                                : (canSend ? onSend : null),
                            icon: DecoratedBox(
                              key: const ValueKey('agent-send-button-visual'),
                              decoration: BoxDecoration(
                                color: sendLooksActive
                                    ? colorScheme.primary
                                    : MomCozyColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox.square(
                                dimension: _controlSize,
                                child: Center(
                                  child: Icon(
                                    sendIsStop
                                        ? Icons.stop_rounded
                                        : Icons.send_rounded,
                                    size: sendIsStop ? 18 : 16,
                                    color: sendLooksActive
                                        ? colorScheme.onPrimary
                                        : MomCozyColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                            tooltip: sendIsStop ? '停止' : '发送',
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
    if (_voiceMode) return Icons.keyboard_alt_outlined;
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
    if (_voiceMode) return '切换到文字输入';
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
      AgentVoicePhase.cancelled => null,
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
  final artifactPayload = _mapField(artifact, 'payload');
  final cardEnvelope = _firstMap([
    _mapField(artifactPayload, 'card'),
    _mapField(payload, 'card'),
    _mapField(artifact, 'card'),
  ]);
  final form = _firstMap([
    _mapField(artifactPayload, 'form'),
    _mapField(payload, 'form'),
    _mapField(artifact, 'form'),
  ]);
  final cartUpdate = _firstMap([
    _mapField(artifactPayload, 'cart_update', 'cartUpdate'),
    _mapField(payload, 'cart_update', 'cartUpdate'),
  ]);
  final assistantFollowup = _firstMap([
    _mapField(artifactPayload, 'assistant_followup', 'assistantFollowup'),
    _mapField(payload, 'assistant_followup', 'assistantFollowup'),
  ]);
  final rawCardJson = _firstMap([
    _mapField(artifact, 'card_json', 'cardJson'),
    _mapField(artifactPayload, 'card_json', 'cardJson'),
    _mapField(payload, 'card_json', 'cardJson'),
    _mapField(cardEnvelope, 'card_json', 'cardJson'),
  ]);
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
        _stringField(form, 'title'),
        _stringField(cardJson, 'title'),
        _stringField(cartUpdate, 'message'),
        _stringField(payload, 'title'),
        _artifactSubject(event),
      ]) ??
      '结果卡片';
  final content = _firstNonEmpty([
    _stringField(richText, 'content'),
    _stringField(payload, 'content'),
    _stringField(payload, 'summary'),
    _stringField(artifactPayload, 'summary'),
    _stringField(assistantFollowup, 'message'),
  ]);
  final status = _firstNonEmpty([
    _stringField(cardJson, 'status_label', 'statusLabel'),
    _stringField(payload, 'status_label', 'statusLabel'),
  ]);
  final rows = <String>[
    ..._formRows(form),
    ..._cardJsonRows(cardJson),
    ..._cartUpdateRows(cartUpdate),
    ..._stringList(cardJson['steps']),
    ..._stringList(payload['steps']),
    ..._richTextCardRows(richText['card']),
  ];
  final actions = <AgentArtifactActionView>[
    ..._buttonActions(richText['button']),
    ..._referenceActionsFromRichText(richText),
    ..._semanticActions(richText['action'], event),
    ..._semanticActions(payload['actions'], event),
    ..._assistantFollowupActions(assistantFollowup),
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

Map<String, Object?> _firstMap(List<Map<String, Object?>> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return const {};
}

List<String> _formRows(Map<String, Object?> form) {
  if (form.isEmpty) return const <String>[];
  final fields = form['fields'];
  if (fields is! List) return const <String>[];
  final rows = <String>[];
  for (final rawField in fields.take(12)) {
    if (rawField is! Map) continue;
    final field = Map<String, Object?>.from(rawField);
    final label = _stringField(field, 'label') ?? _stringField(field, 'id');
    if (label == null) continue;
    final options = _stringList(field['options']);
    final required = field['required'] == true ? '必填' : '可选';
    final suffix = options.isEmpty
        ? required
        : '$required｜${options.take(4).join(' / ')}';
    rows.add('$label：$suffix');
  }
  return rows;
}

List<String> _cardJsonRows(Map<String, Object?> cardJson) {
  if (cardJson.isEmpty) return const <String>[];
  final rows = <String>[];
  final owner = _mapField(cardJson, 'owner');
  if (owner.isNotEmpty) {
    final ownerValues = owner.entries
        .where(
          (entry) =>
              entry.value != null && entry.value.toString().trim().isNotEmpty,
        )
        .take(5)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('｜');
    if (ownerValues.isNotEmpty) rows.add(ownerValues);
  }
  rows.addAll(_packingGroupRows(cardJson['packing_groups']));
  rows.addAll(_todoPlanRows(cardJson['todo_plan']));
  rows.addAll(_stringList(cardJson['timeline']).take(4));
  rows.addAll(_stringList(cardJson['personalized_notes']).take(4));
  return rows;
}

List<String> _packingGroupRows(Object? rawGroups) {
  if (rawGroups is! List) return const <String>[];
  final rows = <String>[];
  for (final rawGroup in rawGroups.take(6)) {
    if (rawGroup is! Map) continue;
    final group = Map<String, Object?>.from(rawGroup);
    final title = _stringField(group, 'title');
    final items = group['items'];
    if (title == null || items is! List) continue;
    final labels = items
        .whereType<Map>()
        .map((rawItem) => Map<String, Object?>.from(rawItem))
        .map(
          (item) => _stringField(item, 'label') ?? _stringField(item, 'name'),
        )
        .whereType<String>()
        .take(5)
        .join('、');
    rows.add(labels.isEmpty ? title : '$title：$labels');
  }
  return rows;
}

List<String> _todoPlanRows(Object? rawTodoPlan) {
  if (rawTodoPlan is! Map) return const <String>[];
  final todoPlan = Map<String, Object?>.from(rawTodoPlan);
  final periods = todoPlan['periods'];
  if (periods is! List) return const <String>[];
  final rows = <String>[];
  for (final rawPeriod in periods.take(4)) {
    if (rawPeriod is! Map) continue;
    final period = Map<String, Object?>.from(rawPeriod);
    final title = _stringField(period, 'title') ?? '阶段';
    final items = period['items'];
    if (items is List) {
      final itemTitles = items
          .whereType<Map>()
          .map((rawItem) => Map<String, Object?>.from(rawItem))
          .map((item) => _stringField(item, 'title'))
          .whereType<String>()
          .take(4)
          .join('、');
      rows.add(itemTitles.isEmpty ? title : '$title：$itemTitles');
    } else {
      rows.add(title);
    }
  }
  return rows;
}

List<String> _cartUpdateRows(Map<String, Object?> cartUpdate) {
  if (cartUpdate.isEmpty) return const <String>[];
  final rows = <String>[];
  final message = _stringField(cartUpdate, 'message');
  if (message != null) rows.add(message);
  rows.addAll(_cartGroupRows(cartUpdate['groups']));
  final totals = _mapField(cartUpdate, 'totals');
  if (totals.isNotEmpty) {
    final itemCount = totals['item_count'] ?? totals['itemCount'];
    final total = totals['total'] ?? totals['subtotal'];
    if (itemCount != null || total != null) {
      rows.add('购物车合计：${itemCount ?? '-'} 件｜${total ?? '-'}');
    }
  }
  return rows;
}

List<AgentArtifactActionView> _assistantFollowupActions(
  Map<String, Object?> assistantFollowup,
) {
  if (assistantFollowup.isEmpty) return const <AgentArtifactActionView>[];
  final kind = _stringField(assistantFollowup, 'kind');
  final message = _stringField(assistantFollowup, 'message');
  final route = _markdownLinkPath(message);
  if (kind == 'hospital_bag_cart' || route == '/hospital-bag-cart') {
    return [
      AgentArtifactActionView(
        label: '打开待产包购物车',
        icon: _actionIcon('artifact'),
        kind: 'artifact',
        value: route ?? '/hospital-bag-cart',
        routePath: route ?? '/hospital-bag-cart',
      ),
    ];
  }
  return const <AgentArtifactActionView>[];
}

List<String> _cartGroupRows(Object? rawGroups) {
  if (rawGroups is! List) return const <String>[];
  return rawGroups
      .whereType<Map>()
      .map((rawGroup) => Map<String, Object?>.from(rawGroup))
      .take(5)
      .map((group) {
        final title = _stringField(group, 'title') ?? '待产包';
        final items = group['items'];
        if (items is! List) return title;
        final names = items
            .whereType<Map>()
            .map((rawItem) => Map<String, Object?>.from(rawItem))
            .map(
              (item) =>
                  _stringField(item, 'name') ?? _stringField(item, 'label'),
            )
            .whereType<String>()
            .take(4)
            .join('、');
        return names.isEmpty ? title : '$title：$names';
      })
      .toList(growable: false);
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
    if (_isFinalActionStatus(existing.status)) continue;
    cards[entry.key] = AgentActionCardView(
      id: existing.id,
      title: existing.title,
      status: entry.value,
      subtitle: existing.subtitle,
    );
  }

  return List<AgentActionCardView>.unmodifiable(cards.values);
}

bool _isFinalActionStatus(String status) {
  return status == 'applied' || status == 'failed' || status == 'rejected';
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
          routeExtra: _actionRouteExtra(kind: kind, value: value, title: label),
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
          routeExtra: _actionRouteExtra(kind: kind, value: value, title: label),
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

Map<String, Object?>? _actionRouteExtra({
  required String? kind,
  required String? value,
  required String? title,
}) {
  if (!_isMediaActionKind(kind)) return null;
  final url = value?.trim();
  if (url == null || url.isEmpty) return null;
  final mediaKind = _mediaViewerKind(kind: kind, url: url);
  if (mediaKind == null) return null;
  final normalizedTitle = title?.trim();
  return {
    'kind': mediaKind,
    'url': url,
    if (normalizedTitle != null && normalizedTitle.isNotEmpty)
      'title': normalizedTitle,
  };
}

bool _isMediaActionKind(String? kind) {
  return switch (kind) {
    'doc' ||
    'document' ||
    'pdf' ||
    'media' ||
    'image' ||
    'photo' ||
    'picture' ||
    'video' => true,
    _ => false,
  };
}

String? _mediaViewerKind({required String? kind, required String url}) {
  final normalizedKind = kind?.trim().toLowerCase();
  if (normalizedKind == 'pdf' ||
      normalizedKind == 'doc' ||
      normalizedKind == 'document') {
    return 'pdf';
  }
  if (normalizedKind == 'image' ||
      normalizedKind == 'photo' ||
      normalizedKind == 'picture') {
    return 'image';
  }
  if (normalizedKind == 'video') return 'video';

  final normalizedUrl = url.toLowerCase().split('?').first;
  if (normalizedUrl.endsWith('.pdf')) return 'pdf';
  if (normalizedUrl.endsWith('.png') ||
      normalizedUrl.endsWith('.jpg') ||
      normalizedUrl.endsWith('.jpeg') ||
      normalizedUrl.endsWith('.webp') ||
      normalizedUrl.endsWith('.gif')) {
    return 'image';
  }
  if (normalizedUrl.endsWith('.mp4') ||
      normalizedUrl.endsWith('.mov') ||
      normalizedUrl.endsWith('.webm')) {
    return 'video';
  }
  return null;
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

String? _markdownLinkPath(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final match = RegExp(r'\[[^\]]+\]\(([^)]+)\)').firstMatch(normalized);
  if (match == null) return null;
  return _safeSameOriginPath(match.group(1));
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
    'run.queued' || 'run.started' => _progressStep(event),
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
      switch (event.type) {
        'run.queued' => '正在排队准备',
        'run.started' => 'CozyMate 正在进入对话',
        _ => '正在处理',
      };
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
