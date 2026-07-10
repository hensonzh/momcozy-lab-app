import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
import 'package:video_player/video_player.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);
typedef AgentHubImagePicker = Future<AgentStreamImageInput?> Function();
typedef AgentHubVoiceInput = Future<String?> Function();
typedef AgentArtifactActionHandler =
    void Function(AgentArtifactActionView action);
typedef AgentHubNewSessionHandler = void Function();

const _agentDefaultGreeting = '嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？';
const _agentDefaultGreetingPlaybackId = 'agent-default-greeting';
const _agentSkillAssetBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _agentActiveRunPersistentWriteInterval = Duration(milliseconds: 750);

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

String _formSubmitRequestMessage(AgentArtifactActionView action) {
  final extra = action.routeExtra;
  final extraMap = extra is Map ? Map<String, Object?>.from(extra) : const {};
  final formId = extraMap['formId']?.toString().trim();
  final values = extraMap['values'];
  final valuesJson = values is Map
      ? jsonEncode(values)
      : (action.value?.trim().isNotEmpty ?? false)
      ? action.value!.trim()
      : '{}';
  return [
    '我已提交信息采集表单，请基于确认后的表单数据继续完成对应服务。',
    if (formId != null && formId.isNotEmpty) 'form_id: $formId',
    'confirmed_form_data: $valuesJson',
  ].join('\n');
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
    this.clientEventClient,
    this.interactionStateStore,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.voiceInput,
    this.voiceInputController,
    this.voicePlaybackCoordinator,
    this.voicePlaybackPlayer,
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
  final AgentStreamClientEventClient? clientEventClient;
  final AgentHubInteractionStateStore? interactionStateStore;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubVoiceInput? voiceInput;
  final AgentVoiceInputController? voiceInputController;
  final AgentVoicePlaybackCoordinator? voicePlaybackCoordinator;
  final AgentVoicePlaybackPlayer? voicePlaybackPlayer;
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
  final ValueNotifier<AgentStreamRunState> _runStateNotifier =
      ValueNotifier<AgentStreamRunState>(const AgentStreamRunState());
  final ValueNotifier<bool> _visibleReplyRunningNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _composerLockedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<_AgentResponseLightRailMode>
  _responseLightRailModeNotifier = ValueNotifier<_AgentResponseLightRailMode>(
    _AgentResponseLightRailMode.idle,
  );
  final ValueNotifier<String?> _activeVoicePlaybackIdNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<int> _actionStateRevisionNotifier = ValueNotifier<int>(0);
  bool _autoVoiceEnabled = true;
  bool _showLatestButton = false;
  bool _showPhotoMenu = false;
  Timer? _persistentWriteTimer;
  Timer? _activeRunPersistentWriteTimer;
  AgentHubInteractionSnapshot? _pendingPersistentSnapshot;
  bool _scrollToLatestFrameScheduled = false;
  bool _scheduledScrollToLatestSmooth = false;
  _PendingAutoVoiceReplay? _pendingAutoVoiceReplay;
  String? _activeAutoVoicePlaybackId;
  String _autoVoiceAppendedText = '';
  AgentVoiceRealtimePlaybackSession? _autoVoiceSession;
  bool _autoVoiceSessionFinished = false;
  VoidCallback? _unsubscribeVoicePlaybackIdle;
  bool _consumedInitialAutoSend = false;

  @override
  void initState() {
    super.initState();
    _restoreCachedInteractionState();
    _publishRunState(_state);
    _restorePersistedInteractionState();
    _applyInitialComposerText();
    _scheduleInitialAutoSendIfNeeded();
    _composerController.addListener(_persistInteractionState);
    _chatScrollController.addListener(_updateLatestButtonVisibility);
    _syncVoicePlaybackIdleSubscription();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateLatestButtonVisibility();
      _maybeStartGreetingVoicePlayback();
    });
  }

  @override
  void didUpdateWidget(covariant AgentHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_interactionState == null &&
        oldWidget.state != widget.state &&
        (widget.runner == null || !_state.isActive)) {
      _setRunState(widget.state);
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
    _persistInteractionState();
    _flushPersistentInteractionState();
    _composerController.removeListener(_persistInteractionState);
    _chatScrollController
      ..removeListener(_updateLatestButtonVisibility)
      ..dispose();
    _composerController.dispose();
    _runStateNotifier.dispose();
    _visibleReplyRunningNotifier.dispose();
    _composerLockedNotifier.dispose();
    _responseLightRailModeNotifier.dispose();
    _activeVoicePlaybackIdNotifier.dispose();
    _actionStateRevisionNotifier.dispose();
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

  void _setRunState(AgentStreamRunState nextState) {
    _state = nextState;
    _publishRunState(nextState);
  }

  void _publishRunState(AgentStreamRunState state) {
    _runStateNotifier.value = state;
    _setNotifierValue(
      _visibleReplyRunningNotifier,
      _isVisibleReplyRunningForState(state),
    );
    _setNotifierValue(
      _composerLockedNotifier,
      _isComposerLockedForState(state),
    );
    _setNotifierValue(
      _responseLightRailModeNotifier,
      _agentResponseLightRailModeForState(state),
    );
  }

  void _setVoiceState(AgentVoiceState nextState) {
    _voiceState = nextState;
    _setNotifierValue(
      _activeVoicePlaybackIdNotifier,
      nextState.isPlaybackActive ? nextState.playbackId : null,
    );
  }

  void _notifyActionStateChanged() {
    _actionStateRevisionNotifier.value += 1;
  }

  void _setNotifierValue<T>(ValueNotifier<T> notifier, T value) {
    if (notifier.value == value) return;
    notifier.value = value;
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
    _state = _restoreInterruptedRunState(
      restoredRunState,
      disconnectedMessage: '连接中断，请重试',
    );
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
    _updateCachedInteractionState();
    _activeRunPersistentWriteTimer?.cancel();
    _activeRunPersistentWriteTimer = null;
    _schedulePersistentInteractionStateWrite(_buildInteractionSnapshot());
  }

  void _persistActiveInteractionStateThrottled() {
    _updateCachedActiveRunState();
    if (widget.interactionStateStore == null ||
        _activeRunPersistentWriteTimer != null) {
      return;
    }
    _activeRunPersistentWriteTimer = Timer(
      _agentActiveRunPersistentWriteInterval,
      () {
        _activeRunPersistentWriteTimer = null;
        _updateCachedInteractionState();
        _schedulePersistentInteractionStateWrite(_buildInteractionSnapshot());
      },
    );
  }

  void _updateCachedInteractionState() {
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
  }

  void _updateCachedActiveRunState() {
    final interactionState = _interactionState;
    if (interactionState == null) return;
    interactionState
      ..runState = _state
      ..autoVoiceEnabled = _autoVoiceEnabled
      ..activeRequest = _activeRequest;
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
    _setRunState(
      _restoreInterruptedRunState(
        snapshot.runState,
        disconnectedMessage: '连接已中断，可继续接收。',
      ),
    );
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

  AgentStreamRunState _restoreInterruptedRunState(
    AgentStreamRunState state, {
    required String disconnectedMessage,
  }) {
    if (!state.isActive) return state;
    if (state.hasCompletedAssistantMessage) return state.finishVisibleReply();
    return state.markDisconnected(disconnectedMessage);
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
    if (text == null || text.isEmpty || _isVisibleReplyRunning) return;
    _composerController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _persistInteractionState();
  }

  void _scheduleInitialAutoSendIfNeeded() {
    if (_consumedInitialAutoSend ||
        !widget.initialAutoSend ||
        widget.runner == null ||
        _isVisibleReplyRunning ||
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
    _scheduledScrollToLatestSmooth = _scheduledScrollToLatestSmooth || smooth;
    if (_scrollToLatestFrameScheduled) return;
    _scrollToLatestFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldSmooth = _scheduledScrollToLatestSmooth;
      _scrollToLatestFrameScheduled = false;
      _scheduledScrollToLatestSmooth = false;
      if (!mounted) return;
      unawaited(
        _scrollToLatest(smooth: shouldSmooth).then((_) {
          if (!shouldSmooth) _scheduleScrollToLatestCorrection();
        }),
      );
    });
  }

  void _scheduleScrollToLatestCorrection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final position = _chatScrollController.position;
      if (position.maxScrollExtent - position.pixels > 1) {
        _chatScrollController.jumpTo(position.maxScrollExtent);
      }
      _updateLatestButtonVisibility();
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

  bool _isComposerLockedForState(AgentStreamRunState state) =>
      state.phase == AgentStreamRunPhase.waitingForConfirmation ||
      state.phase == AgentStreamRunPhase.cancelRequested;

  bool _isVisibleReplyRunningForState(AgentStreamRunState state) =>
      state.isAwaitingVisibleReply;

  bool _canRetryForState(AgentStreamRunState state) =>
      widget.runner != null && state.canRetry && _activeRequest != null;

  bool get _isComposerLocked => _isComposerLockedForState(_state);

  bool get _isVisibleReplyRunning => _isVisibleReplyRunningForState(_state);

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

  Future<void> _sendSyntheticUserMessage({
    required String requestMessage,
    required String optimisticContent,
  }) async {
    final runner = widget.runner;
    if (runner == null || requestMessage.trim().isEmpty || _isComposerLocked) {
      return;
    }

    _cancelCurrentBubblePlaybackForNewTurn();
    final interruptedState = _state.isActive ? _state : null;
    final interruptedRequest = _state.isActive ? _activeRequest : null;
    final request = widget.requestBuilder(requestMessage.trim());
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

  void _handleArtifactAction(AgentArtifactActionView action) {
    if (action.kind == 'form.submit') {
      unawaited(
        _sendSyntheticUserMessage(
          requestMessage: _formSubmitRequestMessage(action),
          optimisticContent: '已提交信息采集表单',
        ),
      );
      return;
    }
    widget.onArtifactAction?.call(action);
  }

  void _handleQuickReplySelected(String text) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty || _isVisibleReplyRunning || _isComposerLocked) {
      return;
    }
    _recordQuickReplyClicked(normalizedText);
    unawaited(
      _sendSyntheticUserMessage(
        requestMessage: normalizedText,
        optimisticContent: normalizedText,
      ),
    );
  }

  void _recordQuickReplyClicked(String text) {
    final clientEventClient = widget.clientEventClient;
    if (clientEventClient == null) return;
    final metadata = <String, Object?>{
      'quick_reply_text': text,
      if (_state.threadId?.trim().isNotEmpty == true)
        'thread_id': _state.threadId,
      if (_state.runId?.trim().isNotEmpty == true) 'run_id': _state.runId,
      if (_state.messageId?.trim().isNotEmpty == true)
        'message_id': _state.messageId,
    };
    unawaited(
      clientEventClient.post(
        AgentStreamClientEventRequest(
          eventType: 'ui.quick_reply.clicked',
          runId: _state.runId,
          label: text,
          occurredAt: DateTime.now().toUtc().toIso8601String(),
          locale: _activeRequest?.locale,
          metadata: metadata,
        ),
      ),
    );
  }

  AgentHubHistoryMessage? _currentAssistantHistoryMessage() {
    final state = _state;
    final text = _agentAssistantTextForState(state).trim();
    if (text.isEmpty) return null;
    return AgentHubHistoryMessage(
      role: AgentHubHistoryRole.assistant,
      content: text,
      runState: state.phase == AgentStreamRunPhase.idle ? null : state,
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
      _setVoiceState(_voiceState.startListening());
    });

    try {
      setState(() {
        _setVoiceState(
          _voiceState.startTranscribing(draft: _composerController.text),
        );
      });
      final result = await _captureVoiceInput();
      if (!mounted) return;
      setState(() {
        if (result.status == AgentVoiceInputResultStatus.permissionDenied) {
          _setVoiceState(
            _voiceState.markPermissionDenied(
              result.permissionState ?? AgentVoiceInputPermissionState.denied,
            ),
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
        _setVoiceState(_voiceState.applyTranscription(text ?? ''));
      });
      _persistInteractionState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setVoiceState(_voiceState.fail(error));
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
    if (_isVisibleReplyRunning) return;
    if (_state.isActive) {
      _sendBestEffortServerCancel(_state, _activeRequest);
    }
    widget.voicePlaybackCoordinator?.cancel();
    _cancelRunSubscription();
    _composerController.clear();
    setState(() {
      _setRunState(const AgentStreamRunState());
      _historyMessages.clear();
      _attachedImages.clear();
      _showPhotoMenu = false;
      _pendingActionIds.clear();
      _localActionStatuses.clear();
      _activeRequest = null;
      _setVoiceState(const AgentVoiceState());
      _pendingAutoVoiceReplay = null;
      _resetAutoVoiceProgress();
    });
    _notifyActionStateChanged();
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

    _setVoiceState(_voiceState.cancelPlayback());
  }

  void _maybeStartGreetingVoicePlayback() {
    final coordinator = widget.voicePlaybackCoordinator;
    final player = widget.voicePlaybackPlayer;
    if (coordinator == null || player == null || !_autoVoiceEnabled) return;

    final result = coordinator.request(
      id: _agentDefaultGreetingPlaybackId,
      source: AgentVoicePlaybackSource.greeting,
      cancel: () => unawaited(player.stop().catchError((Object _) {})),
    );
    final handle = result.handle;
    if (!mounted ||
        result.status != AgentVoicePlaybackRequestStatus.started ||
        handle == null) {
      return;
    }
    _startVoicePlayback(handle: handle, text: _agentDefaultGreeting);
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

  void _handleRunStateUpdate(AgentStreamRunState nextState) {
    if (!mounted || !_state.isActive) return;
    final shouldFollowLatest = _isNearLatest() || nextState.isActive;
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      _activeRequest = _requestWithThreadId(activeRequest, nextState.threadId);
    }
    _applyRunStateUpdate(nextState, shouldFollowLatest: shouldFollowLatest);
  }

  void _applyRunStateUpdate(
    AgentStreamRunState nextState, {
    required bool shouldFollowLatest,
  }) {
    if (!mounted) return;
    _setRunState(nextState);
    if (nextState.isActive) {
      _persistActiveInteractionStateThrottled();
    } else {
      _persistInteractionState();
    }
    _maybeStartAutoVoicePlayback(nextState);
    if (shouldFollowLatest) _scheduleScrollToLatest();
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
      _setRunState(initialState ?? const AgentStreamRunState().start());
      if (initialState == null) {
        _pendingAutoVoiceReplay = null;
        _resetAutoVoiceProgress();
      }
      if (!preserveActionState) {
        _pendingActionIds.clear();
        _localActionStatuses.clear();
      }
    });
    if (!preserveActionState) _notifyActionStateChanged();
    _persistInteractionState();
    _scheduleScrollToLatest();

    _runSubscription = runner
        .run(requestWithThread, initialState: initialState)
        .listen(
          _handleRunStateUpdate,
          onError: (Object error) {
            if (!mounted || !_state.isActive) return;
            final shouldFollowLatest = _isNearLatest();
            _setRunState(_state.markDisconnected(error));
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
    final player = widget.voicePlaybackPlayer;
    final text = nextState.textContent.trim();
    if (coordinator == null ||
        player == null ||
        !_autoVoiceEnabled ||
        !_canAutoVoicePlayback(nextState.phase) ||
        text.isEmpty) {
      return;
    }

    final playbackId = _autoVoicePlaybackId(nextState);
    final isNewPlayback = _activeAutoVoicePlaybackId != playbackId;
    if (isNewPlayback) {
      _cancelActiveAutoVoiceSession();
      _activeAutoVoicePlaybackId = playbackId;
      _autoVoiceAppendedText = '';
      _autoVoiceSessionFinished = false;
    }

    final session = _autoVoiceSession ?? _startAutoVoiceSession(playbackId);
    if (session == null) {
      if (coordinator.activeSource != AgentVoicePlaybackSource.autoReply ||
          coordinator.activeId != playbackId) {
        _queueBlockedAutoVoiceReplay(nextState);
      }
      return;
    }

    _pendingAutoVoiceReplay = null;
    final textToAppend = _nextAutoVoiceTextToAppend(text);
    if (textToAppend.trim().isNotEmpty) {
      session.append(textToAppend);
      _autoVoiceAppendedText = text;
    }
    if (_shouldFinishAutoVoicePlayback(nextState)) {
      _finishActiveAutoVoiceSession();
    }
  }

  AgentVoiceRealtimePlaybackSession? _startAutoVoiceSession(String playbackId) {
    final coordinator = widget.voicePlaybackCoordinator;
    final player = widget.voicePlaybackPlayer;
    if (coordinator == null || player == null) return null;

    final result = coordinator.request(
      id: playbackId,
      source: AgentVoicePlaybackSource.autoReply,
      cancel: _cancelActiveAutoVoiceSession,
    );
    if (result.status == AgentVoicePlaybackRequestStatus.blocked) return null;
    final handle = result.handle;
    if (!mounted ||
        result.status != AgentVoicePlaybackRequestStatus.started ||
        handle == null) {
      return null;
    }

    final session = player.startRealtimeSession();
    _autoVoiceSession = session;
    _autoVoiceSessionFinished = false;
    _setVoiceState(_voiceState.startPlayback(handle.id));
    unawaited(
      session.done
          .then((_) {
            if (!mounted || !handle.isCurrent || _autoVoiceSession != session) {
              return;
            }
            _autoVoiceSession = null;
            handle.finish();
            _setVoiceState(const AgentVoiceState());
          })
          .catchError((Object error) {
            if (!mounted || !handle.isCurrent || _autoVoiceSession != session) {
              return;
            }
            _autoVoiceSession = null;
            handle.finish();
            _setVoiceState(_voiceState.fail(error));
          }),
    );
    return session;
  }

  void _startVoicePlayback({
    required AgentVoicePlaybackHandle handle,
    required String text,
    VoidCallback? onFinished,
  }) {
    _setVoiceState(_voiceState.startPlayback(handle.id));
    final player = widget.voicePlaybackPlayer;
    if (player == null) return;

    unawaited(
      player
          .playText(text)
          .then((_) {
            if (!mounted || !handle.isCurrent) return;
            handle.finish();
            _setVoiceState(const AgentVoiceState());
            onFinished?.call();
          })
          .catchError((Object error) {
            if (!mounted || !handle.isCurrent) return;
            handle.finish();
            _setVoiceState(_voiceState.fail(error));
          }),
    );
  }

  String _autoVoicePlaybackId(AgentStreamRunState state) {
    final activePlaybackId = _activeAutoVoicePlaybackId?.trim();
    if (activePlaybackId != null &&
        activePlaybackId.isNotEmpty &&
        (state.isActive ||
            _pendingAutoVoiceReplay != null ||
            _autoVoiceAppendedText.isNotEmpty)) {
      return activePlaybackId;
    }
    return _firstNonEmpty([state.messageId, state.runId, state.threadId]) ?? '';
  }

  bool _canAutoVoicePlayback(AgentStreamRunPhase phase) {
    return phase == AgentStreamRunPhase.streaming ||
        phase == AgentStreamRunPhase.waitingForConfirmation ||
        phase == AgentStreamRunPhase.finished;
  }

  String _nextAutoVoiceTextToAppend(String text) {
    if (_autoVoiceAppendedText.isEmpty) return text;
    if (text.startsWith(_autoVoiceAppendedText)) {
      return text.substring(_autoVoiceAppendedText.length);
    }
    if (_autoVoiceAppendedText.length >= text.length) return '';
    return text.substring(_autoVoiceAppendedText.length);
  }

  bool _shouldFinishAutoVoicePlayback(AgentStreamRunState state) {
    return state.hasCompletedAssistantMessage ||
        state.phase == AgentStreamRunPhase.finished ||
        state.phase == AgentStreamRunPhase.waitingForConfirmation;
  }

  void _finishActiveAutoVoiceSession() {
    if (_autoVoiceSessionFinished) return;
    _autoVoiceSessionFinished = true;
    _autoVoiceSession?.finish();
  }

  void _cancelActiveAutoVoiceSession() {
    final session = _autoVoiceSession;
    _autoVoiceSession = null;
    _autoVoiceSessionFinished = false;
    if (session != null) {
      unawaited(session.cancel().catchError((Object _) {}));
    }
    if (mounted &&
        _voiceState.isPlaybackActive &&
        _voiceState.playbackId == _activeAutoVoicePlaybackId) {
      _setVoiceState(_voiceState.cancelPlayback());
    }
  }

  void _resetAutoVoiceProgress() {
    _cancelActiveAutoVoiceSession();
    _activeAutoVoicePlaybackId = null;
    _autoVoiceAppendedText = '';
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
    widget.voicePlaybackCoordinator?.cancel();
    _pendingAutoVoiceReplay = null;
    _resetAutoVoiceProgress();
    _setRunState(activeState.requestCancel());
    _persistInteractionState();
    _cancelRunSubscription();
    _setRunState(_state.applyCancelResult(acknowledged: true));
    _persistInteractionState();
    _sendBestEffortServerCancel(activeState, activeRequest);
  }

  void _toggleAutoVoice() {
    setState(() {
      final nextEnabled = !_autoVoiceEnabled;
      if (!nextEnabled) {
        widget.voicePlaybackCoordinator?.cancel();
        _pendingAutoVoiceReplay = null;
        _resetAutoVoiceProgress();
        if (_voiceState.isPlaybackActive) {
          _setVoiceState(_voiceState.cancelPlayback());
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
    _pendingActionIds.add(action.id);
    _localActionStatuses[action.id] = 'confirming';
    _notifyActionStateChanged();

    final result = await actionClient.confirm(
      AgentStreamActionConfirmRequest(actionId: action.id),
    );
    if (!mounted) return;
    _pendingActionIds.remove(action.id);
    _localActionStatuses[action.id] = result.accepted
        ? _acceptedConfirmStatus(result.actionStatus)
        : 'failed';
    _applyActionResultEvents(result.events);
    _notifyActionStateChanged();
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
    _pendingActionIds.add(action.id);
    _localActionStatuses[action.id] = 'rejecting';
    _notifyActionStateChanged();

    final result = await actionClient.reject(
      AgentStreamActionRejectRequest(
        actionId: action.id,
        reason: 'user_rejected',
      ),
    );
    if (!mounted) return;
    _pendingActionIds.remove(action.id);
    _localActionStatuses[action.id] = result.accepted
        ? result.actionStatus ?? 'rejected'
        : 'failed';
    _applyActionResultEvents(result.events);
    _notifyActionStateChanged();
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
    _setRunState(nextState);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('agent-hub-page'),
      color: MomCozyColors.background,
      child: Stack(
        children: [
          ValueListenableBuilder<_AgentResponseLightRailMode>(
            valueListenable: _responseLightRailModeNotifier,
            builder: (context, mode, child) {
              if (mode == _AgentResponseLightRailMode.idle) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: _AgentResponseLightRail(mode: mode),
              );
            },
          ),
          Column(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _visibleReplyRunningNotifier,
                builder: (context, isVisibleReplyRunning, child) {
                  return AgentHubTopBar(
                    showControls: true,
                    autoVoiceEnabled: _autoVoiceEnabled,
                    isRunning: isVisibleReplyRunning,
                    onToggleAutoVoice: _toggleAutoVoice,
                    onNewSession: _startNewSession,
                  );
                },
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
                            if (_historyMessages.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  14,
                                  12,
                                  0,
                                ),
                                sliver: AgentHubHistorySliver(
                                  messages: _historyMessages,
                                  onArtifactAction: _handleArtifactAction,
                                ),
                              ),
                            if (_historyMessages.isNotEmpty)
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 18),
                              ),
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                12,
                                _historyMessages.isEmpty ? 14 : 0,
                                12,
                                24,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: _historyMessages.isEmpty
                                        ? transcriptMinHeight
                                        : 0,
                                  ),
                                  child: _AgentRunTranscriptListenable(
                                    stateListenable: _runStateNotifier,
                                    activeVoicePlaybackIdListenable:
                                        _activeVoicePlaybackIdNotifier,
                                    actionStateRevisionListenable:
                                        _actionStateRevisionNotifier,
                                    canRetryForState: _canRetryForState,
                                    onRetry: _retryRun,
                                    onArtifactAction: _handleArtifactAction,
                                    onQuickReplySelected:
                                        _handleQuickReplySelected,
                                    pendingActionIds: _pendingActionIds,
                                    localActionStatuses: _localActionStatuses,
                                    onConfirmAction: widget.actionClient == null
                                        ? null
                                        : _confirmAction,
                                    onRejectAction: widget.actionClient == null
                                        ? null
                                        : _rejectAction,
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
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              label: const Text('回到最新消息'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([
                  _visibleReplyRunningNotifier,
                  _composerLockedNotifier,
                ]),
                builder: (context, child) {
                  final runState = _runStateNotifier.value;
                  final isVisibleReplyRunning =
                      _visibleReplyRunningNotifier.value;
                  final isComposerLocked = _composerLockedNotifier.value;
                  return AgentComposerBar(
                    controller: _composerController,
                    canSend: widget.runner != null && !isComposerLocked,
                    isRunning: isVisibleReplyRunning,
                    isInputLocked: isComposerLocked,
                    imageCount: _attachedImages.length,
                    showPhotoMenu: _showPhotoMenu,
                    canAttachImage:
                        widget.pickImage != null && !isComposerLocked,
                    canUseVoice:
                        (widget.voiceInputController != null ||
                            widget.voiceInput != null) &&
                        !_isVisibleReplyRunningForState(runState) &&
                        !isComposerLocked &&
                        !_voiceState.isInputActive,
                    voicePhase: _voiceState.phase,
                    voicePlaybackFailed:
                        _voiceState.phase == AgentVoicePhase.error &&
                        _voiceState.playbackId != null,
                    onChanged: (_) {},
                    onSend: _sendMessage,
                    onCancel: _cancelRun,
                    onTogglePhotoMenu: _togglePhotoMenu,
                    onAttachImage: _attachImage,
                    onRemoveImages: _removeAttachedImages,
                    onVoiceInput: _startVoiceInput,
                  );
                },
              ),
            ],
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

enum _AgentResponseLightRailMode { idle, loop, replying }

_AgentResponseLightRailMode _agentResponseLightRailModeForState(
  AgentStreamRunState state,
) {
  if (!state.isAwaitingVisibleReply) return _AgentResponseLightRailMode.idle;
  final hasReplyText =
      state.textContent.trim().isNotEmpty ||
      state.provisionalTextContent.trim().isNotEmpty;
  if (!hasReplyText) return _AgentResponseLightRailMode.loop;
  if (_hasRunningToolWork(state)) {
    return _AgentResponseLightRailMode.loop;
  }
  return _AgentResponseLightRailMode.replying;
}

bool _hasRunningToolWork(AgentStreamRunState state) {
  final toolEvents = state.toolEvents.isNotEmpty
      ? state.toolEvents.values
      : _latestToolEventsFromLegacyEvents(state.events).values;
  return toolEvents.any(
    (event) => event.type == 'tool.started' || event.type == 'tool.progress',
  );
}

Map<String, AgentStreamEvent> _latestToolEventsFromLegacyEvents(
  List<AgentStreamEvent> events,
) {
  final latestToolEvents = <String, AgentStreamEvent>{};
  for (final event in events) {
    if (!event.type.startsWith('tool.')) continue;
    latestToolEvents[event.toolCallId ?? event.mergeKey] = event;
  }
  return latestToolEvents;
}

class _AgentResponseLightRail extends StatefulWidget {
  const _AgentResponseLightRail({required this.mode});

  final _AgentResponseLightRailMode mode;

  @override
  State<_AgentResponseLightRail> createState() =>
      _AgentResponseLightRailState();
}

class _AgentResponseLightRailState extends State<_AgentResponseLightRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForMode(widget.mode),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AgentResponseLightRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == oldWidget.mode) return;
    _controller.duration = _durationForMode(widget.mode);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      key: const ValueKey('agent-response-light-rail'),
      child: RepaintBoundary(
        child: CustomPaint(
          key: ValueKey('agent-response-light-rail-${widget.mode.name}'),
          painter: _AgentResponseLightRailPainter(
            mode: widget.mode,
            animation: _controller,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Duration _durationForMode(_AgentResponseLightRailMode mode) {
    return switch (mode) {
      _AgentResponseLightRailMode.loop => const Duration(milliseconds: 1050),
      _AgentResponseLightRailMode.replying => const Duration(
        milliseconds: 3200,
      ),
      _AgentResponseLightRailMode.idle => const Duration(milliseconds: 1600),
    };
  }
}

class _AgentResponseLightRailPainter extends CustomPainter {
  const _AgentResponseLightRailPainter({
    required this.mode,
    required Animation<double> animation,
  }) : _animation = animation,
       super(repaint: animation);

  final _AgentResponseLightRailMode mode;
  final Animation<double> _animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final railWidth = math.min(size.width, MomCozyLayout.maxAppWidth);
    final railRect = Rect.fromLTWH(
      (size.width - railWidth) / 2,
      0,
      railWidth,
      size.height,
    );
    final progress = _animation.value;
    final modeStrength = mode == _AgentResponseLightRailMode.loop ? 1.0 : 0.62;

    _paintPageGlow(canvas, railRect, progress, modeStrength);
    _paintRailBorder(canvas, railRect, progress, modeStrength);
  }

  void _paintPageGlow(
    Canvas canvas,
    Rect rect,
    double progress,
    double modeStrength,
  ) {
    final breath = (math.sin(progress * math.pi * 2) + 1) / 2;
    final opacity = (0.15 + breath * 0.12) * modeStrength;
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.82),
        radius: 1.15,
        colors: [
          const Color(0xffffeef5).withValues(alpha: opacity * 1.10),
          const Color(0xffecacc3).withValues(alpha: opacity * 0.44),
          Colors.transparent,
        ],
        stops: const [0, 0.34, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final lowerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xffffe8f0).withValues(alpha: opacity * 0.42),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, lowerPaint);
  }

  void _paintRailBorder(
    Canvas canvas,
    Rect rect,
    double progress,
    double modeStrength,
  ) {
    final borderWidth = mode == _AgentResponseLightRailMode.loop ? 2.5 : 2.0;
    final outer = Path()..addRect(rect);
    final inner = Path()..addRect(rect.deflate(borderWidth));
    final border = Path.combine(PathOperation.difference, outer, inner);
    final shader = SweepGradient(
      transform: GradientRotation(progress * math.pi * 2),
      colors: [
        Colors.transparent,
        const Color(0xfff6d2de).withValues(alpha: 0.34 * modeStrength),
        const Color(0xffdc7897).withValues(alpha: 0.82 * modeStrength),
        Colors.white.withValues(alpha: 0.92 * modeStrength),
        const Color(0xffe4a060).withValues(alpha: 0.54 * modeStrength),
        Colors.transparent,
        const Color(0xff7dbcb1).withValues(alpha: 0.42 * modeStrength),
        Colors.white.withValues(alpha: 0.60 * modeStrength),
        Colors.transparent,
      ],
      stops: const [0, 0.08, 0.13, 0.17, 0.23, 0.40, 0.55, 0.62, 1],
    ).createShader(rect);
    canvas.drawPath(border, Paint()..shader = shader);

    final sideGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mode == _AgentResponseLightRailMode.loop ? 9 : 7
      ..color = const Color(0xffd67697).withValues(
        alpha: (mode == _AgentResponseLightRailMode.loop ? 0.14 : 0.08),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRect(rect.deflate(4), sideGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _AgentResponseLightRailPainter oldDelegate) {
    return oldDelegate.mode != mode || oldDelegate._animation != _animation;
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

class AgentHubHistorySliver extends StatelessWidget {
  const AgentHubHistorySliver({
    super.key,
    required this.messages,
    this.onArtifactAction,
  });

  final List<AgentHubHistoryMessage> messages;
  final AgentArtifactActionHandler? onArtifactAction;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.isEmpty ? 0 : messages.length * 2 - 1;
    return SliverList(
      key: const ValueKey('agent-history-panel'),
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index.isOdd) return const SizedBox(height: 20);
        final messageIndex = index ~/ 2;
        return _AgentHistoryBubble(
          key: ValueKey('agent-history-$messageIndex'),
          message: messages[messageIndex],
          onArtifactAction: onArtifactAction,
        );
      }, childCount: itemCount),
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

class _AgentRunTranscriptListenable extends StatefulWidget {
  const _AgentRunTranscriptListenable({
    required this.stateListenable,
    required this.activeVoicePlaybackIdListenable,
    required this.actionStateRevisionListenable,
    required this.canRetryForState,
    this.onRetry,
    this.onArtifactAction,
    this.onQuickReplySelected,
    required this.pendingActionIds,
    required this.localActionStatuses,
    this.onConfirmAction,
    this.onRejectAction,
  });

  final ValueListenable<AgentStreamRunState> stateListenable;
  final ValueListenable<String?> activeVoicePlaybackIdListenable;
  final ValueListenable<int> actionStateRevisionListenable;
  final bool Function(AgentStreamRunState state) canRetryForState;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;
  final ValueChanged<String>? onQuickReplySelected;
  final Set<String> pendingActionIds;
  final Map<String, String> localActionStatuses;
  final ValueChanged<AgentActionCardView>? onConfirmAction;
  final ValueChanged<AgentActionCardView>? onRejectAction;

  @override
  State<_AgentRunTranscriptListenable> createState() =>
      _AgentRunTranscriptListenableState();
}

class _AgentRunTranscriptListenableState
    extends State<_AgentRunTranscriptListenable> {
  Object? _artifactSourceIdentity;
  List<AgentArtifactCardView> _artifactCards = const <AgentArtifactCardView>[];
  Object? _actionSourceIdentity;
  int? _actionRevision;
  List<AgentActionCardView> _actionCards = const <AgentActionCardView>[];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.stateListenable,
        widget.activeVoicePlaybackIdListenable,
        widget.actionStateRevisionListenable,
      ]),
      builder: (context, child) {
        final state = widget.stateListenable.value;
        final actionRevision = widget.actionStateRevisionListenable.value;
        return AgentRunTranscript(
          state: state,
          activeVoicePlaybackId: widget.activeVoicePlaybackIdListenable.value,
          canRetry: widget.canRetryForState(state),
          onRetry: widget.onRetry,
          onArtifactAction: widget.onArtifactAction,
          onQuickReplySelected: widget.onQuickReplySelected,
          pendingActionIds: widget.pendingActionIds,
          artifactCards: _artifactCardsForState(state),
          actionCards: _actionCardsForState(state, actionRevision),
          onConfirmAction: widget.onConfirmAction,
          onRejectAction: widget.onRejectAction,
        );
      },
    );
  }

  List<AgentArtifactCardView> _artifactCardsForState(
    AgentStreamRunState state,
  ) {
    final identity = state.artifactEvents.isNotEmpty
        ? state.artifactEvents
        : state.events;
    if (identical(identity, _artifactSourceIdentity)) return _artifactCards;
    _artifactSourceIdentity = identity;
    _artifactCards = _artifactCardsFromEvents(_artifactEventsForState(state));
    return _artifactCards;
  }

  List<AgentActionCardView> _actionCardsForState(
    AgentStreamRunState state,
    int actionRevision,
  ) {
    final identity = state.actionEvents.isNotEmpty
        ? state.actionEvents
        : state.events;
    if (identical(identity, _actionSourceIdentity) &&
        actionRevision == _actionRevision) {
      return _actionCards;
    }
    _actionSourceIdentity = identity;
    _actionRevision = actionRevision;
    _actionCards = _actionCardsFromEvents(
      _actionEventsForState(state),
      widget.localActionStatuses,
    );
    return _actionCards;
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
    this.onQuickReplySelected,
    this.pendingActionIds = const <String>{},
    this.localActionStatuses = const <String, String>{},
    this.artifactCards,
    this.actionCards,
    this.onConfirmAction,
    this.onRejectAction,
  });

  final AgentStreamRunState state;
  final String? activeVoicePlaybackId;
  final bool canRetry;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;
  final ValueChanged<String>? onQuickReplySelected;
  final Set<String> pendingActionIds;
  final Map<String, String> localActionStatuses;
  final List<AgentArtifactCardView>? artifactCards;
  final List<AgentActionCardView>? actionCards;
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
    final artifactCards =
        this.artifactCards ??
        _artifactCardsFromEvents(_artifactEventsForState(state));
    final actionCards =
        this.actionCards ??
        _actionCardsFromEvents(
          _actionEventsForState(state),
          localActionStatuses,
        );
    final quickReplies = state.quickReplies;
    final shouldRenderQuickReplies =
        quickReplies.isNotEmpty &&
        !state.isAwaitingVisibleReply &&
        onQuickReplySelected != null;
    final avatarMode = _avatarMode;
    final loopDecor = _loopDecorState;
    final thinkingNoteTitle = loopDecor.thinkingTitle;
    final statusLineTitle = loopDecor.statusTitle;
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
                if (thinkingNoteTitle != null || shouldRenderPrimaryText)
                  const SizedBox(height: 5),
              ],
              if (thinkingNoteTitle != null) ...[
                AgentThinkingNote(title: thinkingNoteTitle),
                if (shouldRenderPrimaryText) const SizedBox(height: 8),
              ],
              if (shouldRenderPrimaryText)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDefaultGreeting ? 260 : double.infinity,
                    ),
                    child: AgentMarkdownText(
                      text,
                      style: primaryTextStyle,
                      onArtifactAction: onArtifactAction,
                      parseMarkdown: _shouldParsePrimaryTextMarkdown,
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
              if (shouldRenderQuickReplies) ...[
                const SizedBox(height: 16),
                AgentQuickRepliesBar(
                  replies: quickReplies,
                  onSelected: onQuickReplySelected!,
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

  bool get _shouldParsePrimaryTextMarkdown {
    return !state.isActive || state.hasCompletedAssistantMessage;
  }

  _AgentLoopDecorState get _loopDecorState {
    if (state.phase != AgentStreamRunPhase.streaming ||
        state.textContent.trim().isNotEmpty) {
      return const _AgentLoopDecorState();
    }
    return _agentLoopDecorStateFromEvents(state.events);
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
    final statePlaybackIds = [
      state.messageId,
      state.runId,
      state.threadId,
    ].map((id) => id?.trim()).whereType<String>().where((id) => id.isNotEmpty);
    if (playbackId != null &&
        playbackId.isNotEmpty &&
        statePlaybackIds.contains(playbackId)) {
      return _AgentAssistantAvatarMode.speaking;
    }
    if (state.isAwaitingVisibleReply) {
      return _AgentAssistantAvatarMode.thinking;
    }
    return null;
  }
}

class AgentQuickRepliesBar extends StatelessWidget {
  const AgentQuickRepliesBar({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  final List<String> replies;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (replies.length != 3) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: const Color(0xff9b7a84),
      fontWeight: FontWeight.w600,
      height: 1,
    );
    final replyStyle = textTheme.bodySmall?.copyWith(
      color: const Color(0xff4a3a40),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.22,
    );

    return Column(
      key: const ValueKey('agent-quick-replies'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('agent-quick-replies-title-line'),
                width: 16,
                height: 1,
                decoration: BoxDecoration(
                  color: const Color(0xffdbc3cb),
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '猜你想说',
                key: const ValueKey('agent-quick-replies-title'),
                style: labelStyle,
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < replies.length; index++)
              _AgentQuickReplyPill(
                key: ValueKey('agent-quick-reply-$index'),
                text: replies[index],
                textStyle: replyStyle,
                onSelected: onSelected,
              ),
          ],
        ),
      ],
    );
  }
}

class _AgentQuickReplyPill extends StatelessWidget {
  const _AgentQuickReplyPill({
    super.key,
    required this.text,
    required this.textStyle,
    required this.onSelected,
  });

  final String text;
  final TextStyle? textStyle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(text),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        splashColor: const Color(0xfff8edf2),
        highlightColor: const Color(0xfff8edf2).withValues(alpha: 0.58),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34, maxWidth: 260),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x9effffff),
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              border: Border.all(color: const Color(0xffeadde2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  key: ValueKey('agent-quick-reply-chevron'),
                  size: 16,
                  color: Color(0xffb78294),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgentMarkdownText extends StatelessWidget {
  const AgentMarkdownText(
    this.text, {
    super.key,
    this.style,
    this.onArtifactAction,
    this.parseMarkdown = true,
  });

  final String text;
  final TextStyle? style;
  final AgentArtifactActionHandler? onArtifactAction;
  final bool parseMarkdown;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trim();
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    if (!parseMarkdown) {
      return Text(normalized, style: baseStyle);
    }
    final markdown = _prepareAgentMarkdown(normalized);
    if (!_containsMarkdown(markdown)) {
      return Text(normalized, style: baseStyle);
    }

    return MarkdownBody(
      data: markdown,
      fitContent: true,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: _momcozyMarkdownStyleSheet(context, baseStyle),
      imageBuilder: (uri, title, alt) {
        final url = uri.toString();
        return _AgentMarkdownImage(
          url: url,
          title: alt?.trim().isNotEmpty == true ? alt!.trim() : title,
          onTap: () => _openMarkdownMedia(url: url, title: alt ?? title),
        );
      },
      onTapLink: (label, href, title) {
        final url = href?.trim();
        if (url == null || url.isEmpty) return;
        if (_isHospitalBagCartPath(url)) {
          onArtifactAction?.call(_hospitalBagCartAction());
          return;
        }
        _openMarkdownMedia(url: url, title: label.trim());
      },
    );
  }

  void _openMarkdownMedia({required String url, String? title}) {
    final kind = _viewerKindForUrl(url);
    if (kind == null) return;
    final normalizedTitle = title?.trim();
    onArtifactAction?.call(
      AgentArtifactActionView(
        label: normalizedTitle?.isNotEmpty == true ? normalizedTitle! : '打开资源',
        icon: _mediaIconForKind(kind),
        kind: 'media',
        value: url,
        routePath: '/media-viewer',
        routeExtra: {
          'kind': kind,
          'url': url,
          if (normalizedTitle?.isNotEmpty == true) 'title': normalizedTitle!,
        },
      ),
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

class _AgentMarkdownImage extends StatelessWidget {
  const _AgentMarkdownImage({required this.url, this.title, this.onTap});

  final String url;
  final String? title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim().isNotEmpty == true ? title!.trim() : '查看图片';
    final displayUrl = _displayableHttpUrl(url);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        key: ValueKey('agent-markdown-image-$url'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 112,
              maxHeight: 220,
              minWidth: 180,
              maxWidth: 360,
            ),
            child: displayUrl == null
                ? _AgentMarkdownImagePlaceholder(label: label)
                : Image.network(
                    displayUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _AgentMarkdownImagePlaceholder(label: label);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _AgentMarkdownImagePlaceholder extends StatelessWidget {
  const _AgentMarkdownImagePlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.72),
        border: Border.all(color: MomCozyColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_outlined,
              color: MomCozyColors.mutedForeground,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '点开查看',
              style: textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _prepareAgentMarkdown(String markdown) {
  return _promoteImageLinksToMarkdownImages(
    _linkifyBareSkillAssetUrlsForMarkdown(markdown),
  );
}

String _linkifyBareSkillAssetUrlsForMarkdown(String markdown) {
  var inFence = false;
  return markdown
      .split('\n')
      .map((line) {
        if (RegExp(r'^\s*```').hasMatch(line)) {
          inFence = !inFence;
          return line;
        }
        if (inFence) return line;
        return line.replaceAllMapped(_bareSkillAssetUrlPattern, (match) {
          final prefix = match.group(1) ?? '';
          final url = match.group(2) ?? '';
          return '$prefix[${_skillAssetLinkLabel(url)}]($url)';
        });
      })
      .join('\n');
}

String _promoteImageLinksToMarkdownImages(String markdown) {
  var inFence = false;
  return markdown
      .split('\n')
      .map((line) {
        if (RegExp(r'^\s*```').hasMatch(line)) {
          inFence = !inFence;
          return line;
        }
        if (inFence) return line;
        return line.replaceAllMapped(_markdownLinkPattern, (match) {
          final prefix = match.group(1) ?? '';
          final label = match.group(2) ?? '';
          final destination = match.group(3) ?? '';
          final url = _markdownDestinationUrl(destination);
          if (!_isImageUrl(url)) return match.group(0) ?? '';
          return '$prefix![$label]($destination)';
        });
      })
      .join('\n');
}

String _skillAssetLinkLabel(String url) {
  final kind = _viewerKindForUrl(url);
  return switch (kind) {
    'pdf' => '打开 PDF',
    'video' => '打开视频',
    'image' => '查看图片',
    _ => '打开资源',
  };
}

String _markdownDestinationUrl(String destination) {
  return destination.trim().split(RegExp(r'\s+')).first;
}

String? _viewerKindForUrl(String url) {
  final path = url.split(RegExp(r'[?#]')).first.toLowerCase();
  if (path.endsWith('.pdf')) return 'pdf';
  if (RegExp(r'\.(mp4|webm|ogv|m4v|mov)$').hasMatch(path)) return 'video';
  if (RegExp(r'\.(png|jpe?g|gif|webp|svg|bmp|ico|avif)$').hasMatch(path)) {
    return 'image';
  }
  return null;
}

bool _isImageUrl(String url) => _viewerKindForUrl(url) == 'image';

IconData _mediaIconForKind(String kind) {
  return switch (kind) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'video' => Icons.play_circle_outline_rounded,
    _ => Icons.image_outlined,
  };
}

bool _isHospitalBagCartPath(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.path == '/hospital-bag-cart';
}

String? _displayableHttpUrl(String url) {
  final normalized = url.trim();
  if (normalized.startsWith('/skill-assets/')) {
    return Uri.tryParse(
      _agentSkillAssetBaseUrl,
    )?.resolve(normalized).toString();
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) return null;
  if (uri.scheme == 'http' || uri.scheme == 'https') return uri.toString();
  return null;
}

final _bareSkillAssetUrlPattern = RegExp(
  r'(^|[\s:：])((?:/skill-assets/)[^\s<>)\]}，。；;、]+(?:\.(?:pdf|mp4|mov|m4v|webm|png|jpe?g|gif|webp|svg))(?:[?#][^\s<>)\]}，。；;、]*)?)',
  caseSensitive: false,
);

final _markdownLinkPattern = RegExp(r'(^|[^!])\[([^\]\n]+)\]\(([^)\n]+)\)');

class AgentRunStatusLine extends StatefulWidget {
  const AgentRunStatusLine({super.key, required this.title});

  final String title;

  @override
  State<AgentRunStatusLine> createState() => _AgentRunStatusLineState();
}

class _AgentRunStatusLineState extends State<AgentRunStatusLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final title = widget.title;

    return Semantics(
      label: title,
      child: Container(
        key: const ValueKey('agent-run-status-line'),
        constraints: const BoxConstraints(maxWidth: double.infinity),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 10,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final value = Curves.easeOutCubic.transform(
                    _pulseController.value,
                  );
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: 0.9 + value * 0.45,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(
                              alpha: 0.28 - value * 0.18,
                            ),
                          ),
                          child: const SizedBox.square(dimension: 8),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.86),
                        ),
                        child: const SizedBox.square(dimension: 5),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: _AgentSweepText(
                title,
                sweepKey: const ValueKey('agent-run-status-title-sweep'),
                animation: _pulseController,
                colors: const [
                  Color(0xff9a7a86),
                  Color(0xff5d3f4d),
                  Color(0xff9a7a86),
                ],
                style: textTheme.labelSmall?.copyWith(
                  height: 1.45,
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

class _AgentSweepText extends StatelessWidget {
  const _AgentSweepText(
    this.text, {
    required this.sweepKey,
    required this.animation,
    required this.colors,
    this.style,
  });

  final String text;
  final Key sweepKey;
  final Animation<double> animation;
  final List<Color> colors;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return ShaderMask(
          key: sweepKey,
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.2 + value * 2.4, 0),
              end: Alignment(-0.2 + value * 2.4, 0),
              colors: colors,
              stops: const [0, 0.5, 1],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class AgentThinkingNote extends StatefulWidget {
  const AgentThinkingNote({super.key, required this.title});

  final String title;

  @override
  State<AgentThinkingNote> createState() => _AgentThinkingNoteState();
}

class _AgentThinkingNoteState extends State<AgentThinkingNote>
    with SingleTickerProviderStateMixin {
  static const _sweepDuration = Duration(milliseconds: 760);

  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _sweepDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: widget.title,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: _AgentSweepText(
          widget.title,
          sweepKey: const ValueKey('agent-thinking-note'),
          animation: _sweepController,
          colors: const [
            Color(0xff98a3af),
            Color(0xff2d3745),
            Color(0xff98a3af),
          ],
          style: textTheme.labelSmall?.copyWith(
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

enum _AgentAssistantAvatarMode { thinking, speaking }

class _AgentAssistantAvatar extends StatefulWidget {
  const _AgentAssistantAvatar({this.mode});

  final _AgentAssistantAvatarMode? mode;

  @override
  State<_AgentAssistantAvatar> createState() => _AgentAssistantAvatarState();
}

class _AgentAssistantAvatarState extends State<_AgentAssistantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  VideoPlayerController? _videoController;
  String? _videoAsset;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulseController();
    _syncVideoController();
  }

  @override
  void didUpdateWidget(covariant _AgentAssistantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncPulseController();
      _syncVideoController();
    }
  }

  @override
  void dispose() {
    _disposeVideoController();
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulseController() {
    if (_activeAvatarAsset() == null) {
      _pulseController.stop();
      _pulseController.value = 0;
      return;
    }
    if (!_pulseController.isAnimating) _pulseController.repeat();
  }

  void _syncVideoController() {
    final asset = _activeAvatarAsset();
    if (asset == null) {
      _disposeVideoController();
      return;
    }
    if (_videoController != null && _videoAsset == asset) return;

    _disposeVideoController();
    _videoAsset = asset;
    _videoReady = false;
    final controller = VideoPlayerController.asset(asset);
    _videoController = controller;

    unawaited(
      controller
          .initialize()
          .then((_) async {
            if (!mounted || _videoController != controller) return;
            await controller.setLooping(true);
            await controller.setVolume(0);
            await controller.play();
            if (!mounted || _videoController != controller) return;
            setState(() {
              _videoReady = true;
            });
          })
          .catchError((Object _) {
            if (!mounted || _videoController != controller) return;
            setState(() {
              _videoReady = false;
            });
          }),
    );
  }

  void _disposeVideoController() {
    final controller = _videoController;
    _videoController = null;
    _videoAsset = null;
    _videoReady = false;
    if (controller != null) unawaited(controller.dispose());
  }

  String? _activeAvatarAsset() {
    if (!_shouldAnimateAvatar()) return null;
    return switch (widget.mode) {
      _AgentAssistantAvatarMode.speaking => MomCozyAssets.agentSpeakingAvatar,
      _AgentAssistantAvatarMode.thinking => MomCozyAssets.agentThinkingAvatar,
      null => null,
    };
  }

  bool _shouldAnimateAvatar() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TickerMode.valuesOf(context).enabled && !disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final shouldAnimate = _shouldAnimateAvatar();
    final isSpeakingMode = mode == _AgentAssistantAvatarMode.speaking;
    final isThinkingMode = mode == _AgentAssistantAvatarMode.thinking;
    final isActiveMode = isSpeakingMode || isThinkingMode;
    final showSpeakingVideo = shouldAnimate && isSpeakingMode;
    final showThinkingVideo = shouldAnimate && isThinkingMode;
    final ringColor = isSpeakingMode
        ? const Color(0xffaa647d)
        : const Color(0xff8bbdb5);
    final activeAvatarKey = showSpeakingVideo
        ? 'agent-assistant-avatar-speaking-media'
        : showThinkingVideo
        ? 'agent-assistant-avatar-thinking-media'
        : null;
    final videoController = _videoController;

    return SizedBox.square(
      key: const ValueKey('agent-assistant-avatar'),
      dimension: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (isActiveMode)
            Positioned(
              left: -2,
              right: -2,
              top: -2,
              bottom: -2,
              child: AnimatedBuilder(
                key: ValueKey('agent-avatar-pulse-$mode'),
                animation: _pulseController,
                builder: (context, child) {
                  final pulse = Curves.easeOutCubic.transform(
                    _pulseController.value,
                  );
                  return Transform.scale(
                    scale: 1 + pulse * (isSpeakingMode ? 0.12 : 0.08),
                    child: DecoratedBox(
                      key: ValueKey(
                        isSpeakingMode
                            ? 'agent-assistant-avatar-speaking'
                            : 'agent-assistant-avatar-thinking',
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor.withValues(
                            alpha: 0.42 + pulse * 0.18,
                          ),
                          width: isSpeakingMode ? 3 : 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(
                              alpha:
                                  (isSpeakingMode ? 0.18 : 0.12) + pulse * 0.12,
                            ),
                            blurRadius: (isSpeakingMode ? 12 : 9) + pulse * 6,
                            spreadRadius: (isSpeakingMode ? 1.4 : 0.8) + pulse,
                          ),
                        ],
                      ),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
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
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Image.asset(
                    MomCozyAssets.agentAvatar,
                    key: const ValueKey('agent-assistant-avatar-static'),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                  if (_videoReady &&
                      videoController != null &&
                      activeAvatarKey != null)
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: videoController.value.size.width,
                          height: videoController.value.size.height,
                          child: VideoPlayer(
                            videoController,
                            key: ValueKey(activeAvatarKey),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AgentArtifactPanel extends StatelessWidget {
  const AgentArtifactPanel({super.key, required this.cards, this.onAction});

  final List<AgentArtifactCardView> cards;
  final AgentArtifactActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
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
          _specializedArtifactCard(card: card, onAction: onAction) ??
              _AgentArtifactGenericCard(card: card, onAction: onAction),
          if (card != cards.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AgentArtifactGenericCard extends StatelessWidget {
  const _AgentArtifactGenericCard({required this.card, this.onAction});

  final AgentArtifactCardView card;
  final AgentArtifactActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      key: ValueKey('agent-artifact-card-${card.id}'),
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.74)),
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
            if (card.formFields.isNotEmpty) ...[
              const SizedBox(height: 10),
              _AgentArtifactFormView(card: card, onAction: onAction),
            ],
            if (card.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < card.actions.length; index++)
                    OutlinedButton.icon(
                      key: ValueKey('agent-artifact-action-${card.id}-$index'),
                      onPressed: () => onAction?.call(card.actions[index]),
                      icon: Icon(card.actions[index].icon),
                      label: Text(card.actions[index].label),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget? _specializedArtifactCard({
  required AgentArtifactCardView card,
  AgentArtifactActionHandler? onAction,
}) {
  final cardType = _artifactCardType(card);
  return switch (cardType) {
    'milk_analysis_card' || 'milk_plan_card' => _AgentMilkManagementCard(
      card: card,
      cardType: cardType!,
    ),
    'birth_journey_plan_card' => _AgentBirthJourneyPlanCard(card: card),
    'birth_plan_card' => _AgentBirthPlanCard(card: card),
    'hospital_bag_card' => _AgentHospitalBagCard(
      card: card,
      onAction: onAction,
    ),
    _ => null,
  };
}

class _AgentArtifactSpecializedShell extends StatelessWidget {
  const _AgentArtifactSpecializedShell({
    required this.card,
    required this.icon,
    required this.children,
    this.subtitle,
    this.statusLabel,
    this.accentColor = MomCozyColors.primary,
  });

  final AgentArtifactCardView card;
  final IconData icon;
  final List<Widget> children;
  final String? subtitle;
  final String? statusLabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      key: ValueKey('agent-artifact-${card.id}'),
      decoration: BoxDecoration(
        color: MomCozyColors.raised,
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border),
        boxShadow: MomCozyShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(MomCozyRadii.control),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        style: textTheme.titleSmall?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall?.copyWith(
                            height: 1.3,
                            color: MomCozyColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(width: 8),
                  _AgentArtifactPill(label: statusLabel!, color: accentColor),
                ],
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentMilkManagementCard extends StatelessWidget {
  const _AgentMilkManagementCard({required this.card, required this.cardType});

  final AgentArtifactCardView card;
  final String cardType;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final isPlan = cardType == 'milk_plan_card';
    final subtitle = _displayString(cardJson['subtitle']);
    final headline = _displayString(cardJson['headline']);
    final statusLabel = isPlan
        ? null
        : _displayStringField(cardJson, 'status_label', 'statusLabel');
    final sections = _objectList(cardJson['sections']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: isPlan ? Icons.route_rounded : Icons.water_drop_outlined,
      accentColor: isPlan ? MomCozyColors.care : MomCozyColors.violet,
      subtitle: subtitle,
      statusLabel: statusLabel,
      children: [
        if (headline != null)
          _AgentArtifactBodyText(headline, weight: FontWeight.w700),
        for (final section in sections) ...[
          if (headline != null || section != sections.first)
            const SizedBox(height: 10),
          _AgentMilkSection(section: section),
        ],
      ],
    );
  }
}

class _AgentMilkSection extends StatelessWidget {
  const _AgentMilkSection({required this.section});

  final Map<String, Object?> section;

  @override
  Widget build(BuildContext context) {
    final title = _displayString(section['title']);
    final metrics = _objectList(section['metrics']);
    final items = _displayStringList(section['items']);

    return _AgentArtifactSection(
      title: title,
      children: [
        if (metrics.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final metric in metrics)
                _AgentMetricTile(
                  label: _displayString(metric['label']) ?? '指标',
                  value: _displayString(metric['value']) ?? '-',
                  detail: _displayString(metric['detail']),
                ),
            ],
          ),
        if (items.isNotEmpty) ...[
          if (metrics.isNotEmpty) const SizedBox(height: 8),
          _AgentArtifactBulletList(items: items),
        ],
      ],
    );
  }
}

class _AgentBirthJourneyPlanCard extends StatelessWidget {
  const _AgentBirthJourneyPlanCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final owner = _mapField(cardJson, 'owner');
    final ownerChips = <({String label, String value})>[
      for (final entry in [
        (
          '孕期',
          _fieldValue(owner, 'current_week', 'currentWeek') ??
              _fieldValue(owner, 'due_date_or_week', 'dueDateOrWeek'),
        ),
        ('预产期预计', _fieldValue(owner, 'estimated_due_date', 'estimatedDueDate')),
        ('方式', _fieldValue(owner, 'birth_path', 'birthPath')),
        ('支持', _fieldValue(owner, 'support_person', 'supportPerson')),
        ('喂养', _fieldValue(owner, 'feeding_intention', 'feedingIntention')),
      ])
        if (_displayString(entry.$2) case final value?)
          (label: entry.$1, value: value),
    ].take(4).toList(growable: false);
    final todoPlan = _mapField(cardJson, 'todo_plan', 'todoPlan');
    final periods = _objectList(todoPlan['periods']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.calendar_month_outlined,
      accentColor: MomCozyColors.primary,
      children: [
        if (ownerChips.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in ownerChips)
                _AgentOwnerChip(label: chip.label, value: chip.value),
            ],
          ),
        if (periods.isNotEmpty) ...[
          if (ownerChips.isNotEmpty) const SizedBox(height: 10),
          _AgentArtifactSection(
            children: [
              for (final period in periods) ...[
                _AgentBirthJourneyPeriod(period: period),
                if (period != periods.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _AgentBirthJourneyPeriod extends StatelessWidget {
  const _AgentBirthJourneyPeriod({required this.period});

  final Map<String, Object?> period;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayString(period['title']) ?? '阶段';
    final subtitle = _displayString(period['subtitle']);
    final items = _objectList(period['items']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.labelLarge?.copyWith(
                          color: MomCozyColors.foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        _AgentArtifactBodyText(subtitle),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _AgentArtifactPill(
                  label: '${items.length} 个事项',
                  color: MomCozyColors.primary,
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < items.length; index++) ...[
                _AgentBirthJourneyItem(index: index + 1, item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentBirthJourneyItem extends StatelessWidget {
  const _AgentBirthJourneyItem({required this.index, required this.item});

  final int index;
  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = _displayString(item['title']) ?? '事项';
    final priorityLabel = _displayStringField(
      item,
      'priority_label',
      'priorityLabel',
    );
    final reason = _displayString(item['reason']);
    final steps = _displayStringList(item['steps']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: MomCozyColors.raised,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 24,
            child: Center(
              child: Text(
                '$index',
                style: textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (priorityLabel != null)
                    _AgentArtifactPill(
                      label: priorityLabel,
                      color: priorityLabel == '建议'
                          ? MomCozyColors.care
                          : MomCozyColors.primary,
                    ),
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (reason != null) ...[
                const SizedBox(height: 4),
                _AgentArtifactBodyText(reason),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 6),
                _AgentArtifactBulletList(items: steps),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentBirthPlanCard extends StatelessWidget {
  const _AgentBirthPlanCard({required this.card});

  final AgentArtifactCardView card;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final groups = <({String title, List<String> values, IconData icon})>[
      (
        title: '沟通方式',
        values: _displayStringList(cardJson['communication']),
        icon: Icons.headphones_outlined,
      ),
      (
        title: '生产时偏好',
        values: _displayStringListField(
          cardJson,
          'labor_preferences',
          'laborPreferences',
        ),
        icon: Icons.directions_walk_rounded,
      ),
      (
        title: '需要先沟通的操作',
        values: _displayStringListField(
          cardJson,
          'intervention_preferences',
          'interventionPreferences',
        ),
        icon: Icons.health_and_safety_outlined,
      ),
      (
        title: '疼痛缓解',
        values: _displayStringListField(cardJson, 'pain_relief', 'painRelief'),
        icon: Icons.favorite_border_rounded,
      ),
      (
        title: '宝宝出生后',
        values: _displayStringListField(
          cardJson,
          'baby_after_birth',
          'babyAfterBirth',
        ),
        icon: Icons.child_care_rounded,
      ),
      (
        title: '计划变化时',
        values: _displayStringListField(
          cardJson,
          'if_plans_change',
          'ifPlansChange',
        ),
        icon: Icons.medical_services_outlined,
      ),
      (
        title: '紧急情况',
        values: _displayStringListField(
          cardJson,
          'emergency_authorization',
          'emergencyAuthorization',
        ),
        icon: Icons.monitor_heart_outlined,
      ),
      (
        title: '提前问医院',
        values: _displayStringListField(
          cardJson,
          'questions_for_hospital',
          'questionsForHospital',
        ),
        icon: Icons.help_outline_rounded,
      ),
    ].where((group) => group.values.isNotEmpty).toList(growable: false);
    final medicalNotes = _displayStringListField(
      cardJson,
      'medical_notes',
      'medicalNotes',
    );
    final disclaimer = _displayString(cardJson['disclaimer']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.fact_check_outlined,
      accentColor: MomCozyColors.violet,
      children: [
        if (groups.isNotEmpty)
          _AgentArtifactSection(
            title: '沟通卡片内容',
            children: [
              for (final group in groups) ...[
                _AgentBirthPlanGroup(group: group),
                if (group != groups.last) const SizedBox(height: 8),
              ],
            ],
          ),
        if (medicalNotes.isNotEmpty) ...[
          if (groups.isNotEmpty) const SizedBox(height: 10),
          _AgentArtifactSection(
            title: '医疗或安全信息',
            children: [_AgentArtifactBulletList(items: medicalNotes)],
          ),
        ],
        if (disclaimer != null) ...[
          const SizedBox(height: 10),
          _AgentArtifactBodyText(disclaimer),
        ],
      ],
    );
  }
}

class _AgentBirthPlanGroup extends StatelessWidget {
  const _AgentBirthPlanGroup({required this.group});

  final ({String title, List<String> values, IconData icon}) group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(group.icon, size: 17, color: MomCozyColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.title,
                    style: textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _AgentArtifactBulletList(items: group.values),
          ],
        ),
      ),
    );
  }
}

class _AgentHospitalBagCard extends StatelessWidget {
  const _AgentHospitalBagCard({required this.card, this.onAction});

  final AgentArtifactCardView card;
  final AgentArtifactActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final cardJson = _effectiveCardJson(card);
    final packingGroups = _objectListField(
      cardJson,
      'packing_groups',
      'packingGroups',
    );
    final disclaimer = _displayString(cardJson['disclaimer']);

    return _AgentArtifactSpecializedShell(
      card: card,
      icon: Icons.shopping_bag_outlined,
      accentColor: MomCozyColors.care,
      subtitle: '住院母婴必备用品 · 32～34周准备 · 36周完成',
      children: [
        if (packingGroups.isNotEmpty)
          _AgentArtifactSection(
            title: '物品清单',
            children: [
              for (final group in packingGroups) ...[
                _AgentPackingGroup(group: group),
                if (group != packingGroups.last) const SizedBox(height: 8),
              ],
            ],
          ),
        if (disclaimer != null) ...[
          const SizedBox(height: 10),
          _AgentArtifactBodyText(disclaimer),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onAction == null
                ? null
                : () => onAction?.call(_hospitalBagCartAction()),
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: const Text('打开购物车'),
          ),
        ),
      ],
    );
  }
}

class _AgentPackingGroup extends StatelessWidget {
  const _AgentPackingGroup({required this.group});

  final Map<String, Object?> group;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title =
        _displayString(group['title']) ??
        _displayStringField(group, 'group_id', 'groupId') ??
        '待产包';
    final items = _objectList(group['items']);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.careSoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.care.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.labelLarge?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _AgentArtifactPill(
                  label: '${items.length}项',
                  color: MomCozyColors.care,
                ),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var index = 0; index < items.length; index++) ...[
                _AgentPackingItem(item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AgentPackingItem extends StatelessWidget {
  const _AgentPackingItem({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label =
        _displayString(item['label']) ??
        _displayString(item['name']) ??
        _displayString(item['title']) ??
        '物品';
    final quantity =
        _displayString(item['quantity']) ??
        _displayString(item['amount']) ??
        _displayString(item['count']);
    final priority = _displayString(item['priority']);
    final priorityLabel = _packingPriorityLabel(priority);
    final description =
        _displayString(item['reason']) ??
        _displayString(item['description']) ??
        _displayString(item['note']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: MomCozyColors.raised,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox.square(
            dimension: 28,
            child: Icon(
              Icons.checkroom_outlined,
              size: 16,
              color: MomCozyColors.care,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      color: MomCozyColors.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (quantity != null)
                    Text(
                      quantity,
                      style: textTheme.labelMedium?.copyWith(
                        color: MomCozyColors.foreground,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  if (priorityLabel != null)
                    _AgentArtifactPill(
                      label: priorityLabel,
                      color: MomCozyColors.care,
                    ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                _AgentArtifactBodyText(description),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AgentArtifactSection extends StatelessWidget {
  const _AgentArtifactSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: textTheme.labelLarge?.copyWith(
              color: MomCozyColors.foreground,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...children,
      ],
    );
  }
}

class _AgentMetricTile extends StatelessWidget {
  const _AgentMetricTile({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: MomCozyColors.muted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(MomCozyRadii.control),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: MomCozyColors.mutedForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: textTheme.labelSmall?.copyWith(
                    color: MomCozyColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentOwnerChip extends StatelessWidget {
  const _AgentOwnerChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.roseSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: MomCozyColors.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: textTheme.labelMedium?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentArtifactPill extends StatelessWidget {
  const _AgentArtifactPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MomCozyRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AgentArtifactBodyText extends StatelessWidget {
  const _AgentArtifactBodyText(this.text, {this.weight});

  final String text;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        height: 1.35,
        color: MomCozyColors.mutedForeground,
        fontWeight: weight,
      ),
    );
  }
}

class _AgentArtifactBulletList extends StatelessWidget {
  const _AgentArtifactBulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '•',
                style: textTheme.bodySmall?.copyWith(
                  color: MomCozyColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: _AgentArtifactBodyText(item)),
            ],
          ),
          if (item != items.last) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class AgentArtifactCardView {
  const AgentArtifactCardView({
    required this.id,
    required this.title,
    this.artifactType,
    this.cardType,
    this.cardJson = const <String, Object?>{},
    this.rawCard = const <String, Object?>{},
    this.content,
    this.statusLabel,
    this.rows = const <String>[],
    this.formId,
    this.formSubmitLabel,
    this.formFields = const <AgentArtifactFormFieldView>[],
    this.actions = const <AgentArtifactActionView>[],
  });

  final String id;
  final String title;
  final String? artifactType;
  final String? cardType;
  final Map<String, Object?> cardJson;
  final Map<String, Object?> rawCard;
  final String? content;
  final String? statusLabel;
  final List<String> rows;
  final String? formId;
  final String? formSubmitLabel;
  final List<AgentArtifactFormFieldView> formFields;
  final List<AgentArtifactActionView> actions;
}

class AgentArtifactFormFieldView {
  const AgentArtifactFormFieldView({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const <String>[],
    this.placeholder,
    this.defaultValue,
    this.allowOtherInput = false,
    this.otherPlaceholder,
    this.helpText,
  });

  final String id;
  final String label;
  final String type;
  final bool required;
  final List<String> options;
  final String? placeholder;
  final Object? defaultValue;
  final bool allowOtherInput;
  final String? otherPlaceholder;
  final String? helpText;

  String get groupTitle => _splitFormFieldLabel(label).groupTitle;

  String get fieldLabel => _splitFormFieldLabel(label).fieldLabel;

  bool get isMultiSelect {
    return type == 'multi_select' ||
        type == 'checkboxes' ||
        type == 'checkbox_group';
  }

  bool get isChoice => isMultiSelect || type == 'select' || type == 'radio';
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

class _AgentArtifactFormView extends StatefulWidget {
  const _AgentArtifactFormView({required this.card, this.onAction});

  final AgentArtifactCardView card;
  final AgentArtifactActionHandler? onAction;

  @override
  State<_AgentArtifactFormView> createState() => _AgentArtifactFormViewState();
}

class _AgentArtifactFormViewState extends State<_AgentArtifactFormView> {
  late Map<String, Object?> _values;
  late Map<String, String> _otherValues;
  String? _submitError;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _values = _initialValues(widget.card.formFields);
    _otherValues = const <String, String>{};
  }

  @override
  void didUpdateWidget(covariant _AgentArtifactFormView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.formFields.length != widget.card.formFields.length) {
      _values = _initialValues(widget.card.formFields);
      _otherValues = const <String, String>{};
      _submitError = null;
      _submitted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final groups = _formFieldGroups(widget.card);

    return Column(
      key: ValueKey('agent-artifact-form-${widget.card.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          if (group.title.isNotEmpty)
            _AgentArtifactFormGroup(
              title: group.title,
              children: [
                for (final field in group.fields) ...[
                  _buildField(context, field),
                  if (field != group.fields.last) const SizedBox(height: 10),
                ],
              ],
            )
          else
            for (final field in group.fields) ...[
              _buildField(context, field),
              if (field != group.fields.last) const SizedBox(height: 10),
            ],
          if (group != groups.last) const SizedBox(height: 10),
        ],
        if (_submitError != null) ...[
          if (groups.isNotEmpty) const SizedBox(height: 10),
          Text(
            _submitError!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: ValueKey('agent-artifact-form-submit-${widget.card.id}'),
            onPressed: widget.onAction == null || _submitted ? null : _submit,
            icon: Icon(
              _submitted
                  ? Icons.check_circle_outline_rounded
                  : Icons.check_rounded,
              size: 18,
            ),
            label: Text(
              _submitted ? '已提交' : widget.card.formSubmitLabel ?? '提交',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _submitted
                  ? MomCozyColors.careSoft
                  : colorScheme.primary,
              foregroundColor: _submitted
                  ? MomCozyColors.care
                  : colorScheme.onPrimary,
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, AgentArtifactFormFieldView field) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      key: ValueKey('agent-artifact-form-field-${widget.card.id}-${field.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                field.fieldLabel,
                style: textTheme.labelMedium?.copyWith(
                  color: MomCozyColors.foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (field.required)
              Text(
                '必填',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (field.isChoice && field.options.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in field.options)
                    ChoiceChip(
                      key: ValueKey(
                        'agent-artifact-form-option-${widget.card.id}-${field.id}-$option',
                      ),
                      selected: _isOptionSelected(field, option),
                      label: Text(option),
                      onSelected: _submitted
                          ? null
                          : (_) => _toggleOption(field, option),
                    ),
                ],
              ),
              if (field.allowOtherInput && _isOtherSelected(field)) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey(
                    'agent-artifact-form-other-${widget.card.id}-${field.id}',
                  ),
                  initialValue: _otherValues[field.id] ?? '',
                  readOnly: _submitted,
                  decoration: InputDecoration(
                    hintText: field.otherPlaceholder ?? '请补充说明',
                    isDense: true,
                    filled: true,
                    fillColor: MomCozyColors.card.withValues(alpha: 0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MomCozyRadii.control),
                    ),
                  ),
                  onChanged: (value) {
                    _setOtherFieldValue(field.id, value.trim());
                  },
                ),
              ],
            ],
          )
        else
          TextFormField(
            initialValue: _textValue(field),
            readOnly: _submitted,
            minLines: field.type == 'textarea' ? 3 : 1,
            maxLines: field.type == 'textarea' ? 5 : 1,
            decoration: InputDecoration(
              hintText: field.placeholder ?? '请填写',
              isDense: true,
              filled: true,
              fillColor: MomCozyColors.card.withValues(alpha: 0.72),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MomCozyRadii.control),
              ),
            ),
            onChanged: (value) {
              _setFieldValue(field.id, value.trim());
            },
          ),
        if (field.helpText != null) ...[
          const SizedBox(height: 6),
          Text(
            field.helpText!,
            style: textTheme.labelSmall?.copyWith(
              color: MomCozyColors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }

  bool _isOptionSelected(AgentArtifactFormFieldView field, String option) {
    final value = _values[field.id];
    if (field.isMultiSelect) {
      return value is List && value.contains(option);
    }
    return value == option;
  }

  String _textValue(AgentArtifactFormFieldView field) {
    final value = _values[field.id];
    return value == null ? '' : value.toString();
  }

  bool _isOtherSelected(AgentArtifactFormFieldView field) {
    final value = _values[field.id];
    if (field.isMultiSelect) {
      return value is List && value.whereType<String>().any(_isOtherFormOption);
    }
    return value is String && _isOtherFormOption(value);
  }

  void _toggleOption(AgentArtifactFormFieldView field, String option) {
    setState(() {
      if (field.isMultiSelect) {
        final current = List<String>.from(
          (_values[field.id] as List?)?.whereType<String>() ?? const <String>[],
        );
        current.contains(option) ? current.remove(option) : current.add(option);
        _values = {..._values, field.id: current};
      } else {
        _values = {..._values, field.id: option};
      }
      _submitError = null;
    });
  }

  void _submit() {
    for (final field in widget.card.formFields) {
      if (!field.allowOtherInput || !_isOtherSelected(field)) continue;
      final otherValue = _otherValues[field.id]?.trim() ?? '';
      if (otherValue.isEmpty) {
        setState(() {
          _submitError = '请填写：${field.fieldLabel}的其它内容';
        });
        return;
      }
    }

    final values = _submittedValues();
    final missingFields = widget.card.formFields
        .where((field) => field.required && !_hasFieldValue(values[field.id]))
        .map((field) => field.fieldLabel)
        .toList();
    if (missingFields.isNotEmpty) {
      setState(() {
        _submitError = '请补充：${missingFields.join('、')}';
      });
      return;
    }

    widget.onAction?.call(
      AgentArtifactActionView(
        label: widget.card.formSubmitLabel ?? '提交',
        icon: Icons.check_rounded,
        kind: 'form.submit',
        value: jsonEncode(values),
        routeExtra: {
          'artifactId': widget.card.id,
          if (widget.card.formId != null) 'formId': widget.card.formId,
          'values': values,
        },
      ),
    );
    setState(() {
      _submitted = true;
      _submitError = null;
    });
  }

  void _setFieldValue(String id, Object? value) {
    if (_submitted) return;
    setState(() {
      _values = {..._values, id: value};
      _submitError = null;
    });
  }

  void _setOtherFieldValue(String id, String value) {
    if (_submitted) return;
    setState(() {
      _otherValues = {..._otherValues, id: value};
      _submitError = null;
    });
  }

  bool _hasFieldValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  Map<String, Object?> _initialValues(List<AgentArtifactFormFieldView> fields) {
    return {
      for (final field in fields)
        if (field.defaultValue != null)
          field.id: field.isMultiSelect
              ? _defaultMultiSelectValues(field.defaultValue)
              : field.defaultValue,
    };
  }

  Map<String, Object?> _submittedValues() {
    final values = <String, Object?>{};
    for (final field in widget.card.formFields) {
      final rawValue = _values[field.id];
      Object? value = rawValue;
      if (field.isMultiSelect && rawValue is List) {
        final otherValue = _otherValues[field.id]?.trim();
        value = rawValue
            .whereType<String>()
            .map((item) {
              if (field.allowOtherInput &&
                  otherValue != null &&
                  otherValue.isNotEmpty &&
                  _isOtherFormOption(item)) {
                return '其它：$otherValue';
              }
              return item.trim();
            })
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      } else if (rawValue is String) {
        final otherValue = _otherValues[field.id]?.trim();
        value =
            field.allowOtherInput &&
                otherValue != null &&
                otherValue.isNotEmpty &&
                _isOtherFormOption(rawValue)
            ? '其它：$otherValue'
            : rawValue.trim();
      }
      if (_hasFieldValue(value)) values[field.id] = value;
    }
    return values;
  }
}

class _AgentArtifactFormFieldGroup {
  const _AgentArtifactFormFieldGroup({
    required this.title,
    required this.fields,
  });

  final String title;
  final List<AgentArtifactFormFieldView> fields;
}

class _AgentArtifactFormGroup extends StatelessWidget {
  const _AgentArtifactFormGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: MomCozyColors.raised.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(MomCozyRadii.control),
        border: Border.all(color: MomCozyColors.border.withValues(alpha: 0.72)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.labelLarge?.copyWith(
                color: MomCozyColors.foreground,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

List<_AgentArtifactFormFieldGroup> _formFieldGroups(
  AgentArtifactCardView card,
) {
  if (card.formFields.isEmpty) return const <_AgentArtifactFormFieldGroup>[];
  final forceBasicInfoGroup = card.formId == 'birth_journey_basic_info_intake';
  final orderedTitles = <({String key, String title})>[];
  final fieldsByTitle = <String, List<AgentArtifactFormFieldView>>{};

  for (final field in card.formFields) {
    final groupTitle = forceBasicInfoGroup ? '基本信息' : field.groupTitle;
    final key = groupTitle.isEmpty ? '__ungrouped' : groupTitle;
    if (!fieldsByTitle.containsKey(key)) {
      orderedTitles.add((key: key, title: groupTitle));
      fieldsByTitle[key] = <AgentArtifactFormFieldView>[];
    }
    fieldsByTitle[key]!.add(field);
  }

  return [
    for (final group in orderedTitles)
      _AgentArtifactFormFieldGroup(
        title: group.title,
        fields: List<AgentArtifactFormFieldView>.unmodifiable(
          fieldsByTitle[group.key] ?? const <AgentArtifactFormFieldView>[],
        ),
      ),
  ];
}

List<String> _defaultMultiSelectValues(Object? value) {
  if (value is List) return _displayStringList(value);
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final displayValue = _displayString(value);
  return displayValue == null ? const <String>[] : <String>[displayValue];
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
    this.voicePlaybackFailed = false,
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
  final bool voicePlaybackFailed;
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
    final imageCount = widget.imageCount;
    final canSend =
        widget.canSend && (controller.text.trim().isNotEmpty || imageCount > 0);
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
      _ => '语音输入',
    };
  }

  String? get _voiceStatusLabel {
    return switch (widget.voicePhase) {
      AgentVoicePhase.listening => '正在听',
      AgentVoicePhase.transcribing => '正在整理语音',
      AgentVoicePhase.playing => null,
      AgentVoicePhase.cancelled => null,
      _ => null,
    };
  }
}

Iterable<AgentStreamEvent> _artifactEventsForState(AgentStreamRunState state) {
  return state.artifactEvents.isNotEmpty
      ? state.artifactEvents.values
      : state.events;
}

Iterable<AgentStreamEvent> _actionEventsForState(AgentStreamRunState state) {
  return state.actionEvents.isNotEmpty
      ? state.actionEvents.values
      : state.events;
}

List<AgentArtifactCardView> _artifactCardsFromEvents(
  Iterable<AgentStreamEvent> events,
) {
  final cards = <String, AgentArtifactCardView>{};
  for (final event in events) {
    for (final card in _artifactCardsFromEvent(event)) {
      cards[card.id] = card;
    }
  }
  return List<AgentArtifactCardView>.unmodifiable(cards.values);
}

List<AgentArtifactCardView> _artifactCardsFromEvent(AgentStreamEvent event) {
  final payload = event.payload;
  final rawRichText = _mapField(event.raw, 'rich_text', 'richText');
  final payloadRichText = _mapField(payload, 'rich_text', 'richText');
  final richText = rawRichText.isNotEmpty ? rawRichText : payloadRichText;

  if (event.type != 'artifact.created' && event.type != 'artifact.updated') {
    return const <AgentArtifactCardView>[];
  }

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
  final artifactId =
      stringField(event.raw, 'artifact_id') ??
      stringField(payload, 'artifact_id') ??
      stringField(event.raw, 'artifactId') ??
      stringField(artifact, 'id') ??
      event.mergeKey;

  final envelopeCard = _artifactCardFromEnvelope(
    event: event,
    payload: payload,
    richText: richText,
    artifact: artifact,
    artifactPayload: artifactPayload,
    cardEnvelope: cardEnvelope,
    form: form,
    cartUpdate: cartUpdate,
    assistantFollowup: assistantFollowup,
    artifactId: artifactId,
    artifactType: _firstNonEmpty([
      _stringField(payload, 'artifact_type', 'artifactType'),
      _stringField(artifact, 'artifact_type', 'artifactType'),
    ]),
  );

  return List<AgentArtifactCardView>.unmodifiable([?envelopeCard]);
}

AgentArtifactCardView? _artifactCardFromEnvelope({
  required AgentStreamEvent event,
  required Map<String, Object?> payload,
  required Map<String, Object?> richText,
  required Map<String, Object?> artifact,
  required Map<String, Object?> artifactPayload,
  required Map<String, Object?> cardEnvelope,
  required Map<String, Object?> form,
  required Map<String, Object?> cartUpdate,
  required Map<String, Object?> assistantFollowup,
  required String artifactId,
  String? artifactType,
}) {
  final rawCardJson = _firstMap([
    _mapField(artifact, 'card_json', 'cardJson'),
    _mapField(artifactPayload, 'card_json', 'cardJson'),
    _mapField(payload, 'card_json', 'cardJson'),
    _mapField(cardEnvelope, 'card_json', 'cardJson'),
  ]);
  final cardJson = rawCardJson.isNotEmpty ? rawCardJson : payload;
  final explicitTitle = _firstNonEmpty([
    _stringField(richText, 'title'),
    _stringField(form, 'title'),
    _stringField(cardJson, 'title'),
    _stringField(cartUpdate, 'message'),
    _stringField(payload, 'title'),
  ]);
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
  final formFields = _formFields(form);
  final rows = <String>[
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

  if (explicitTitle == null &&
      formFields.isEmpty &&
      (content == null || content.trim().isEmpty) &&
      rows.isEmpty &&
      actions.isEmpty) {
    return null;
  }

  return AgentArtifactCardView(
    id: artifactId,
    title: explicitTitle ?? _artifactSubject(event),
    artifactType: artifactType,
    cardType: _stringField(cardEnvelope, 'card_type', 'cardType'),
    cardJson: cardJson,
    rawCard: cardEnvelope,
    content: content,
    statusLabel: status,
    rows: rows,
    formId: _stringField(form, 'id'),
    formSubmitLabel: _stringField(form, 'submit_label', 'submitLabel'),
    formFields: formFields,
    actions: actions,
  );
}

Map<String, Object?> _firstMap(List<Map<String, Object?>> values) {
  for (final value in values) {
    if (value.isNotEmpty) return value;
  }
  return const {};
}

String? _artifactCardType(AgentArtifactCardView card) {
  final explicitCardType = _firstNonEmpty([
    card.cardType,
    _stringField(card.rawCard, 'card_type', 'cardType'),
    _stringField(card.cardJson, 'card_type', 'cardType'),
  ]);
  if (explicitCardType != null) return explicitCardType;

  final artifactType = card.artifactType;
  final cardJson = _effectiveCardJson(card);
  return switch (artifactType) {
    'milk_analysis_card' || 'milk_plan_card'
        when cardJson.containsKey('sections') ||
            cardJson.containsKey('headline') =>
      artifactType,
    'birth_journey_plan_card'
        when cardJson.containsKey('todo_plan') ||
            cardJson.containsKey('todoPlan') ||
            cardJson.containsKey('owner') =>
      artifactType,
    'birth_plan_card'
        when cardJson.containsKey('communication') ||
            cardJson.containsKey('pain_relief') ||
            cardJson.containsKey('painRelief') ||
            cardJson.containsKey('medical_notes') ||
            cardJson.containsKey('medicalNotes') =>
      artifactType,
    'hospital_bag_card'
        when cardJson.containsKey('packing_groups') ||
            cardJson.containsKey('packingGroups') =>
      artifactType,
    _ => null,
  };
}

Map<String, Object?> _effectiveCardJson(AgentArtifactCardView card) {
  if (card.cardJson.isNotEmpty) return card.cardJson;
  final rawCardJson = _mapField(card.rawCard, 'card_json', 'cardJson');
  if (rawCardJson.isNotEmpty) return rawCardJson;
  return card.rawCard;
}

Object? _fieldValue(Map<String, Object?> map, String key, [String? alias]) {
  return map[key] ?? (alias == null ? null : map[alias]);
}

String? _displayStringField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  return _displayString(_fieldValue(map, key, alias));
}

List<String> _displayStringListField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  return _displayStringList(_fieldValue(map, key, alias));
}

List<Map<String, Object?>> _objectListField(
  Map<String, Object?> map,
  String key, [
  String? alias,
]) {
  return _objectList(_fieldValue(map, key, alias));
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

String? _displayString(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    final values = _displayStringList(value);
    return values.isEmpty ? null : values.join('、');
  }
  return null;
}

List<String> _displayStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map(_displayString).whereType<String>().toList(growable: false);
}

String? _packingPriorityLabel(String? priority) {
  return switch (priority) {
    'must' || 'required' => '必备',
    'recommended' || 'recommend' => '推荐',
    'optional' => '可选',
    final value? when value.trim().isNotEmpty => value,
    _ => null,
  };
}

AgentArtifactActionView _hospitalBagCartAction() {
  return const AgentArtifactActionView(
    label: '打开待产包购物车',
    icon: Icons.shopping_cart_outlined,
    kind: 'artifact',
    value: '/hospital-bag-cart',
    routePath: '/hospital-bag-cart',
  );
}

({String groupTitle, String fieldLabel}) _splitFormFieldLabel(String label) {
  final normalized = label.trim();
  final separatorIndex = normalized.indexOf('｜');
  if (separatorIndex <= 0) {
    return (groupTitle: '', fieldLabel: normalized);
  }
  final groupTitle = normalized.substring(0, separatorIndex).trim();
  final fieldLabel = normalized.substring(separatorIndex + 1).trim();
  if (groupTitle.isEmpty || fieldLabel.isEmpty) {
    return (groupTitle: '', fieldLabel: normalized);
  }
  return (groupTitle: groupTitle, fieldLabel: fieldLabel);
}

bool _isOtherFormOption(String option) {
  final normalized = option.trim();
  return normalized == '其它' || normalized == '其他';
}

List<AgentArtifactFormFieldView> _formFields(Map<String, Object?> form) {
  if (form.isEmpty) return const <AgentArtifactFormFieldView>[];
  final fields = form['fields'];
  if (fields is! List) return const <AgentArtifactFormFieldView>[];
  final defaultValues = _mapField(form, 'default_values', 'defaultValues');
  final views = <AgentArtifactFormFieldView>[];
  for (final rawField in fields.take(24)) {
    if (rawField is! Map) continue;
    final field = Map<String, Object?>.from(rawField);
    final id = _stringField(field, 'id')?.trim();
    final label = _stringField(field, 'label')?.trim();
    if (id == null || id.isEmpty || label == null || label.isEmpty) continue;
    views.add(
      AgentArtifactFormFieldView(
        id: id,
        label: label,
        type: _stringField(field, 'type') ?? 'text',
        required: field['required'] == true,
        options: _stringList(field['options']),
        placeholder: _stringField(field, 'placeholder'),
        defaultValue:
            field['default_value'] ??
            field['defaultValue'] ??
            defaultValues[id],
        allowOtherInput:
            field['allow_other_input'] == true ||
            field['allowOtherInput'] == true,
        otherPlaceholder: _stringField(
          field,
          'other_placeholder',
          'otherPlaceholder',
        ),
        helpText: _stringField(field, 'help_text', 'helpText'),
      ),
    );
  }
  return List<AgentArtifactFormFieldView>.unmodifiable(views);
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
  Iterable<AgentStreamEvent> events,
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
      .where((action) => _stringField(action, 'kind') != 'ag_ui_artifact')
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

class _AgentLoopDecorState {
  const _AgentLoopDecorState({this.statusTitle, this.thinkingTitle});

  final String? statusTitle;
  final String? thinkingTitle;
}

_AgentLoopDecorState _agentLoopDecorStateFromEvents(
  List<AgentStreamEvent> events,
) {
  return _AgentLoopDecorState(
    statusTitle: _activeAgentStatusTitle(events),
    thinkingTitle: _activeAgentThinkingTitle(events),
  );
}

String? _activeAgentStatusTitle(List<AgentStreamEvent> events) {
  for (final event in events.reversed) {
    if (_eventStopsAgentLoopDecor(event)) return null;

    final semanticTitle = _semanticStatusTitle(event);
    if (semanticTitle != null) return semanticTitle;

    switch (event.type) {
      case 'run.queued':
      case 'run.started':
        return '我已经收到你的消息啦～';
      case 'run.progress':
        if (_isThinkingProgressEvent(event)) continue;
        final title = _visibleAgentStatusTitle(
          _firstNonEmpty([
            _stringField(event.payload, 'label'),
            _stringField(event.payload, 'message'),
            _runProgressStatusTitle(event),
          ]),
        );
        if (title != null) return title;
        continue;
      default:
        continue;
    }
  }
  return '我已经收到你的消息啦～';
}

String? _activeAgentThinkingTitle(List<AgentStreamEvent> events) {
  for (final event in events.reversed) {
    final semanticThinkingTitle = _semanticThinkingTitle(event);
    if (semanticThinkingTitle != null) return semanticThinkingTitle;
    if (_semanticClearsAgentThinking(event)) return null;

    if (event.type == 'run.progress') {
      final phase = _stringField(event.payload, 'phase')?.trim();
      if (phase == 'model_reasoning') {
        return _visibleAgentStatusTitle(
              _firstNonEmpty([
                _stringField(event.payload, 'label'),
                _stringField(event.payload, 'message'),
              ]),
            ) ??
            '我想一下';
      }
      if (phase == 'model_reasoning_after_tool') {
        return _visibleAgentStatusTitle(
              _firstNonEmpty([
                _stringField(event.payload, 'label'),
                _stringField(event.payload, 'message'),
              ]),
            ) ??
            '我接着处理下一步';
      }
      if (_runProgressClearsAgentThinking(event, phase)) return null;
    }

    if (_eventStopsAgentLoopDecor(event)) return null;
  }
  return null;
}

bool _eventStopsAgentLoopDecor(AgentStreamEvent event) {
  return event.type == 'message.delta' ||
      event.type == 'message.completed' ||
      event.type == 'run.completed' ||
      event.type == 'run.failed' ||
      event.type == 'run.cancelled';
}

bool _isThinkingProgressEvent(AgentStreamEvent event) {
  if (event.semanticSurface == 'thinking_note') return true;
  if (event.type != 'run.progress') return false;
  final phase = _stringField(event.payload, 'phase')?.trim();
  return phase == 'model_reasoning' || phase == 'model_reasoning_after_tool';
}

bool _runProgressClearsAgentThinking(AgentStreamEvent event, String? phase) {
  if (phase != null && phase.isNotEmpty) {
    return phase != 'model_reasoning' && phase != 'model_reasoning_after_tool';
  }
  final statusCandidates = [
    _semanticStatusTitle(event),
    _stringField(event.payload, 'label'),
    _stringField(event.payload, 'message'),
  ];
  return statusCandidates.any(
    (candidate) => _visibleAgentStatusTitle(candidate) != null,
  );
}

bool _semanticClearsAgentThinking(AgentStreamEvent event) {
  final semantic = event.semantic;
  if (semantic.isEmpty) return false;
  final surface = _stringField(semantic, 'surface')?.trim();
  final visibility = _stringField(semantic, 'visibility')?.trim();
  if (surface == 'thinking_note') return false;
  if (surface == 'status_bar' || visibility == 'status') {
    return _semanticDisplayTitle(semantic) != null;
  }
  final lifecycle = _stringField(semantic, 'lifecycle')?.trim();
  return lifecycle == 'completed' || lifecycle == 'failed';
}

String? _semanticStatusTitle(AgentStreamEvent event) {
  final semantic = event.semantic;
  if (semantic.isEmpty) return null;
  final surface = _stringField(semantic, 'surface')?.trim();
  final visibility = _stringField(semantic, 'visibility')?.trim();
  if (surface == 'thinking_note' || surface == 'hidden') return null;
  if (surface == 'status_bar' || visibility == 'status') {
    return _semanticDisplayTitle(semantic);
  }
  return null;
}

String? _semanticThinkingTitle(AgentStreamEvent event) {
  final semantic = event.semantic;
  if (semantic.isEmpty) return null;
  final surface = _stringField(semantic, 'surface')?.trim();
  if (surface != 'thinking_note') return null;
  return _semanticDisplayTitle(semantic);
}

String? _semanticDisplayTitle(Map<String, Object?> semantic) {
  return _visibleAgentStatusTitle(
    _firstNonEmpty([
      _stringField(semantic, 'label'),
      _stringField(semantic, 'title'),
    ]),
  );
}

String? _runProgressStatusTitle(AgentStreamEvent event) {
  final phase = _stringField(event.payload, 'phase')?.trim();
  return switch (phase) {
    'context_loading' => '我已经收到你的消息啦～',
    'context_ready' => '我先理解一下你的需求～',
    'response_finalizing' => '我在组织回复～',
    _ => null,
  };
}

String? _visibleAgentStatusTitle(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  const hidden = {
    '开始处理请求。',
    '正在处理请求。',
    '正在处理请求',
    'Agent loop started.',
    'Requesting model response.',
    'Requesting model response with tool outputs.',
  };
  if (hidden.contains(normalized)) return null;
  return switch (normalized) {
    'CozyMate 正在进入对话' => '我已经收到你的消息啦～',
    '正在整理对话上下文' => '我已经收到你的消息啦～',
    '已整理好相关信息' => '我先理解一下你的需求～',
    'CozyMate 正在思考怎么帮你' => '我想一下',
    '正在整理回复' => '我在组织回复～',
    _ => normalized,
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
