import 'package:momcozy_flutter_app/shared/widgets/mom_settings_widgets.dart';
import 'package:momcozy_flutter_app/shared/design_system/mom_home_tokens.dart';
import 'dart:async';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_work_status_projection.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_file_previews.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:video_player/video_player.dart';
import 'presentation/assistant_display_text.dart';
import 'presentation/agent_text_reveal.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);
typedef AgentHubApplicationEventHandler = void Function(AgentStreamEvent event);

const _agentActiveRunPersistentWriteInterval = Duration(milliseconds: 750);
const _completedReplyRunSettlementTimeout = Duration(seconds: 2);
const _completedReplyCancelTimeout = Duration(seconds: 2);
const _agentRunAttachmentLimit = 20;
const _unsupportedActionMessage =
    'This action is not supported in this version. You can keep asking questions.';

AgentStreamRunState _phaseOneRunState(AgentStreamRunState state) {
  if (state.phase != AgentStreamRunPhase.waitingForConfirmation) return state;
  // Retired actions must never execute or leave the composer locked.
  return state.copyWith(
    phase: AgentStreamRunPhase.error,
    errorMessage: _unsupportedActionMessage,
  );
}

String _agentAssistantTextForState(
  AgentStreamRunState state, {
  required String greeting,
}) {
  final text = state.textContent.trim();
  if (text.isNotEmpty) return text;

  return switch (state.phase) {
    AgentStreamRunPhase.idle => greeting,
    AgentStreamRunPhase.streaming => 'I have your message.',
    AgentStreamRunPhase.cancelRequested => 'Stopping this response…',
    AgentStreamRunPhase.cancelled =>
      state.cancelAcknowledged
          ? 'Response stopped.'
          : 'Stopped on this device. Server cancellation has not been confirmed.',
    AgentStreamRunPhase.waitingForConfirmation => _unsupportedActionMessage,
    AgentStreamRunPhase.finished =>
      'The request finished, but there was no response to show.',
    AgentStreamRunPhase.error ||
    AgentStreamRunPhase.disconnected => 'No response this time.',
  };
}

String _newAgentRunIdempotencyKey() {
  return 'agent-run-${DateTime.now().microsecondsSinceEpoch}';
}

final _agentHubInteractionStates = Expando<_AgentHubInteractionState>(
  'momcozy-agent-hub-interaction-state',
);

class _AgentHubInteractionState {
  AgentStreamRunState runState = const AgentStreamRunState();
  List<AgentHubHistoryMessage>? historyMessages;
  String composerText = '';
  List<AgentStreamImageInput> attachedImages = const <AgentStreamImageInput>[];
  List<AgentStreamFileInput> attachedFiles = const <AgentStreamFileInput>[];
  List<String> pendingAttachmentCleanupIds = const <String>[];

  AgentStreamRequest? activeRequest;
  int? nextBeforeSequence;
  final Map<String, AgentHubInteractionSnapshot> threads = {};
}

class AgentHubAutoRunRequest {
  const AgentHubAutoRunRequest({
    required this.requestMessage,
    required this.idempotencyKey,
    this.metadata = const <String, Object?>{},
  });

  final String requestMessage;
  final String idempotencyKey;
  final Map<String, Object?> metadata;
}

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({
    super.key,
    this.stateCacheKey,
    this.isVisible = true,
    this.now,
    this.state = const AgentStreamRunState(),
    this.historyMessages = const <AgentHubHistoryMessage>[],
    this.runner,
    this.cancelClient,
    this.conversationRepository,
    this.initialConversationId,
    this.interactionStateStore,
    this.greetingProfileLoader,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.pickDocument,
    this.mediaRepository,
    this.loadImageThumbnail,
    this.loadImageContent,
    this.onApplicationEvent,
    this.initialComposerText,
    this.initialAutoSend = false,
    this.initialAutoRunRequest,
    this.externalConversationRefreshKey,
    this.externalConversationRefreshInterval = const Duration(
      milliseconds: 750,
    ),
    this.externalConversationRefreshAttempts = 20,
    this.externalConversationRefreshUntilFound = false,
  });

  final Object? stateCacheKey;
  final bool isVisible;
  final DateTime Function()? now;
  final AgentStreamRunState state;
  final List<AgentHubHistoryMessage> historyMessages;
  final AgentStreamRunner? runner;
  final AgentStreamCancelClient? cancelClient;

  final AgentConversationRepository? conversationRepository;
  final String? initialConversationId;
  final AgentHubInteractionStateStore? interactionStateStore;
  final AgentHubGreetingProfileLoader? greetingProfileLoader;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubDocumentPicker? pickDocument;
  final MediaRepository? mediaRepository;
  final AgentImageContentLoader? loadImageThumbnail;
  final AgentImageContentLoader? loadImageContent;

  final AgentHubApplicationEventHandler? onApplicationEvent;
  final String? initialComposerText;
  final bool initialAutoSend;
  final AgentHubAutoRunRequest? initialAutoRunRequest;
  final String? externalConversationRefreshKey;
  final Duration externalConversationRefreshInterval;
  final int externalConversationRefreshAttempts;
  final bool externalConversationRefreshUntilFound;

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage>
    with WidgetsBindingObserver {
  bool _appForeground = true;
  bool _historyRecoveryPending = false;
  Object? _historyRecoveryError;
  bool _initialRecoveryScheduled = false;
  int _localTurnRevision = 0;
  DateTime get _now => (widget.now ?? DateTime.now)();
  bool get _isPageVisible => widget.isVisible && _appForeground;
  String? get _completedMessageId =>
      _state.hasCompletedAssistantMessage ||
          _state.phase == AgentStreamRunPhase.finished
      ? (_state.messageId ??
            (_state.runId == null ? null : 'run:${_state.runId}:assistant'))
      : null;
  late AgentStreamRunState _state;
  late List<AgentHubHistoryMessage> _historyMessages;
  late final TextEditingController _composerController;
  final FocusNode _composerFocusNode = FocusNode();
  _AgentHubInteractionState? _interactionState;
  StreamSubscription<AgentStreamRunState>? _runSubscription;
  Completer<bool>? _runAcceptanceCompleter;
  Completer<void>? _runSettlementCompleter;
  Future<void>? _pendingServerCancel;
  bool _followUpStartPending = false;

  bool _conversationSwitchPending = false;
  int _sessionOperationGeneration = 0;
  int? _conversationHistoryBeforeSequence;
  bool _olderConversationHistoryLoading = false;
  bool _olderConversationHistoryLoadArmed = false;
  Object? _olderConversationHistoryError;
  final GlobalKey _olderHistoryViewportAnchorKey = GlobalKey();
  String? _olderHistoryViewportAnchorMessageId;
  AgentStreamRequest? _activeRequest;
  String? _submittedComposerText;

  final List<AgentStreamImageInput> _attachedImages = <AgentStreamImageInput>[];
  final List<AgentStreamFileInput> _attachedFiles = <AgentStreamFileInput>[];

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

  bool _interactionRestoreResolved = false;
  bool _showLatestButton = false;
  bool _attachmentUploadPending = false;
  final Set<String> _pendingAttachmentCleanupIds = <String>{};
  Timer? _attachmentCleanupRetryTimer;
  bool _attachmentCleanupInFlight = false;
  double? _attachmentUploadProgress;
  Timer? _persistentWriteTimer;
  Timer? _activeRunPersistentWriteTimer;
  AgentHubInteractionSnapshot? _pendingPersistentSnapshot;
  bool _scrollToLatestFrameScheduled = false;
  bool _scheduledScrollToLatestSmooth = false;
  int _scheduledScrollToLatestIntentVersion = 0;

  int _scrollIntentVersion = 0;

  bool _consumedInitialAutoSend = false;
  String? _consumedInitialAutoRunKey;
  bool _initialAutoRunInFlight = false;
  bool _dismissComposerKeyboardOnRunAccepted = false;
  String _greeting = agentHubDefaultGreeting;
  int _greetingRefreshGeneration = 0;
  int _externalConversationRefreshGeneration = 0;
  String? _consumedExternalConversationRefreshKey;
  String? _consumedInitialConversationId;
  bool _externalConversationRefreshPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreCachedInteractionState();

    _publishRunState(_state);
    _composerController.addListener(_handleComposerChanged);
    _chatScrollController.addListener(_handleChatScroll);

    _initializeInteractionState();
  }

  @override
  void didUpdateWidget(covariant AgentHubPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _returnToConversation();
      } else {
        _leaveConversation();
      }
    }
    if (oldWidget.initialConversationId != widget.initialConversationId &&
        _interactionRestoreResolved) {
      _scheduleInitialConversation();
    }
    if (_interactionState == null &&
        oldWidget.state != widget.state &&
        (widget.runner == null || !_state.isActive)) {
      _setRunState(widget.state);
    }
    if (_interactionState == null &&
        oldWidget.historyMessages != widget.historyMessages &&
        !_state.isActive) {
      _historyMessages = _visibleAgentHubHistoryMessages(
        widget.historyMessages,
      );
      _persistInteractionState();
    }
    if (oldWidget.initialComposerText != widget.initialComposerText) {
      _consumedInitialAutoSend = false;
      if (_interactionRestoreResolved) {
        _applyInitialComposerText();
        _scheduleInitialAutoSendIfNeeded();
      }
    } else if (oldWidget.initialAutoSend != widget.initialAutoSend &&
        _interactionRestoreResolved) {
      _scheduleInitialAutoSendIfNeeded();
    }
    if (oldWidget.initialAutoRunRequest?.idempotencyKey !=
            widget.initialAutoRunRequest?.idempotencyKey &&
        _interactionRestoreResolved) {
      _scheduleInitialAutoRunIfNeeded();
    }
    if (oldWidget.externalConversationRefreshKey !=
            widget.externalConversationRefreshKey &&
        _interactionRestoreResolved) {
      _scheduleExternalConversationRefreshIfNeeded();
    }
  }

  @override
  void dispose() {
    _leaveConversation();
    WidgetsBinding.instance.removeObserver(this);
    _externalConversationRefreshGeneration += 1;
    _attachmentCleanupRetryTimer?.cancel();
    _cancelRunSubscription();

    _persistInteractionState();
    _flushPersistentInteractionState();
    _composerController.removeListener(_handleComposerChanged);
    _chatScrollController
      ..removeListener(_handleChatScroll)
      ..dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _runStateNotifier.dispose();
    _visibleReplyRunningNotifier.dispose();
    _composerLockedNotifier.dispose();
    _responseLightRailModeNotifier.dispose();

    super.dispose();
  }

  void _setRunState(AgentStreamRunState nextState) {
    _state = _phaseOneRunState(nextState);
    _publishRunState(_state);
  }

  void _publishRunState(AgentStreamRunState state) {
    _runStateNotifier.value = state;
    _setNotifierValue(
      _visibleReplyRunningNotifier,
      _isVisibleReplyRunningForState(state),
    );
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);

    _setNotifierValue(
      _responseLightRailModeNotifier,
      _agentResponseLightRailModeForState(state),
    );
  }

  void _setNotifierValue<T>(ValueNotifier<T> notifier, T value) {
    if (notifier.value == value) return;
    notifier.value = value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_appForeground && widget.isVisible) _leaveConversation();
      _appForeground = false;
    } else if (state == AppLifecycleState.resumed && !_appForeground) {
      _appForeground = true;
      if (widget.isVisible) _returnToConversation();
    }
  }

  void _handleComposerChanged() {
    _persistInteractionState();
  }

  void _leaveConversation() {
    if (!_interactionRestoreResolved) return;
    _persistInteractionState();
    _flushPersistentInteractionState();
  }

  void _returnToConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isPageVisible || !_interactionRestoreResolved) return;
      unawaited(_recoverConversation());
    });
  }

  void _identifyAcceptedUserMessage(AgentStreamRunState nextState) {
    final queued = nextState.events
        .where((event) => event.type == 'run.queued' && event.messageId != null)
        .firstOrNull;
    if (queued == null) return;
    final index = _historyMessages.lastIndexWhere(
      (message) =>
          message.role == AgentHubHistoryRole.user &&
          message.id?.startsWith('local:') == true,
    );
    if (index < 0) return;
    final local = _historyMessages[index];
    _historyMessages[index] = AgentHubHistoryMessage(
      id: queued.messageId,
      sequence: local.sequence,
      createdAt: queued.createdAt ?? local.createdAt,
      role: local.role,
      content: local.content,
      images: local.images,
      files: local.files,
    );
  }

  Future<void> _recoverConversation() async {
    final repository = widget.conversationRepository;
    if (repository == null ||
        _historyRecoveryPending ||
        (widget.initialConversationId != null &&
            widget.initialConversationId != _state.threadId) ||
        _state.isActive ||
        (_activeRequest != null &&
            _state.phase != AgentStreamRunPhase.finished)) {
      if (_isPageVisible) _scheduleScrollToLatest();
      _persistInteractionState();
      return;
    }
    final generation = _sessionOperationGeneration;
    final revision = _localTurnRevision;
    final threadId = _state.threadId;
    setState(() {
      _historyRecoveryPending = true;
      _historyRecoveryError = null;
    });
    try {
      final history = threadId == null
          ? await repository.loadLatestConversation()
          : await repository.loadConversation(threadId);
      if (!mounted ||
          generation != _sessionOperationGeneration ||
          revision != _localTurnRevision ||
          _state.threadId != threadId ||
          _state.isActive) {
        return;
      }
      if (history != null) {
        final merged = _mergeRecoveredHistory(history);
        setState(() {
          _historyMessages = merged;
          _setRunState(history.currentState);
          _conversationHistoryBeforeSequence = history.nextBeforeSequence;
          _historyRecoveryPending = false;
        });
        _armOlderConversationHistoryLoading();
      }
      if (mounted) {
        setState(() => _historyRecoveryPending = false);
        _scheduleScrollToLatest();
        _persistInteractionState();
        if (history?.currentState.isActive == true && widget.runner != null) {
          await _resumeCurrentRun();
        }
      }
    } catch (error) {
      if (mounted &&
          generation == _sessionOperationGeneration &&
          revision == _localTurnRevision) {
        setState(() {
          _historyRecoveryPending = false;
          _historyRecoveryError = error;
        });
        if (_isPageVisible) _scheduleScrollToLatest();
      }
    } finally {
      if (mounted && _historyRecoveryPending) {
        setState(() => _historyRecoveryPending = false);
      }
    }
  }

  void _restoreCachedInteractionState() {
    final stateCacheKey = widget.stateCacheKey;
    if (stateCacheKey == null) {
      _state = _phaseOneRunState(widget.state);
      _historyMessages = _visibleAgentHubHistoryMessages(
        widget.historyMessages,
      );
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
      disconnectedMessage: 'Connection lost. Try again.',
    );
    _historyMessages = _visibleAgentHubHistoryMessages(
      interactionState.historyMessages ?? widget.historyMessages,
    );
    _composerController = TextEditingController(
      text: interactionState.composerText,
    );
    _attachedImages.addAll(interactionState.attachedImages);
    _attachedFiles.addAll(interactionState.attachedFiles);
    _pendingAttachmentCleanupIds.addAll(
      interactionState.pendingAttachmentCleanupIds,
    );

    _activeRequest = interactionState.activeRequest;
    _conversationHistoryBeforeSequence = interactionState.nextBeforeSequence;

    interactionState.runState = _state;
  }

  void _persistInteractionState() {
    if (!_interactionRestoreResolved) return;
    _updateCachedInteractionState();
    _activeRunPersistentWriteTimer?.cancel();
    _activeRunPersistentWriteTimer = null;
    _schedulePersistentInteractionStateWrite(_buildInteractionSnapshot());
  }

  void _persistActiveInteractionStateThrottled() {
    if (!_interactionRestoreResolved) return;
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
        ..attachedFiles = [..._attachedFiles]
        ..pendingAttachmentCleanupIds = [..._pendingAttachmentCleanupIds]
        ..activeRequest = _activeRequest
        ..nextBeforeSequence = _conversationHistoryBeforeSequence;
    }
  }

  void _updateCachedActiveRunState() {
    final interactionState = _interactionState;
    if (interactionState == null) return;
    interactionState
      ..runState = _state
      ..activeRequest = _activeRequest;
  }

  void _initializeInteractionState() {
    if (widget.interactionStateStore == null || _hasLocalInteraction()) {
      _interactionRestoreResolved = true;
      _applyInitialComposerText();
      _scheduleInitialAutoSendIfNeeded();
      _scheduleInitialAutoRunIfNeeded();
      _scheduleExternalConversationRefreshIfNeeded();
      _scheduleInitialInteractionPostFrame();
      unawaited(_retryAttachmentCleanup());
      return;
    }
    unawaited(_restorePersistedInteractionState());
  }

  Future<void> _restorePersistedInteractionState() async {
    final store = widget.interactionStateStore;
    AgentHubInteractionSnapshot? snapshot;
    try {
      snapshot = await store?.read();
    } catch (_) {
      snapshot = null;
    }
    if (!mounted) return;
    final shouldRestore =
        snapshot?.hasContent == true && !_hasLocalInteraction();
    setState(() {
      if (shouldRestore) _applyInteractionSnapshot(snapshot!);
      _pendingAttachmentCleanupIds.addAll(
        snapshot?.pendingAttachmentCleanupIds ?? const [],
      );
      _interactionRestoreResolved = true;
    });
    _applyInitialComposerText();
    _scheduleInitialAutoSendIfNeeded();
    _scheduleInitialAutoRunIfNeeded();
    _scheduleExternalConversationRefreshIfNeeded();
    if (shouldRestore) _persistInteractionState();
    unawaited(_retryAttachmentCleanup());
    _scheduleInitialInteractionPostFrame();
  }

  void _scheduleInitialConversation() {
    final id = widget.initialConversationId?.trim();
    if (id == null || id.isEmpty || id == _consumedInitialConversationId) {
      return;
    }
    _consumedInitialConversationId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final opened = await _loadTargetConversation(id);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open this conversation.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                _consumedInitialConversationId = null;
                _scheduleInitialConversation();
              },
            ),
          ),
        );
      }
    });
  }

  void _scheduleInitialInteractionPostFrame() {
    _scheduleInitialConversation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_interactionRestoreResolved) return;
      _scheduleScrollToLatest();
      _armOlderConversationHistoryLoading();
      if (!_initialRecoveryScheduled) {
        _initialRecoveryScheduled = true;
        unawaited(_recoverConversation());
      }
      unawaited(_refreshGreeting());
    });
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
        _attachedFiles.isNotEmpty ||
        _activeRequest != null;
  }

  void _applyInteractionSnapshot(AgentHubInteractionSnapshot snapshot) {
    _setRunState(
      _restoreInterruptedRunState(
        snapshot.runState,
        disconnectedMessage:
            'Connection interrupted. You can resume receiving.',
      ),
    );
    _historyMessages = _visibleAgentHubHistoryMessages(
      snapshot.historyMessages.map(_historyMessageFromSnapshot),
    );
    _composerController
      ..text = snapshot.composerText
      ..selection = TextSelection.collapsed(
        offset: snapshot.composerText.length,
      );
    _attachedImages
      ..clear()
      ..addAll(snapshot.attachedImages);
    _attachedFiles
      ..clear()
      ..addAll(snapshot.attachedFiles);

    _activeRequest = snapshot.activeRequest;
    _conversationHistoryBeforeSequence = snapshot.nextBeforeSequence;
  }

  AgentStreamRunState _restoreInterruptedRunState(
    AgentStreamRunState state, {
    required String disconnectedMessage,
  }) {
    if (!state.isActive) return _phaseOneRunState(state);
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
      attachedFiles: [..._attachedFiles],
      pendingAttachmentCleanupIds: [..._pendingAttachmentCleanupIds],
      activeRequest: _activeRequest,
      nextBeforeSequence: _conversationHistoryBeforeSequence,
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

  void _scheduleInitialAutoRunIfNeeded() {
    final request = widget.initialAutoRunRequest;
    final key = request?.idempotencyKey.trim() ?? '';
    if (request == null ||
        key.isEmpty ||
        request.requestMessage.trim().isEmpty ||
        widget.runner == null ||
        _initialAutoRunInFlight ||
        _consumedInitialAutoRunKey == key) {
      return;
    }
    _initialAutoRunInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await _sendSyntheticUserMessage(
        requestMessage: request.requestMessage,
        optimisticContent: '',
        metadata: request.metadata,
        idempotencyKey: key,
        awaitServerRunSignal: true,
      );
      if (!mounted) return;
      _initialAutoRunInFlight = false;
      if (accepted) _consumedInitialAutoRunKey = key;
    });
  }

  void _scheduleExternalConversationRefreshIfNeeded() {
    final key = widget.externalConversationRefreshKey?.trim() ?? '';
    if (key.isEmpty ||
        widget.conversationRepository == null ||
        (!widget.externalConversationRefreshUntilFound &&
            widget.externalConversationRefreshAttempts <= 0) ||
        _consumedExternalConversationRefreshKey == key) {
      return;
    }
    _consumedExternalConversationRefreshKey = key;
    final generation = ++_externalConversationRefreshGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _externalConversationRefreshGeneration) {
        return;
      }
      setState(() => _externalConversationRefreshPending = true);
      unawaited(_pollForExternalConversationUpdate(generation));
    });
  }

  Future<void> _pollForExternalConversationUpdate(int generation) async {
    final repository = widget.conversationRepository;
    final sourceThreadId = (_state.threadId ?? _activeRequest?.threadId)
        ?.trim();
    final sourceRunId = _state.runId?.trim() ?? '';
    if (repository == null ||
        sourceThreadId == null ||
        sourceThreadId.isEmpty) {
      _setExternalConversationRefreshPending(false);
      return;
    }
    var attempt = 0;
    while (widget.externalConversationRefreshUntilFound ||
        attempt < widget.externalConversationRefreshAttempts) {
      if (attempt > 0 &&
          widget.externalConversationRefreshInterval > Duration.zero) {
        final multiplier = 1 << (attempt - 1).clamp(0, 5);
        await Future<void>.delayed(
          widget.externalConversationRefreshInterval * multiplier,
        );
      } else if (attempt > 0) {
        await Future<void>.delayed(Duration.zero);
      }
      if (!mounted || generation != _externalConversationRefreshGeneration) {
        return;
      }
      final activeThreadId = (_state.threadId ?? _activeRequest?.threadId)
          ?.trim();
      final activeRunId = _state.runId?.trim() ?? '';
      if (activeThreadId != sourceThreadId || activeRunId != sourceRunId) {
        _setExternalConversationRefreshPending(false);
        return;
      }
      try {
        final history = await repository.loadConversation(sourceThreadId);
        if (!mounted || generation != _externalConversationRefreshGeneration) {
          return;
        }
        final nextRunId = history.currentState.runId?.trim() ?? '';
        if (history.thread.id != sourceThreadId ||
            nextRunId.isEmpty ||
            nextRunId == sourceRunId) {
          attempt += 1;
          continue;
        }
        final adopted = await _adoptExternalConversationHistory(history);
        if (adopted) return;
      } catch (_) {
        // The durable backend job may not have created its Agent run yet.
      }
      attempt += 1;
    }
    _setExternalConversationRefreshPending(false);
  }

  void _setExternalConversationRefreshPending(bool value) {
    if (!mounted || _externalConversationRefreshPending == value) return;
    setState(() => _externalConversationRefreshPending = value);
  }

  Future<bool> _adoptExternalConversationHistory(
    AgentConversationHistory history,
  ) async {
    if (!mounted || _isVisibleReplyRunning || _isSessionMutationPending) {
      return false;
    }

    final shouldFollow = _isPageVisible && _isNearLatest();
    final merged = _mergeRecoveredHistory(history);
    _cancelRunSubscription();
    setState(() {
      _externalConversationRefreshPending = false;
      _historyMessages = merged;
      _conversationHistoryBeforeSequence = history.nextBeforeSequence;
      _olderConversationHistoryLoading = false;
      _olderConversationHistoryLoadArmed = false;
      _olderConversationHistoryError = null;
      _setRunState(history.currentState);
      _activeRequest = null;
    });

    _persistInteractionState();
    _flushPersistentInteractionState();
    if (shouldFollow) _scheduleScrollToLatest();
    _armOlderConversationHistoryLoading();

    if (history.currentState.isActive &&
        history.currentState.runId?.trim().isNotEmpty == true &&
        widget.runner != null) {
      await _resumeCurrentRun();
      return true;
    }

    return true;
  }

  List<AgentHubHistoryMessage> _mergeRecoveredHistory(
    AgentConversationHistory history,
  ) {
    final remote = history.messages
        .map(_historyMessageFromConversation)
        .toList();
    if (_state.threadId != history.thread.id) return remote;
    final remoteIds = remote.map(_messageIdentity).toSet();
    final previousAssistant = _state.phase == AgentStreamRunPhase.idle
        ? null
        : _currentAssistantHistoryMessage();
    // Keep cached older records and merge by durable identity. The server
    // cursor still pages every gap, even if some older rows are cached.
    final retained = [..._historyMessages, ?previousAssistant].where(
      (message) =>
          message.id != null &&
          !remoteIds.contains(_messageIdentity(message)) &&
          _messageIdentity(message) != history.currentState.messageId &&
          (message.id == 'local:welcome' || !message.id!.startsWith('local:')),
    );
    return _mergeHistoryMessages([...retained, ...remote]);
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

  void _handleChatScroll() {
    _updateLatestButtonVisibility();
    if (!_olderConversationHistoryLoadArmed ||
        _olderConversationHistoryLoading ||
        _olderConversationHistoryError != null ||
        _conversationHistoryBeforeSequence == null ||
        !_chatScrollController.hasClients ||
        _chatScrollController.position.pixels > 120) {
      return;
    }
    unawaited(_loadOlderConversationHistory());
  }

  void _armOlderConversationHistoryLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _olderConversationHistoryLoadArmed = true;
    });
  }

  Future<void> _loadOlderConversationHistory() async {
    final repository = widget.conversationRepository;
    final threadId = (_state.threadId ?? _activeRequest?.threadId)?.trim();
    final beforeSequence = _conversationHistoryBeforeSequence;
    if (repository == null ||
        threadId == null ||
        threadId.isEmpty ||
        beforeSequence == null ||
        _olderConversationHistoryLoading) {
      return;
    }

    final operationGeneration = _sessionOperationGeneration;
    final oldExtent = _chatScrollController.hasClients
        ? _chatScrollController.position.maxScrollExtent
        : 0.0;
    final oldPixels = _chatScrollController.hasClients
        ? _chatScrollController.position.pixels
        : 0.0;
    final anchorMessageId = _historyMessages.firstOrNull == null
        ? null
        : _messageIdentity(_historyMessages.first);
    setState(() {
      _olderConversationHistoryLoading = true;
      _olderConversationHistoryError = null;
      _olderHistoryViewportAnchorMessageId = anchorMessageId;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted ||
          operationGeneration != _sessionOperationGeneration ||
          beforeSequence != _conversationHistoryBeforeSequence) {
        return;
      }
      final anchorTop = _olderHistoryViewportAnchorKey.currentContext
          ?.findRenderObject();
      final anchorTopBefore = anchorTop is RenderBox && anchorTop.hasSize
          ? anchorTop.localToGlobal(Offset.zero).dy
          : null;
      final page = await repository.loadConversation(
        threadId,
        beforeSequence: beforeSequence,
      );
      if (!mounted ||
          operationGeneration != _sessionOperationGeneration ||
          threadId != (_state.threadId ?? _activeRequest?.threadId) ||
          beforeSequence != _conversationHistoryBeforeSequence) {
        return;
      }
      final olderMessages = _historyMessagesFromOlderConversationPage(page);
      setState(() {
        final existingIds = _historyMessages.map(_messageIdentity).toSet()
          ..addAll([?_completedMessageId]);
        _historyMessages = _mergeHistoryMessages([
          ...olderMessages.where(
            (message) => existingIds.add(_messageIdentity(message)),
          ),
          ..._historyMessages,
        ]);
        _conversationHistoryBeforeSequence = page.nextBeforeSequence;
        _olderConversationHistoryLoading = false;
        _olderConversationHistoryError = null;
      });
      _persistInteractionState();
      var adjustmentAttempts = 0;
      void preserveViewport(Duration _) {
        if (!mounted || !_chatScrollController.hasClients) return;
        final position = _chatScrollController.position;
        final anchorRenderObject = _olderHistoryViewportAnchorKey.currentContext
            ?.findRenderObject();
        final anchorTopAfter =
            anchorRenderObject is RenderBox && anchorRenderObject.hasSize
            ? anchorRenderObject.localToGlobal(Offset.zero).dy
            : null;
        final target =
            adjustmentAttempts > 0 &&
                anchorTopBefore != null &&
                anchorTopAfter != null
            ? position.pixels + anchorTopAfter - anchorTopBefore
            : oldPixels + position.maxScrollExtent - oldExtent;
        final clampedTarget = target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        final settled = (position.pixels - clampedTarget).abs() <= 0.5;
        if (!settled) position.jumpTo(clampedTarget);
        _updateLatestButtonVisibility();
        if (!settled && ++adjustmentAttempts < 16) {
          WidgetsBinding.instance.addPostFrameCallback(preserveViewport);
          WidgetsBinding.instance.scheduleFrame();
        }
      }

      WidgetsBinding.instance.addPostFrameCallback(preserveViewport);
    } catch (error) {
      if (!mounted || operationGeneration != _sessionOperationGeneration) {
        return;
      }
      setState(() {
        _olderConversationHistoryLoading = false;
        _olderConversationHistoryError = error;
      });
    } finally {
      if (mounted &&
          operationGeneration == _sessionOperationGeneration &&
          _olderConversationHistoryLoading) {
        setState(() => _olderConversationHistoryLoading = false);
      }
    }
  }

  bool _isNearLatest([double threshold = 80]) {
    if (!_chatScrollController.hasClients) return true;
    final position = _chatScrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
  }

  void _scheduleScrollToLatest({bool smooth = false}) {
    final intentVersion = ++_scrollIntentVersion;
    _scheduledScrollToLatestIntentVersion = intentVersion;
    _scheduledScrollToLatestSmooth = _scheduledScrollToLatestSmooth || smooth;
    if (_scrollToLatestFrameScheduled) return;
    _scrollToLatestFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shouldSmooth = _scheduledScrollToLatestSmooth;
      final intentVersion = _scheduledScrollToLatestIntentVersion;
      _scrollToLatestFrameScheduled = false;
      _scheduledScrollToLatestSmooth = false;
      _scheduledScrollToLatestIntentVersion = 0;
      if (!mounted) return;
      if (intentVersion != _scrollIntentVersion) return;
      unawaited(
        _scrollToLatest(smooth: shouldSmooth).then((_) {
          if (!shouldSmooth) {
            _scheduleScrollToLatestCorrection(intentVersion);
          }
        }),
      );
    });
  }

  void _scheduleScrollToLatestCorrection(int intentVersion) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          intentVersion != _scrollIntentVersion ||
          !_chatScrollController.hasClients) {
        return;
      }
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
      await MomCozyMotion.scrollTo(
        context,
        _chatScrollController,
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

  Future<void> _scrollToLatestFromUser() async {
    _scrollIntentVersion += 1;
    await _scrollToLatest(smooth: TickerMode.valuesOf(context).enabled);
    if (!mounted) return;
    _scheduleScrollToLatestCorrection(_scrollIntentVersion);
  }

  bool _isVisibleReplyRunningForState(AgentStreamRunState state) =>
      state.isAwaitingVisibleReply;

  bool _canRetryForState(AgentStreamRunState state) =>
      widget.runner != null &&
      state.canRetry &&
      state.errorMessage != _unsupportedActionMessage &&
      _activeRequest != null;

  bool get _isComposerLocked =>
      _followUpStartPending ||
      _conversationSwitchPending ||
      _attachmentUploadPending;

  bool get _isVisibleReplyRunning => _isVisibleReplyRunningForState(_state);

  Future<void> _waitForCompletedReplyRunSettlement() async {
    final settlement = _runSettlementCompleter;
    final waitingState = _state;
    if (!waitingState.isActive ||
        !waitingState.hasCompletedAssistantMessage ||
        settlement == null ||
        settlement.isCompleted) {
      return;
    }

    _setFollowUpStartPending(true);
    try {
      await settlement.future.timeout(_completedReplyRunSettlementTimeout);
    } on TimeoutException {
      if (!mounted ||
          !identical(_runSettlementCompleter, settlement) ||
          !_state.isActive ||
          !_state.hasCompletedAssistantMessage ||
          _state.runId != waitingState.runId) {
        return;
      }
      final activeRequest = _activeRequest;
      _cancelRunSubscription();
      await _cancelServerRun(
        waitingState,
        activeRequest,
      ).timeout(_completedReplyCancelTimeout, onTimeout: () => null);
      if (!mounted || !_state.isActive || _state.runId != waitingState.runId) {
        return;
      }
      _setRunState(_state.finishVisibleReply());
      _persistInteractionState();
    } finally {
      if (mounted) {
        _setFollowUpStartPending(false);
      } else {
        _followUpStartPending = false;
      }
    }
  }

  void _setFollowUpStartPending(bool value) {
    if (_followUpStartPending == value) return;
    _followUpStartPending = value;
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
  }

  Future<void> _sendMessage() async {
    final runner = widget.runner;
    final message = _composerController.text.trim();
    if (runner == null ||
        (message.isEmpty &&
            _attachedImages.isEmpty &&
            _attachedFiles.isEmpty) ||
        _isComposerLocked) {
      return;
    }

    await _waitForCompletedReplyRunSettlement();
    await _waitForPendingServerCancel();
    if (!mounted || _isComposerLocked) return;

    final requestMessage = message.isNotEmpty
        ? message
        : (_attachedFiles.isNotEmpty && _attachedImages.isEmpty
              ? 'Please review this file'
              : 'Please look at this image');
    final sentImages = List<AgentStreamImageInput>.unmodifiable(
      _attachedImages,
    );
    final requestImages = List<AgentStreamImageInput>.unmodifiable(
      _attachedImages.map(
        (image) =>
            image.fileId.trim().isEmpty ? image : image.copyWith(dataUrl: ''),
      ),
    );
    final sentFiles = List<AgentStreamFileInput>.unmodifiable(_attachedFiles);
    final interruptedState = _state.isActive ? _state : null;
    final interruptedRequest = _state.isActive ? _activeRequest : null;
    final request = _requestWithWorkflowReply(
      _requestWithFiles(
        _requestWithImages(
          widget.requestBuilder(requestMessage),
          requestImages,
        ),
        sentFiles,
      ),
      _state.workflowReply,
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
          id: 'local:${_now.microsecondsSinceEpoch}:${++_localTurnRevision}',
          createdAt: _now,
          role: AgentHubHistoryRole.user,
          content: message,
          images: sentImages,
          files: sentFiles,
        ),
      );
      _attachedImages.clear();
      _attachedFiles.clear();
    });
    _persistInteractionState();
    _scheduleScrollToLatest();
    _dismissComposerKeyboardOnRunAccepted = true;
    await _startRun(request, submittedComposerText: message);
  }

  Future<bool> _sendSyntheticUserMessage({
    required String requestMessage,
    required String optimisticContent,
    Map<String, Object?> metadata = const {},
    String? idempotencyKey,
    bool awaitServerRunSignal = false,
  }) async {
    final runner = widget.runner;
    if (runner == null || requestMessage.trim().isEmpty || _isComposerLocked) {
      return false;
    }

    await _waitForCompletedReplyRunSettlement();
    await _waitForPendingServerCancel();
    if (!mounted || _isComposerLocked) return false;
    final request = _requestWithIdempotencyKey(
      _requestWithWorkflowReply(
        _requestWithMetadata(
          widget.requestBuilder(requestMessage.trim()),
          metadata,
        ),
        _state.workflowReply,
      ),
      idempotencyKey,
    );
    final abandonedAttachmentIds = _attachedFileIds().toList(growable: false);
    final interruptedState = _state.isActive ? _state : null;
    final interruptedRequest = _state.isActive ? _activeRequest : null;
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
      if (optimisticContent.trim().isNotEmpty) {
        _historyMessages.add(
          AgentHubHistoryMessage(
            id: 'local:${_now.microsecondsSinceEpoch}:${++_localTurnRevision}',
            createdAt: _now,
            role: AgentHubHistoryRole.user,
            content: optimisticContent,
          ),
        );
      }
      _attachedImages.clear();
      _attachedFiles.clear();
    });
    _queueAttachmentCleanup(abandonedAttachmentIds);
    _scheduleScrollToLatest();
    return _startRun(request, awaitServerRunSignal: awaitServerRunSignal);
  }

  AgentHubHistoryMessage? _currentAssistantHistoryMessage() {
    final state = _state;
    final text = _agentAssistantTextForState(state, greeting: _greeting).trim();
    if (text.isEmpty) return null;
    // Keep the visible welcome verbatim when the first-entry card becomes
    // an ordinary assistant bubble in the conversation history.
    return AgentHubHistoryMessage(
      id: state.phase == AgentStreamRunPhase.idle
          ? 'local:welcome'
          : state.messageId ?? 'run:${state.runId}:assistant',
      role: AgentHubHistoryRole.assistant,
      content: text,
      runState: state.phase == AgentStreamRunPhase.idle ? null : state,
    );
  }

  Future<void> _attachImage(AgentImageInputSource source) async {
    final pickImage = widget.pickImage;
    if (pickImage == null ||
        _isComposerLocked ||
        _attachmentUploadPending ||
        !_canAddAttachment) {
      return;
    }
    _setAttachmentUploadPending(true);
    AgentStreamImageInput? image;
    Object? failure;
    try {
      image = await pickImage(source);
      final mediaRepository = widget.mediaRepository;
      if (image != null &&
          mediaRepository != null &&
          image.fileId.trim().isEmpty) {
        final bytes = image.localBytes ?? _decodeAgentImageBytes(image.dataUrl);
        final uploaded = await mediaRepository.uploadFile(
          file: ApiUploadFile(
            name: image.name.trim().isEmpty ? 'image.png' : image.name.trim(),
            mimeType: image.mimeType.trim().isEmpty
                ? 'image/png'
                : image.mimeType.trim(),
            sizeBytes: bytes.length,
            bytes: bytes,
            openRead: image.openRead,
            onProgress: _handleAttachmentUploadProgress,
          ),
        );
        final fileId = uploaded.id.trim();
        if (fileId.isEmpty) {
          throw StateError('Image upload did not return a file id.');
        }
        image = image.copyWith(fileId: fileId, size: bytes.length);
      }
    } catch (error) {
      failure = error;
    }
    if (!mounted) {
      await _deleteAbandonedAttachments([image?.fileId ?? '']);
      return;
    }
    setState(() {
      _attachmentUploadPending = false;
      _attachmentUploadProgress = null;
      if (image != null && failure == null) {
        _attachedImages.add(image);
      }
    });
    _publishAttachmentUploadState();
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_attachmentFeedback('Image upload failed. Try again.'));
      return;
    }
    if (image == null) return;
    _persistInteractionState();
  }

  Future<void> _attachDocument() async {
    final pickDocument = widget.pickDocument;
    final mediaRepository = widget.mediaRepository;
    if (pickDocument == null ||
        mediaRepository == null ||
        _isComposerLocked ||
        _attachmentUploadPending ||
        !_canAddAttachment) {
      return;
    }
    _setAttachmentUploadPending(true);

    AgentStreamFileInput? file;
    Object? failure;
    try {
      final document = await pickDocument();
      if (document != null) {
        final uploaded = await mediaRepository.uploadFile(
          file: ApiUploadFile(
            name: document.name.trim().isEmpty
                ? 'document.pdf'
                : document.name.trim(),
            mimeType: 'application/pdf',
            sizeBytes: document.size,
            bytes: document.bytes,
            onProgress: _handleAttachmentUploadProgress,
          ),
        );
        final fileId = uploaded.id.trim();
        if (fileId.isEmpty) {
          throw StateError('Document upload did not return a file id.');
        }
        file = AgentStreamFileInput(
          fileId: fileId,
          mimeType: 'application/pdf',
          name: document.name,
          size: document.size,
        );
      }
    } catch (error) {
      failure = error;
    }
    if (!mounted) {
      await _deleteAbandonedAttachments([file?.fileId ?? '']);
      return;
    }
    setState(() {
      _attachmentUploadPending = false;
      _attachmentUploadProgress = null;
      if (file != null && failure == null) {
        _attachedFiles.add(file);
      }
    });
    _publishAttachmentUploadState();
    if (failure != null) {
      final message = switch (failure) {
        AgentDocumentInputException(code: 'file_too_large') =>
          'Files must be 10 MB or smaller.',
        AgentDocumentInputException(code: 'unsupported_file_type') =>
          'Only PDF files are supported for now.',
        _ => 'File upload failed. Try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(_attachmentFeedback(message));
      return;
    }
    if (file == null) return;
    _persistInteractionState();
  }

  void _setAttachmentUploadPending(bool value) {
    if (_attachmentUploadPending == value) return;
    setState(() {
      _attachmentUploadPending = value;
      _attachmentUploadProgress = null;
    });
    _publishAttachmentUploadState();
  }

  void _handleAttachmentUploadProgress(int sentBytes, int totalBytes) {
    if (!mounted || !_attachmentUploadPending || totalBytes <= 0) return;
    final next = (sentBytes / totalBytes).clamp(0.0, 1.0);
    final current = _attachmentUploadProgress;
    if (current != null && next < 1 && (next - current).abs() < 0.01) return;
    setState(() {
      _attachmentUploadProgress = next;
    });
  }

  void _publishAttachmentUploadState() {
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
  }

  bool get _canAddAttachment =>
      _attachedImages.length + _attachedFiles.length < _agentRunAttachmentLimit;

  void _removeAttachedImage(int index) {
    if (index < 0 || index >= _attachedImages.length) return;
    final removed = _attachedImages[index];
    setState(() => _attachedImages.removeAt(index));
    _queueAttachmentCleanup([removed.fileId]);
  }

  void _removeAttachedFile(int index) {
    if (index < 0 || index >= _attachedFiles.length) return;
    final removed = _attachedFiles[index];
    setState(() => _attachedFiles.removeAt(index));
    _queueAttachmentCleanup([removed.fileId]);
  }

  void _queueAttachmentCleanup(Iterable<String> fileIds) {
    _pendingAttachmentCleanupIds.addAll(
      fileIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );
    // Persist the removed draft and cleanup intent together before any request.
    _persistInteractionState();
    _flushPersistentInteractionState();
    _attachmentCleanupRetryTimer?.cancel();
    unawaited(_retryAttachmentCleanup());
  }

  Future<void> _retryAttachmentCleanup() async {
    if (!mounted ||
        _attachmentCleanupInFlight ||
        _pendingAttachmentCleanupIds.isEmpty ||
        widget.mediaRepository == null) {
      return;
    }
    _attachmentCleanupInFlight = true;
    final pending = _pendingAttachmentCleanupIds.toList(growable: false);
    final deleted = await _deleteAbandonedAttachments(pending);
    _attachmentCleanupInFlight = false;
    if (!mounted) return; // The persisted intent is retried on the next visit.
    if (deleted) {
      _pendingAttachmentCleanupIds.removeAll(pending);
      _persistInteractionState();
      _flushPersistentInteractionState();
    }
    if (_pendingAttachmentCleanupIds.isNotEmpty) {
      _attachmentCleanupRetryTimer = Timer(
        const Duration(seconds: 30),
        () => unawaited(_retryAttachmentCleanup()),
      );
    }
  }

  Iterable<String> _attachedFileIds() sync* {
    for (final image in _attachedImages) {
      yield image.fileId;
    }
    for (final file in _attachedFiles) {
      yield file.fileId;
    }
  }

  Future<bool> _deleteAbandonedAttachments(Iterable<String> fileIds) async {
    final normalizedIds = fileIds
        .map((fileId) => fileId.trim())
        .where((fileId) => fileId.isNotEmpty)
        .toSet();
    if (normalizedIds.isEmpty) return true;
    final repository = widget.mediaRepository;
    if (repository == null) return false;
    final results = await Future.wait(
      normalizedIds.map((fileId) async {
        try {
          await repository
              .deleteFile(
                fileId: fileId,
                idempotencyKey: 'agent-draft-discard:$fileId',
              )
              .timeout(const Duration(seconds: 20));
          return true;
        } on ApiHttpException catch (error) {
          return error.statusCode == 404;
        } catch (_) {
          return false;
        }
      }),
    );
    return results.every((deleted) => deleted);
  }

  SnackBar _attachmentFeedback(String message) => SnackBar(
    elevation: 0,
    backgroundColor: MomHomeTokens.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    content: Text(
      message,
      style: MomHomeTokens.text(14, color: MomHomeTokens.surface),
    ),
  );

  Future<bool> _loadTargetConversation(String threadId) async {
    final repository = widget.conversationRepository;
    final normalizedThreadId = threadId.trim();
    if (repository == null ||
        normalizedThreadId.isEmpty ||
        _isVisibleReplyRunning ||
        _attachmentUploadPending ||
        _conversationSwitchPending) {
      return false;
    }
    if (normalizedThreadId == (_state.threadId ?? _activeRequest?.threadId)) {
      return true;
    }

    final previousThreadId = _state.threadId;
    if (previousThreadId != null) {
      _interactionState?.threads[previousThreadId] =
          _buildInteractionSnapshot();
    }
    final cached = _interactionState?.threads[normalizedThreadId];
    if (cached != null) {
      _sessionOperationGeneration += 1;
      setState(() => _applyInteractionSnapshot(cached));
      _returnToConversation();
      return true;
    }
    final operationGeneration = ++_sessionOperationGeneration;
    _setConversationSwitchPending(true);
    try {
      final history = await repository.loadConversation(normalizedThreadId);
      if (!mounted ||
          operationGeneration != _sessionOperationGeneration ||
          !_conversationSwitchPending) {
        return false;
      }

      final abandonedAttachmentIds = _attachedFileIds().toList();

      _cancelRunSubscription();
      _composerController.clear();

      setState(() {
        _historyMessages = history.messages
            .map(_historyMessageFromConversation)
            .toList(growable: true);
        _conversationHistoryBeforeSequence = history.nextBeforeSequence;
        _olderConversationHistoryLoading = false;
        _olderConversationHistoryLoadArmed = false;
        _olderConversationHistoryError = null;
        _setRunState(history.currentState);
        _attachedImages.clear();
        _attachedFiles.clear();
        _activeRequest = null;
      });

      _queueAttachmentCleanup(abandonedAttachmentIds);
      _persistInteractionState();
      _flushPersistentInteractionState();
      _scheduleScrollToLatest();
      _armOlderConversationHistoryLoading();

      if (history.currentState.isActive &&
          history.currentState.runId?.trim().isNotEmpty == true &&
          widget.runner != null) {
        await _resumeCurrentRun();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (operationGeneration == _sessionOperationGeneration) {
        _setConversationSwitchPending(false);
      }
    }
  }

  void _setConversationSwitchPending(bool value) {
    if (_conversationSwitchPending == value) return;
    _conversationSwitchPending = value;
    _publishSessionMutationState();
  }

  bool get _isSessionMutationPending => _conversationSwitchPending;

  void _publishSessionMutationState() {
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
  }

  Future<void> _refreshGreeting() async {
    final loader = widget.greetingProfileLoader;
    if (loader == null) {
      return;
    }

    final generation = ++_greetingRefreshGeneration;
    AgentHubGreetingProfile? profile;
    var loaded = false;
    try {
      profile = await loader();
      loaded = true;
    } catch (_) {
      // Greeting personalization is best effort; the default stays available.
    }
    if (!mounted || generation != _greetingRefreshGeneration) return;
    final isShowingFreshGreeting = _isShowingFreshGreeting;
    if (loaded) {
      final nextGreeting = agentHubGreetingForProfile(profile);
      setState(() {
        if (isShowingFreshGreeting) _greeting = nextGreeting;
      });
    }
    if (!isShowingFreshGreeting) return;
  }

  bool get _isShowingFreshGreeting =>
      _state.phase == AgentStreamRunPhase.idle &&
      _state.textContent.trim().isEmpty &&
      _state.provisionalTextContent.trim().isEmpty &&
      _historyMessages.isEmpty &&
      _activeRequest == null;

  Future<void> _retryRun() async {
    final request = _activeRequest;
    if (request == null || !_canRetryForState(_state)) return;
    final submittedText = _submittedComposerText;
    if (submittedText != null && _composerController.text == submittedText) {
      _composerController.clear();
    }
    final runId = _state.runId?.trim();
    if (runId != null && runId.isNotEmpty) {
      await _startRun(
        request.resume(
          runId: runId,
          threadId: _state.threadId,
          afterSequence: _state.lastSequence ?? 0,
          afterTransientCursor: _state.lastTransientCursor,
        ),
        initialState: _state.copyWith(phase: AgentStreamRunPhase.streaming),
        submittedComposerText: submittedText,
      );
      return;
    }
    await _startRun(request, submittedComposerText: submittedText);
  }

  Future<void> _resumeCurrentRun() async {
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
        afterTransientCursor: _state.lastTransientCursor,
      ),
      initialState: _state.copyWith(phase: AgentStreamRunPhase.streaming),
    );
  }

  void _handleRunStateUpdate(AgentStreamRunState nextState) {
    if (!mounted || !_state.isActive) return;
    final submittedText = _submittedComposerText;
    if ((nextState.phase == AgentStreamRunPhase.error ||
            nextState.phase == AgentStreamRunPhase.disconnected) &&
        _composerController.text.isEmpty &&
        submittedText != null &&
        submittedText.isNotEmpty &&
        _activeRequest?.message == submittedText) {
      _composerController.value = TextEditingValue(
        text: submittedText,
        selection: TextSelection.collapsed(offset: submittedText.length),
      );
    }
    if (nextState.phase == AgentStreamRunPhase.waitingForConfirmation &&
        _state.phase != AgentStreamRunPhase.waitingForConfirmation) {
      _sendBestEffortServerCancel(nextState, _activeRequest);
    }
    _forwardNewApplicationEvents(_state, nextState);
    _updateComposerFocusForRun(nextState);
    final shouldFollowLatest = _isPageVisible && _isNearLatest();
    _identifyAcceptedUserMessage(nextState);
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      _activeRequest = _requestWithThreadId(activeRequest, nextState.threadId);
    }
    _applyRunStateUpdate(nextState, shouldFollowLatest: shouldFollowLatest);
  }

  void _updateComposerFocusForRun(AgentStreamRunState nextState) {
    if (!_dismissComposerKeyboardOnRunAccepted) return;
    if (nextState.phase == AgentStreamRunPhase.error ||
        nextState.phase == AgentStreamRunPhase.disconnected ||
        nextState.phase == AgentStreamRunPhase.cancelled) {
      _dismissComposerKeyboardOnRunAccepted = false;
      return;
    }

    if (!_hasServerRunSignal(nextState)) return;

    _dismissComposerKeyboardOnRunAccepted = false;
    if (_composerFocusNode.hasFocus) _composerFocusNode.unfocus();
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

    if (shouldFollowLatest) {
      _scheduleScrollToLatest();
    }
  }

  Future<bool> _startRun(
    AgentStreamRequest request, {
    String? submittedComposerText,
    AgentStreamRunState? initialState,
    bool awaitServerRunSignal = false,
  }) async {
    final runner = widget.runner;
    if (runner == null || (initialState == null && _isComposerLocked)) {
      return false;
    }
    final requestWithIdempotency =
        request.runId?.trim().isNotEmpty == true ||
            request.idempotencyKey?.trim().isNotEmpty == true
        ? request
        : _requestWithIdempotencyKey(request, _newAgentRunIdempotencyKey());
    final requestWithThread = _requestWithConversationThread(
      requestWithIdempotency,
    );
    _submittedComposerText = submittedComposerText;

    _cancelRunSubscription();
    final acceptance = awaitServerRunSignal ? Completer<bool>() : null;
    final settlement = Completer<void>();
    _runAcceptanceCompleter = acceptance;
    _runSettlementCompleter = settlement;

    _activeRequest = requestWithThread;
    _localTurnRevision += 1;
    setState(() {
      _setRunState(initialState ?? const AgentStreamRunState().start());
    });
    _persistInteractionState();
    if (initialState == null || (_isPageVisible && _isNearLatest())) {
      _scheduleScrollToLatest();
    }

    _runSubscription = runner
        .run(requestWithThread, initialState: initialState)
        .listen(
          (nextState) {
            _handleRunStateUpdate(nextState);
            if (!nextState.isActive) {
              _completeRunSettlement(settlement);
            }
            if (_hasServerRunSignal(nextState)) {
              _completeRunAcceptance(acceptance, true);
            } else if (!nextState.isActive) {
              _completeRunAcceptance(acceptance, false);
            }
          },
          onError: (Object error) {
            _completeRunAcceptance(acceptance, false);
            _completeRunSettlement(settlement);
            if (!mounted || !_state.isActive) return;
            _dismissComposerKeyboardOnRunAccepted = false;
            final shouldFollowLatest = _isNearLatest();
            _setRunState(_state.markDisconnected(error));
            _persistInteractionState();
            if (shouldFollowLatest) _scheduleScrollToLatest();
          },
          onDone: () {
            _completeRunAcceptance(acceptance, false);
            _completeRunSettlement(settlement);
          },
        );
    return acceptance == null ? true : acceptance.future;
  }

  void _completeRunAcceptance(Completer<bool>? completer, bool accepted) {
    if (completer == null || completer.isCompleted) return;
    if (identical(_runAcceptanceCompleter, completer)) {
      _runAcceptanceCompleter = null;
    }
    completer.complete(accepted);
  }

  void _completeRunSettlement(Completer<void>? completer) {
    if (completer == null || completer.isCompleted) return;
    if (identical(_runSettlementCompleter, completer)) {
      _runSettlementCompleter = null;
    }
    completer.complete();
  }

  AgentStreamRequest _requestWithConversationThread(
    AgentStreamRequest request,
  ) {
    return _requestWithThreadId(
      request,
      request.threadId ?? _state.threadId ?? _activeRequest?.threadId,
    );
  }

  void _cancelRun() {
    if (!_state.isActive) return;
    final activeState = _state;
    final activeRequest = _activeRequest;

    _dismissComposerKeyboardOnRunAccepted = false;

    _setRunState(activeState.requestCancel());
    _persistInteractionState();
    _cancelRunSubscription();
    final hasServerRun =
        widget.cancelClient != null &&
        activeState.runId?.trim().isNotEmpty == true;
    if (hasServerRun) {
      _sendBestEffortServerCancel(activeState, activeRequest);
    } else {
      _setRunState(_state.applyCancelResult(acknowledged: true));
      _persistInteractionState();
    }
  }

  void _cancelRunSubscription() {
    final acceptance = _runAcceptanceCompleter;
    _runAcceptanceCompleter = null;
    _completeRunAcceptance(acceptance, false);
    final settlement = _runSettlementCompleter;
    _runSettlementCompleter = null;
    _completeRunSettlement(settlement);
    final subscription = _runSubscription;
    _runSubscription = null;
    if (subscription == null) return;
    unawaited(subscription.cancel().catchError((Object _) {}));
  }

  void _sendBestEffortServerCancel(
    AgentStreamRunState activeState,
    AgentStreamRequest? activeRequest,
  ) {
    final operation = _settleServerCancel(activeState, activeRequest);
    _pendingServerCancel = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_pendingServerCancel, operation)) {
          _pendingServerCancel = null;
        }
      }),
    );
  }

  Future<void> _settleServerCancel(
    AgentStreamRunState activeState,
    AgentStreamRequest? activeRequest,
  ) async {
    AgentStreamCancelResult? result;
    try {
      result = await _cancelServerRun(
        activeState,
        activeRequest,
      ).timeout(_completedReplyCancelTimeout);
    } catch (error) {
      result = AgentStreamCancelResult(acknowledged: false, error: error);
    }
    if (!mounted || result == null) return;
    if (_state.phase != AgentStreamRunPhase.cancelRequested ||
        _state.runId != activeState.runId) {
      return;
    }
    final failure = result.acknowledged
        ? null
        : result.error ??
              result.body ??
              'Server cancellation was not acknowledged.';
    _setRunState(
      _state.applyCancelResult(
        acknowledged: result.acknowledged,
        statusCode: result.statusCode,
        error: failure,
      ),
    );
    _persistInteractionState();
  }

  Future<void> _waitForPendingServerCancel() async {
    final pending = _pendingServerCancel;
    if (pending == null) return;
    _setFollowUpStartPending(true);
    try {
      await pending;
    } finally {
      if (mounted) {
        _setFollowUpStartPending(false);
      } else {
        _followUpStartPending = false;
      }
    }
  }

  Future<AgentStreamCancelResult?> _cancelServerRun(
    AgentStreamRunState activeState,
    AgentStreamRequest? activeRequest,
  ) async {
    final cancelClient = widget.cancelClient;
    if (cancelClient == null) return null;

    final runId = activeState.runId;
    if (runId == null || runId.trim().isEmpty) return null;

    return cancelClient.cancel(
      AgentStreamCancelRequest(
        threadId: activeState.threadId ?? activeRequest?.threadId ?? '',
        runId: runId,
        reason: 'user_cancelled',
      ),
    );
  }

  void _forwardNewApplicationEvents(
    AgentStreamRunState previous,
    AgentStreamRunState next,
  ) {
    final handler = widget.onApplicationEvent;
    if (handler == null || next.events.length <= previous.events.length) return;
    for (final event in next.events.skip(previous.events.length)) {
      handler(event);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, pageConstraints) {
      final page = ColoredBox(
        key: const ValueKey('agent-hub-page'),
        color: MomHomeTokens.background,
        child: Stack(
          children: [
            const Positioned.fill(child: _AgentPageBackground()),
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
                if (_externalConversationRefreshPending)
                  Container(
                    key: const ValueKey('motion-feedback-pending'),
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: MomCozyColors.roseSoft,
                      borderRadius: BorderRadius.circular(MomCozyRadii.card),
                      border: Border.all(color: MomCozyColors.border),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MomCozyColors.primary,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Preparing your posture assessment feedback…',
                            style: TextStyle(
                              color: MomCozyColors.foreground,
                              fontSize: MomCozyTypography.secondarySize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const verticalTranscriptPadding = 24.0 + 28.0;
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
                              if (_conversationHistoryBeforeSequence != null ||
                                  _olderConversationHistoryLoading ||
                                  _olderConversationHistoryError != null)
                                SliverToBoxAdapter(
                                  child: _AgentOlderConversationHistoryControl(
                                    loading: _olderConversationHistoryLoading,
                                    failed:
                                        _olderConversationHistoryError != null,
                                    onLoad: _loadOlderConversationHistory,
                                  ),
                                ),
                              if (_historyMessages.isNotEmpty)
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    24,
                                    16,
                                    0,
                                  ),
                                  sliver: AgentHubHistorySliver(
                                    messages: _historyMessages,
                                    viewportAnchorMessageId:
                                        _olderHistoryViewportAnchorMessageId,
                                    viewportAnchorKey:
                                        _olderHistoryViewportAnchorKey,
                                    loadImageThumbnail:
                                        widget.loadImageThumbnail,
                                    loadImageContent: widget.loadImageContent,
                                  ),
                                ),
                              if (_historyMessages.isNotEmpty)
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 18),
                                ),
                              if (!(_state.phase == AgentStreamRunPhase.idle &&
                                      _historyMessages.isNotEmpty) &&
                                  _interactionRestoreResolved &&
                                  !(_historyRecoveryPending &&
                                      !_hasLocalInteraction()) &&
                                  !(_historyRecoveryError != null &&
                                      !_hasLocalInteraction()))
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    _historyMessages.isEmpty ? 24 : 0,
                                    16,
                                    28,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: _historyMessages.isEmpty
                                            ? transcriptMinHeight
                                            : 0,
                                      ),
                                      child: _AgentRunTranscriptListenable(
                                        greeting: _greeting,
                                        stateListenable: _runStateNotifier,
                                        onTextRevealed: () {
                                          if (_isPageVisible &&
                                              _isNearLatest()) {
                                            _scheduleScrollToLatest();
                                          }
                                        },
                                        canRetryForState: _canRetryForState,
                                        onRetry: _retryRun,
                                        // Generated quick replies are temporarily hidden
                                        // while the follow-up interaction is redesigned.
                                        onQuickReplySelected: null,
                                      ),
                                    ),
                                  ),
                                )
                              else if (_historyMessages.isEmpty)
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: transcriptMinHeight,
                                    child: _historyRecoveryError != null
                                        ? Center(
                                            child: TextButton(
                                              onPressed: _recoverConversation,
                                              child: const Text(
                                                'Could not load earlier messages. Tap to try again.',
                                              ),
                                            ),
                                          )
                                        : const Center(
                                            child: Text(
                                              'Restoring conversation…',
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                          if (_showLatestButton)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: FilledButton.tonalIcon(
                                key: const ValueKey(
                                  'agent-scroll-latest-button',
                                ),
                                onPressed: _scrollToLatestFromUser,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                label: const Text('Jump to latest message'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: MomHomeTokens.rose,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(44, 44),
                                  textStyle: MomHomeTokens.text(
                                    13,
                                    weight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
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
                    final isVisibleReplyRunning =
                        _visibleReplyRunningNotifier.value;
                    final isComposerLocked = _composerLockedNotifier.value;
                    final isRestoring = !_interactionRestoreResolved;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_historyRecoveryError != null &&
                            _hasLocalInteraction())
                          TextButton(
                            onPressed: _recoverConversation,
                            child: const Text(
                              'Could not sync history. Tap to try again.',
                            ),
                          ),
                        _AgentHomeShortcuts(
                          onSelected:
                              widget.runner == null ||
                                  isComposerLocked ||
                                  isRestoring ||
                                  isVisibleReplyRunning ||
                                  _attachmentUploadPending
                              ? null
                              : (prompt) {
                                  _composerController.text = prompt;
                                  unawaited(_sendMessage());
                                },
                        ),
                        AgentComposerBar(
                          controller: _composerController,
                          focusNode: _composerFocusNode,
                          canSend:
                              widget.runner != null &&
                              !isComposerLocked &&
                              !isRestoring,
                          isRunning: isVisibleReplyRunning,
                          isInputLocked: isComposerLocked || isRestoring,
                          images: List<AgentStreamImageInput>.unmodifiable(
                            _attachedImages,
                          ),
                          files: List<AgentStreamFileInput>.unmodifiable(
                            _attachedFiles,
                          ),
                          canAttachImage:
                              widget.pickImage != null &&
                              !_attachmentUploadPending &&
                              _canAddAttachment &&
                              !isComposerLocked &&
                              !isRestoring,
                          canAttachFile:
                              widget.pickDocument != null &&
                              widget.mediaRepository != null &&
                              !_attachmentUploadPending &&
                              _canAddAttachment &&
                              !isComposerLocked &&
                              !isRestoring,
                          isAttachmentPending: _attachmentUploadPending,
                          attachmentUploadProgress: _attachmentUploadProgress,
                          onChanged: (_) {},
                          onSend: _sendMessage,
                          onCancel: _cancelRun,
                          onTakePhoto: () => unawaited(
                            _attachImage(AgentImageInputSource.camera),
                          ),
                          onPickPhoto: () => unawaited(
                            _attachImage(AgentImageInputSource.gallery),
                          ),
                          onPickFile: () => unawaited(_attachDocument()),
                          onRemoveImage: _removeAttachedImage,
                          onRemoveFile: _removeAttachedFile,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
      return page;
    },
  );
}

class _AgentHomeShortcuts extends StatelessWidget {
  const _AgentHomeShortcuts({required this.onSelected});
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final action in const [
            (
              'Milk supply insights',
              'I would like to understand my milk supply and feeding. Start by asking me the most important question.',
            ),
            (
              'Postpartum recovery check-in',
              'I would like a postpartum recovery check-in. Start with the most important question.',
            ),
          ])
            OutlinedButton(
              onPressed: onSelected == null
                  ? null
                  : () => onSelected!(action.$2),
              style: OutlinedButton.styleFrom(
                foregroundColor: MomHomeTokens.rose,
                backgroundColor: MomHomeTokens.surface,
                side: const BorderSide(color: MomHomeTokens.border),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'NotoSansSCHome',
                  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(action.$1),
            ),
        ],
      ),
    ),
  );
}

class _AgentOlderConversationHistoryControl extends StatelessWidget {
  const _AgentOlderConversationHistoryControl({
    required this.loading,
    required this.failed,
    required this.onLoad,
  });

  final bool loading;
  final bool failed;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Center(
        child: loading
            ? const SizedBox.square(
                key: ValueKey('agent-conversation-older-loading'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                key: ValueKey(
                  failed
                      ? 'agent-conversation-older-retry'
                      : 'agent-conversation-older-load',
                ),
                onPressed: onLoad,
                icon: Icon(
                  failed
                      ? Icons.refresh_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 18,
                ),
                label: Text(
                  failed
                      ? 'Could not load. Tap to try again.'
                      : 'Load earlier messages',
                ),
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
  return state.toolEvents.values.any(
    (event) => event.type == 'tool.started' || event.type == 'tool.progress',
  );
}

void _syncAgentDecoration(
  BuildContext context,
  AnimationController controller,
) {
  if (MediaQuery.disableAnimationsOf(context) ||
      !TickerMode.valuesOf(context).enabled) {
    controller.stop();
    controller.value = 0;
  } else if (!controller.isAnimating) {
    controller.repeat();
  }
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
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAgentDecoration(context, _controller);
  }

  @override
  void didUpdateWidget(covariant _AgentResponseLightRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == oldWidget.mode) return;
    _controller.duration = _durationForMode(widget.mode);
    _controller.stop();
    _syncAgentDecoration(context, _controller);
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
          MomCozyColors.violetSoft.withValues(alpha: opacity * 1.10),
          MomCozyColors.violet.withValues(alpha: opacity * 0.44),
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
          MomCozyColors.violetSoft.withValues(alpha: opacity * 0.42),
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
        MomCozyColors.violetSoft.withValues(alpha: 0.34 * modeStrength),
        MomCozyColors.violet.withValues(alpha: 0.82 * modeStrength),
        Colors.white.withValues(alpha: 0.92 * modeStrength),
        MomCozyColors.warm.withValues(alpha: 0.54 * modeStrength),
        Colors.transparent,
        MomCozyColors.care.withValues(alpha: 0.42 * modeStrength),
        Colors.white.withValues(alpha: 0.60 * modeStrength),
        Colors.transparent,
      ],
      stops: const [0, 0.08, 0.13, 0.17, 0.23, 0.40, 0.55, 0.62, 1],
    ).createShader(rect);
    canvas.drawPath(border, Paint()..shader = shader);

    final sideGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = mode == _AgentResponseLightRailMode.loop ? 9 : 7
      ..color = MomCozyColors.violet.withValues(
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

class _AgentPageBackground extends StatelessWidget {
  const _AgentPageBackground();
  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: MomHomeTokens.background);
}

class _AgentAssistantTurn extends StatelessWidget {
  const _AgentAssistantTurn({
    super.key,
    required this.avatar,
    required this.child,
    this.fullWidth = false,
  });
  final Widget avatar;
  final Widget child;
  final bool fullWidth;
  @override
  Widget build(BuildContext context) {
    if (fullWidth) return child;
    if (MediaQuery.textScalerOf(context).scale(16) > 21) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              avatar,
              const SizedBox(width: 8),
              Text(
                'Momcozy AI',
                style: MomHomeTokens.text(12, color: MomHomeTokens.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

class _AgentWelcomeCard extends StatelessWidget {
  const _AgentWelcomeCard({required this.text, required this.avatar});
  final String text;
  final Widget avatar;
  @override
  Widget build(BuildContext context) {
    final split = text.indexOf('\n');
    final heading = split < 0 ? text : text.substring(0, split);
    final body = split < 0 ? '' : text.substring(split).trim();
    return MomSettingsCard(
      backgroundDecoration: MomCardDecoration.ai,
      gradient: MomHomeTokens.ai,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                heading,
                style: MomHomeTokens.text(
                  18,
                  weight: FontWeight.w700,
                  height: 26 / 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            avatar,
          ],
        ),
        if (body.isNotEmpty)
          Text(body, style: MomHomeTokens.text(14, height: 1.55)),
      ],
    );
  }
}

class _AgentAssistantBubble extends StatelessWidget {
  const _AgentAssistantBubble({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('agent-assistant-bubble'),
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 360 ? 13 : 16,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: MomHomeTokens.surface,
      border: Border.all(color: MomHomeTokens.border),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(22),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(22),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x032B2826),
          blurRadius: 20,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
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
    files: request.files,
    metadata: request.metadata,
    idempotencyKey: request.idempotencyKey,
  );
}

AgentStreamRequest _requestWithFiles(
  AgentStreamRequest request,
  List<AgentStreamFileInput> files,
) {
  if (files.isEmpty) return request;
  return AgentStreamRequest(
    message: request.message,
    threadId: request.threadId,
    locale: request.locale,
    images: request.images,
    files: [...request.files, ...files],
    metadata: request.metadata,
    idempotencyKey: request.idempotencyKey,
  );
}

List<int> _decodeAgentImageBytes(String dataUrl) {
  final marker = dataUrl.indexOf(',');
  if (marker < 0 || !dataUrl.substring(0, marker).contains(';base64')) {
    throw const FormatException('Image input is not a Base64 data URL.');
  }
  final bytes = base64Decode(dataUrl.substring(marker + 1));
  if (bytes.isEmpty) {
    throw const FormatException('Image input is empty.');
  }
  return bytes;
}

AgentStreamRequest _requestWithIdempotencyKey(
  AgentStreamRequest request,
  String? idempotencyKey,
) {
  final normalized = idempotencyKey?.trim();
  if (normalized == null || normalized.isEmpty) return request;
  return AgentStreamRequest(
    message: request.message,
    threadId: request.threadId,
    runId: request.runId,
    afterSequence: request.afterSequence,
    locale: request.locale,
    images: request.images,
    files: request.files,
    metadata: request.metadata,
    idempotencyKey: normalized,
  );
}

AgentStreamRequest _requestWithMetadata(
  AgentStreamRequest request,
  Map<String, Object?> metadata,
) {
  if (metadata.isEmpty) return request;
  return AgentStreamRequest(
    message: request.message,
    threadId: request.threadId,
    runId: request.runId,
    afterSequence: request.afterSequence,
    locale: request.locale,
    images: request.images,
    files: request.files,
    metadata: {...request.metadata, ...metadata},
    idempotencyKey: request.idempotencyKey,
  );
}

AgentStreamRequest _requestWithWorkflowReply(
  AgentStreamRequest request,
  Map<String, Object?>? workflowReply,
) {
  if (workflowReply == null || workflowReply.isEmpty) return request;
  return _requestWithMetadata(request, {'workflow_reply': workflowReply});
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
    files: request.files,
    metadata: request.metadata,
    idempotencyKey: request.idempotencyKey,
  );
}

enum AgentHubHistoryRole { user, assistant }

class AgentHubHistoryMessage {
  const AgentHubHistoryMessage({
    required this.role,
    required this.content,
    this.id,
    this.sequence,
    this.createdAt,
    this.runState,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
  });

  final String? id;
  final int? sequence;
  final DateTime? createdAt;
  final AgentHubHistoryRole role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;

  String get roleLabel {
    return switch (role) {
      AgentHubHistoryRole.user => 'Me',
      AgentHubHistoryRole.assistant => 'Momcozy AI',
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
    id: snapshot.id,
    sequence: snapshot.sequence,
    createdAt: snapshot.createdAt,
    content: snapshot.content,
    runState: snapshot.runState,
    images: snapshot.images,
    files: snapshot.files,
  );
}

AgentHubHistoryMessage _historyMessageFromConversation(
  AgentConversationMessage message,
) {
  return AgentHubHistoryMessage(
    role: message.role == AgentConversationMessageRole.user
        ? AgentHubHistoryRole.user
        : AgentHubHistoryRole.assistant,
    id: message.id,
    sequence: message.sequence,
    createdAt: message.createdAt,
    content: message.content,
    runState: message.runState,
    images: message.images,
    files: message.files,
  );
}

List<AgentHubHistoryMessage> _visibleAgentHubHistoryMessages(
  Iterable<AgentHubHistoryMessage> messages,
) {
  return [
    for (final message in messages)
      if (message.role != AgentHubHistoryRole.user ||
          !isMotionAssessmentCompletionPrompt(message.content))
        message,
  ];
}

List<AgentHubHistoryMessage> _historyMessagesFromOlderConversationPage(
  AgentConversationHistory page,
) {
  final messages = page.messages
      .map(_historyMessageFromConversation)
      .toList(growable: true);
  if (hasAgentConversationAssistantProjection(page.currentState)) {
    messages.add(
      AgentHubHistoryMessage(
        role: AgentHubHistoryRole.assistant,
        id:
            page.currentState.messageId ??
            'run:${page.currentState.runId}:assistant',
        createdAt: page.latestMessageCreatedAt,
        content: page.currentState.textContent,
        runState: page.currentState,
      ),
    );
  }
  return messages;
}

AgentHubHistorySnapshot _historySnapshotFromMessage(
  AgentHubHistoryMessage message,
) {
  return AgentHubHistorySnapshot(
    role: message.role == AgentHubHistoryRole.user ? 'user' : 'assistant',
    id: message.id,
    sequence: message.sequence,
    createdAt: message.createdAt,
    content: message.content,
    runState: _historyRunStateForPersistence(message),
    images: message.images,
    files: message.files,
  );
}

AgentStreamRunState? _historyRunStateForPersistence(
  AgentHubHistoryMessage message,
) {
  final state = message.runState;
  if (message.role != AgentHubHistoryRole.assistant || state == null) {
    return null;
  }

  return AgentStreamRunState(
    phase: AgentStreamRunPhase.finished,
    textContent: state.textContent,
    messageId: state.messageId,
    runId: state.runId,
    threadId: state.threadId,
  );
}

class AgentHubHistoryPanel extends StatelessWidget {
  const AgentHubHistoryPanel({
    super.key,
    required this.messages,
    this.loadImageThumbnail,
    this.loadImageContent,
  });

  final List<AgentHubHistoryMessage> messages;

  final AgentImageContentLoader? loadImageThumbnail;
  final AgentImageContentLoader? loadImageContent;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('agent-history-panel'),
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          _AgentHistoryBubble(
            key: ValueKey('agent-history-$index'),
            message: messages[index],
            loadImageThumbnail: loadImageThumbnail,
            loadImageContent: loadImageContent,
          ),
          if (index != messages.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class AgentHubHistorySliver extends StatelessWidget {
  const AgentHubHistorySliver({
    super.key,
    required this.messages,
    this.viewportAnchorMessageId,
    this.viewportAnchorKey,
    this.loadImageThumbnail,
    this.loadImageContent,
  });

  final List<AgentHubHistoryMessage> messages;
  final String? viewportAnchorMessageId;
  final GlobalKey? viewportAnchorKey;
  final AgentImageContentLoader? loadImageThumbnail;
  final AgentImageContentLoader? loadImageContent;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.isEmpty ? 0 : messages.length * 2 - 1;
    final messageKeys = <Key>[
      for (final message in messages)
        if (viewportAnchorKey != null &&
            _messageIdentity(message) == viewportAnchorMessageId)
          viewportAnchorKey!
        else
          ValueKey<String>(
            'agent-history-message:${_messageIdentity(message)}',
          ),
    ];
    return SliverList(
      key: const ValueKey('agent-history-panel'),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index.isOdd) return const SizedBox(height: 18);
          final messageIndex = index ~/ 2;
          return KeyedSubtree(
            key: messageKeys[messageIndex],
            child: _AgentHistoryBubble(
              key: ValueKey('agent-history-$messageIndex'),
              message: messages[messageIndex],
              loadImageThumbnail: loadImageThumbnail,
              loadImageContent: loadImageContent,
            ),
          );
        },
        childCount: itemCount,
        findChildIndexCallback: (key) {
          final index = messageKeys.indexOf(key);
          return index < 0 ? null : index * 2;
        },
      ),
    );
  }
}

class _AgentHistoryBubble extends StatelessWidget {
  const _AgentHistoryBubble({
    super.key,
    required this.message,
    this.loadImageThumbnail,
    this.loadImageContent,
  });

  final AgentHubHistoryMessage message;

  final AgentImageContentLoader? loadImageThumbnail;
  final AgentImageContentLoader? loadImageContent;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentHubHistoryRole.user;
    final textStyle = MomHomeTokens.text(
      16,
      height: 1.65,
      color: isUser ? Colors.white : MomHomeTokens.ink,
    );

    if (!isUser) {
      final runState = message.runState;
      if (runState != null) {
        return AgentRunTranscript(state: runState);
      }

      return _AgentAssistantTurn(
        avatar: const _AgentAssistantAvatar(),
        child: _AgentAssistantBubble(
          child: AgentMarkdownText(
            assistantDisplayText(message.content),
            style: textStyle,
          ),
        ),
      );
    }

    final hasAttachments =
        message.images.isNotEmpty || message.files.isNotEmpty;
    final attachments = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (message.images.isNotEmpty)
          AgentSentImages(
            images: message.images,
            loadImageThumbnail: loadImageThumbnail,
            loadImageContent: loadImageContent,
          ),
        if (message.images.isNotEmpty && message.files.isNotEmpty)
          const SizedBox(height: 8),
        if (message.files.isNotEmpty) AgentSentFiles(files: message.files),
      ],
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: hasAttachments && message.content.isEmpty
                ? 244
                : math.min(
                    340,
                    MediaQuery.sizeOf(context).width -
                        (MediaQuery.textScalerOf(context).scale(16) > 21
                            ? 32
                            : 78),
                  ),
          ),
          child: hasAttachments && message.content.isEmpty
              ? attachments
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: MomHomeTokens.rose,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (hasAttachments) attachments,
                        if (hasAttachments && message.content.isNotEmpty)
                          const SizedBox(height: 8),
                        if (message.content.isNotEmpty)
                          Text(message.content, style: textStyle),
                      ],
                    ),
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _phaseLabel {
    return switch (phase) {
      AgentStreamRunPhase.idle => 'Ready',
      AgentStreamRunPhase.streaming => 'Responding',
      AgentStreamRunPhase.waitingForConfirmation => 'Awaiting confirmation',
      AgentStreamRunPhase.finished => 'Completed',
      AgentStreamRunPhase.error => 'Try again',
      AgentStreamRunPhase.disconnected => 'Connection lost',
      AgentStreamRunPhase.cancelRequested => 'Stopping',
      AgentStreamRunPhase.cancelled => 'Stopped',
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
    required this.greeting,
    required this.stateListenable,
    required this.onTextRevealed,
    required this.canRetryForState,
    this.onRetry,
    this.onQuickReplySelected,
  });

  final String greeting;
  final VoidCallback onTextRevealed;
  final ValueListenable<AgentStreamRunState> stateListenable;

  final bool Function(AgentStreamRunState state) canRetryForState;
  final VoidCallback? onRetry;

  final ValueChanged<String>? onQuickReplySelected;

  @override
  State<_AgentRunTranscriptListenable> createState() =>
      _AgentRunTranscriptListenableState();
}

class _AgentRunTranscriptListenableState
    extends State<_AgentRunTranscriptListenable> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.stateListenable,
      builder: (context, child) {
        final state = widget.stateListenable.value;

        return AgentTextReveal(
          text: state.textContent,
          streaming: state.phase == AgentStreamRunPhase.streaming,
          completed:
              state.phase == AgentStreamRunPhase.finished ||
              (state.phase == AgentStreamRunPhase.streaming &&
                  state.hasCompletedAssistantMessage),
          replyId: state.runId,
          onReveal: widget.onTextRevealed,
          builder: (context, visibleText) => AgentRunTranscript(
            visibleText: visibleText,
            state: state,
            greeting: widget.greeting,
            canRetry: widget.canRetryForState(state),
            onRetry: widget.onRetry,
            onQuickReplySelected: widget.onQuickReplySelected,
          ),
        );
      },
    );
  }
}

class AgentRunTranscript extends StatelessWidget {
  const AgentRunTranscript({
    super.key,
    required this.state,
    this.greeting = agentHubDefaultGreeting,
    this.visibleText,
    this.canRetry = false,
    this.onRetry,
    this.onQuickReplySelected,
  });

  final AgentStreamRunState state;
  final String greeting;
  final String? visibleText;

  final bool canRetry;
  final VoidCallback? onRetry;

  final ValueChanged<String>? onQuickReplySelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = assistantDisplayText(
      state.textContent.isNotEmpty
          ? (visibleText ?? _primaryText)
          : _primaryText,
    );
    final allowsSupplementaryContent =
        state.phase != AgentStreamRunPhase.error &&
        state.phase != AgentStreamRunPhase.cancelled;
    final quickReplies = state.quickReplies;
    final shouldRenderQuickReplies =
        allowsSupplementaryContent &&
        quickReplies.length == 3 &&
        !quickReplies.any(containsUnsupportedAssistantText) &&
        !state.isAwaitingVisibleReply &&
        onQuickReplySelected != null;
    final avatarMode = _avatarMode;
    final loopDecor = _loopDecorState;
    final thinkingNoteTitle = loopDecor.thinkingTitle;
    final statusLineTitle = loopDecor.statusTitle;
    final shouldRenderPrimaryText = _shouldRenderPrimaryText;
    final isFailure =
        state.phase == AgentStreamRunPhase.error ||
        state.phase == AgentStreamRunPhase.disconnected;
    final showFailureFallback = isFailure && state.textContent.trim().isEmpty;
    final primaryTextStyle = MomHomeTokens.text(16, height: 1.65);
    final isGreeting =
        state.phase == AgentStreamRunPhase.idle &&
        state.textContent.trim().isEmpty;

    return _AgentAssistantTurn(
      key: const ValueKey('agent-run-transcript'),
      avatar: _AgentAssistantAvatar(mode: avatarMode),
      fullWidth: isGreeting,
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
          if (showFailureFallback)
            Semantics(
              liveRegion: true,
              child: const Text(
                'No response this time.',
                key: ValueKey('agent-run-failure-fallback'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: MomCozyColors.danger,
                ),
              ),
            )
          else if (shouldRenderPrimaryText)
            Align(
              alignment: Alignment.centerLeft,
              child: isGreeting
                  ? _AgentWelcomeCard(
                      text: text,
                      avatar: _AgentAssistantAvatar(mode: avatarMode),
                    )
                  : _AgentAssistantBubble(
                      child: AgentMarkdownText(text, style: primaryTextStyle),
                    ),
            ),
          if (_supportingText != null) ...[
            const SizedBox(height: 9),
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
                      fontSize: 12,
                      height: 1.4,
                      color: _supportingColor(colorScheme),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (allowsSupplementaryContent && canRetry) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('agent-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: MomHomeTokens.surface,
                foregroundColor: MomHomeTokens.rose,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontFamily: MomCozyTypography.fontFamily,
                  fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
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
    );
  }

  String get _primaryText {
    return _agentAssistantTextForState(state, greeting: greeting);
  }

  bool get _shouldRenderPrimaryText {
    if (state.phase == AgentStreamRunPhase.streaming &&
        state.textContent.trim().isEmpty) {
      return false;
    }
    return true;
  }

  _AgentLoopDecorState get _loopDecorState {
    final supportsLoopDecor =
        state.phase == AgentStreamRunPhase.streaming ||
        state.phase == AgentStreamRunPhase.waitingForConfirmation ||
        state.phase == AgentStreamRunPhase.error;
    if (!supportsLoopDecor || state.hasCompletedAssistantMessage) {
      return const _AgentLoopDecorState();
    }
    if (state.phase == AgentStreamRunPhase.streaming &&
        state.textContent.trim().isNotEmpty) {
      return const _AgentLoopDecorState(
        statusTitle: 'Putting together a response…',
      );
    }
    if (state.textContent.trim().isNotEmpty) {
      return const _AgentLoopDecorState();
    }
    return _agentLoopDecorStateFromEvents(state.events);
  }

  String? get _supportingText {
    if (state.phase == AgentStreamRunPhase.waitingForConfirmation) {
      return _unsupportedActionMessage;
    }
    if (state.phase == AgentStreamRunPhase.disconnected) {
      return _safeAgentErrorText(
            state.errorMessage,
            fallback: 'Connection interrupted. You can try again.',
          ) ??
          'Connection interrupted. You can try again.';
    }
    if (state.phase == AgentStreamRunPhase.error) {
      return _safeAgentErrorText(
            state.errorMessage,
            fallback: 'Could not complete the request. Please try again later.',
          ) ??
          'Could not complete the request. Please try again later.';
    }
    if (state.phase == AgentStreamRunPhase.cancelRequested) {
      return 'Requesting server cancellation';
    }
    if (state.phase == AgentStreamRunPhase.cancelled) {
      return state.cancelAcknowledged
          ? 'Response stopped'
          : 'Stopped on this device. Server cancellation not confirmed';
    }
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
      color: MomCozyColors.mutedForeground,
      fontWeight: FontWeight.w600,
      height: 1,
    );
    final replyStyle = textTheme.bodySmall?.copyWith(
      color: MomCozyColors.foreground,
      fontSize: MomCozyTypography.secondarySize,
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
                  color: MomCozyColors.border,
                  borderRadius: BorderRadius.circular(MomCozyRadii.pill),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'You might ask',
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
        splashColor: MomCozyColors.roseSoft,
        highlightColor: MomCozyColors.roseSoft.withValues(alpha: 0.58),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34, maxWidth: 260),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: MomCozyColors.card,
              borderRadius: BorderRadius.circular(MomCozyRadii.pill),
              border: Border.all(color: MomCozyColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(text, softWrap: true, style: textStyle)),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  key: ValueKey('agent-quick-reply-chevron'),
                  size: 16,
                  color: MomCozyColors.primary,
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
    this.parseMarkdown = true,
  });

  final String text;
  final TextStyle? style;

  final bool parseMarkdown;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trim();
    final baseStyle = style ?? MomHomeTokens.text(16, height: 1.65);
    if (!parseMarkdown) {
      return Text(normalized, style: baseStyle);
    }
    final markdown = normalized;
    final markdownBody = markdown.trim().isEmpty
        ? null
        : !_containsMarkdown(markdown) && !markdown.contains('\n\n')
        ? Text(markdown, style: baseStyle)
        : MarkdownBody(
            data: markdown,
            fitContent: true,
            shrinkWrap: true,
            softLineBreak: true,
            styleSheet: _momcozyMarkdownStyleSheet(context, baseStyle),
            imageBuilder: (uri, title, alt) => Text(
              alt?.trim().isNotEmpty == true ? alt!.trim() : 'Image',
              style: baseStyle,
            ),
          );

    return markdownBody ?? Text('', style: baseStyle);
  }

  MarkdownStyleSheet _momcozyMarkdownStyleSheet(
    BuildContext context,
    TextStyle? baseStyle,
  ) {
    final theme = Theme.of(context);
    final paragraphStyle = theme.textTheme.bodyMedium?.merge(baseStyle);
    final mutedStyle = paragraphStyle?.copyWith(
      color: MomCozyColors.mutedForeground,
    );
    final headingBase = paragraphStyle?.copyWith(
      fontFamily: 'NotoSansSCHome',
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w700,
    );
    final codeStyle = paragraphStyle?.copyWith(
      color: MomCozyColors.foreground,
      backgroundColor: MomCozyColors.muted.withValues(alpha: 0.52),
      fontFamily: 'monospace',
      fontSize: MomCozyTypography.secondarySize,
      height: 1.36,
    );

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: paragraphStyle,
      pPadding: EdgeInsets.zero,
      a: paragraphStyle?.copyWith(
        color: MomHomeTokens.teal,
        decoration: TextDecoration.underline,
        decorationColor: MomHomeTokens.teal,
      ),
      strong: paragraphStyle?.copyWith(
        fontFamily: 'NotoSansSCHome',
        fontWeight: FontWeight.w700,
      ),
      em: paragraphStyle?.copyWith(fontStyle: FontStyle.italic),
      del: mutedStyle?.copyWith(decoration: TextDecoration.lineThrough),
      h1: headingBase,
      h2: headingBase,
      h3: headingBase,
      h4: headingBase?.copyWith(fontSize: MomCozyTypography.bodySize),
      h5: headingBase,
      h6: headingBase,
      h1Padding: EdgeInsets.zero,
      h2Padding: EdgeInsets.zero,
      h3Padding: EdgeInsets.zero,
      h4Padding: const EdgeInsets.only(bottom: 4),
      h5Padding: const EdgeInsets.only(bottom: 4),
      h6Padding: const EdgeInsets.only(bottom: 4),
      code: codeStyle,
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: MomCozyColors.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(MomCozyRadii.thumbnail),
        border: Border.all(color: MomCozyColors.border),
      ),
      blockSpacing: 16,
      listIndent: 20,
      listBullet: paragraphStyle,
      listBulletPadding: const EdgeInsets.only(right: 6),
      blockquote: mutedStyle,
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      blockquoteDecoration: BoxDecoration(
        color: MomCozyColors.secondary.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(MomCozyRadii.thumbnail),
        border: const Border(
          left: BorderSide(color: MomCozyColors.primary, width: 3),
        ),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: MomCozyColors.border, width: 1)),
      ),
      tableHead: paragraphStyle?.copyWith(
        color: MomCozyColors.foreground,
        fontWeight: FontWeight.w700,
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

class AgentRunStatusLine extends StatefulWidget {
  const AgentRunStatusLine({super.key, required this.title});

  final String title;

  @override
  State<AgentRunStatusLine> createState() => _AgentRunStatusLineState();
}

class _AgentRunStatusLineState extends State<AgentRunStatusLine>
    with SingleTickerProviderStateMixin {
  static const _sweepDuration = Duration(milliseconds: 640);

  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _sweepDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAgentDecoration(context, _sweepController);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final title = widget.title;

    return Semantics(
      label: title,
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('agent-run-status-line'),
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).width < 360 ? 36 : 40,
          maxWidth: double.infinity,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _AgentSweepText(
          title,
          sweepKey: const ValueKey('agent-run-status-title-sweep'),
          animation: _sweepController,
          colors: const [
            MomCozyColors.violet,
            MomCozyColors.primaryDark,
            MomCozyColors.violet,
          ],
          style: textTheme.labelSmall?.copyWith(
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
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
      child: Text(text, style: style),
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
  static const _sweepDuration = Duration(milliseconds: 640);

  late final AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: _sweepDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAgentDecoration(context, _sweepController);
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
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.zero,
        child: _AgentSweepText(
          widget.title,
          sweepKey: const ValueKey('agent-thinking-note'),
          animation: _sweepController,
          colors: const [
            MomCozyColors.mutedForeground,
            MomCozyColors.foreground,
            MomCozyColors.mutedForeground,
          ],
          style: textTheme.labelSmall?.copyWith(
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _AgentAssistantAvatarMode { thinking }

class _AgentAssistantAvatar extends StatefulWidget {
  const _AgentAssistantAvatar({this.mode});

  final _AgentAssistantAvatarMode? mode;

  @override
  State<_AgentAssistantAvatar> createState() => _AgentAssistantAvatarState();
}

class _AgentAssistantAvatarState extends State<_AgentAssistantAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final Map<_AgentAssistantAvatarMode, VideoPlayerController>
  _videoControllers = <_AgentAssistantAvatarMode, VideoPlayerController>{};
  final Set<_AgentAssistantAvatarMode> _videoReadyModes =
      <_AgentAssistantAvatarMode>{};
  _AgentAssistantAvatarMode? _playingVideoMode;

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
    _syncVideoPlayback();
  }

  @override
  void didUpdateWidget(covariant _AgentAssistantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _syncPulseController();
      _syncVideoPlayback();
    }
  }

  @override
  void dispose() {
    _disposeVideoControllers();
    _pulseController.dispose();
    super.dispose();
  }

  void _syncPulseController() {
    if (_activeAnimationMode() == null) {
      _pulseController.stop();
      _pulseController.value = 0;
      return;
    }
    if (!_pulseController.isAnimating) _pulseController.repeat();
  }

  void _syncVideoPlayback() {
    final activeMode = _activeAnimationMode();
    final previousMode = _playingVideoMode;
    if (previousMode != null && previousMode != activeMode) {
      final previousController = _videoControllers[previousMode];
      if (previousController != null &&
          _videoReadyModes.contains(previousMode)) {
        unawaited(_runVideoCommand(previousController.pause));
      }
      _playingVideoMode = null;
    }

    if (activeMode == null) return;
    final controller = _ensureVideoController(activeMode);
    if (!_videoReadyModes.contains(activeMode) ||
        _playingVideoMode == activeMode) {
      return;
    }
    _playingVideoMode = activeMode;
    unawaited(_runVideoCommand(controller.play));
  }

  VideoPlayerController _ensureVideoController(_AgentAssistantAvatarMode mode) {
    final existing = _videoControllers[mode];
    if (existing != null) return existing;

    final controller = VideoPlayerController.asset(_videoAssetForMode(mode));
    _videoControllers[mode] = controller;
    unawaited(_initializeVideoController(mode, controller));
    return controller;
  }

  Future<void> _initializeVideoController(
    _AgentAssistantAvatarMode mode,
    VideoPlayerController controller,
  ) async {
    try {
      await controller.initialize();
      if (!mounted || _videoControllers[mode] != controller) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted || _videoControllers[mode] != controller) return;
      _videoReadyModes.add(mode);
      _syncVideoPlayback();
      setState(() {});
    } catch (_) {
      if (!mounted || _videoControllers[mode] != controller) return;
      _videoControllers.remove(mode);
      _videoReadyModes.remove(mode);
      if (_playingVideoMode == mode) _playingVideoMode = null;
      unawaited(_runVideoCommand(controller.dispose));
      setState(() {});
    }
  }

  Future<void> _runVideoCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (_) {
      // The static avatar remains visible when the platform player rejects.
    }
  }

  void _disposeVideoControllers() {
    final controllers = _videoControllers.values.toList(growable: false);
    _videoControllers.clear();
    _videoReadyModes.clear();
    _playingVideoMode = null;
    for (final controller in controllers) {
      unawaited(_runVideoCommand(controller.dispose));
    }
  }

  _AgentAssistantAvatarMode? _activeAnimationMode() {
    if (!_shouldAnimateAvatar()) return null;
    return widget.mode;
  }

  String _videoAssetForMode(_AgentAssistantAvatarMode mode) {
    return switch (mode) {
      _AgentAssistantAvatarMode.thinking => MomCozyAssets.agentThinkingAvatar,
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
    final isThinkingMode = mode == _AgentAssistantAvatarMode.thinking;
    final isActiveMode = isThinkingMode;
    final showThinkingVideo = shouldAnimate && isThinkingMode;
    const ringColor = MomCozyColors.care;
    final activeAvatarKey = showThinkingVideo
        ? 'agent-assistant-avatar-thinking-media'
        : null;
    final videoController = mode == null ? null : _videoControllers[mode];
    final videoReady = mode != null && _videoReadyModes.contains(mode);

    return SizedBox.square(
      key: const ValueKey('agent-assistant-avatar'),
      dimension: MediaQuery.sizeOf(context).width < 360 ? 36 : 40,
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
                    scale: 1 + pulse * (0.08),
                    child: DecoratedBox(
                      key: ValueKey('agent-assistant-avatar-thinking'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor.withValues(
                            alpha: 0.42 + pulse * 0.18,
                          ),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(
                              alpha: 0.12 + pulse * 0.12,
                            ),
                            blurRadius: 9 + pulse * 6,
                            spreadRadius: 0.8 + pulse,
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
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0xffdfcbed), spreadRadius: 1),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    Image.asset(
                      MomCozyAssets.agentAvatar,
                      key: const ValueKey('agent-assistant-avatar-static'),
                      width: MediaQuery.sizeOf(context).width < 360 ? 32 : 36,
                      height: MediaQuery.sizeOf(context).width < 360 ? 32 : 36,
                      fit: BoxFit.cover,
                    ),
                    if (videoReady &&
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
          ),
        ],
      ),
    );
  }
}

class AgentComposerBar extends StatefulWidget {
  const AgentComposerBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.canSend,
    required this.isRunning,
    required this.isInputLocked,
    required this.images,
    required this.files,
    required this.canAttachImage,
    required this.canAttachFile,
    required this.isAttachmentPending,
    this.attachmentUploadProgress,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    required this.onTakePhoto,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onRemoveImage,
    required this.onRemoveFile,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool canSend;
  final bool isRunning;
  final bool isInputLocked;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;
  final bool canAttachImage;
  final bool canAttachFile;
  final bool isAttachmentPending;
  final double? attachmentUploadProgress;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveFile;

  @override
  State<AgentComposerBar> createState() => _AgentComposerBarState();
}

class _AgentComposerBarState extends State<AgentComposerBar> {
  static const double _controlSize = 44;
  static const double _attachmentControlSize = 44;
  static const double _surfaceMinHeight = 56;
  static const double _surfaceHorizontalInset = 5;
  static const double _surfaceVerticalInset = 5;
  static const double _controlGap = 6;
  static const double _inputLeftInset =
      _surfaceHorizontalInset + _attachmentControlSize + _controlGap;
  static const double _expandedInputHorizontalInset = 20;
  static const double _expandedInputTopInset = 14;
  static const double _expandedInputBottomInset =
      _surfaceVerticalInset + _controlSize + 18;
  static const double _lineWrapGuard = 10;
  final MenuController _attachmentMenuController = MenuController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant AgentComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
    if (!widget.canAttachImage &&
        !widget.canAttachFile &&
        _attachmentMenuController.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _attachmentMenuController.close();
      });
    }
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

  Widget _attachmentMenuItem({
    required Key key,
    required String label,
    required String description,
    required String iconAsset,
    required VoidCallback? onPressed,
  }) {
    return MenuItemButton(
      key: key,
      onPressed: onPressed == null
          ? null
          : () {
              _attachmentMenuController.close();
              onPressed();
            },
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(0, 48),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF5E7ED),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: iconAsset.endsWith('.png')
                    ? Image.asset(
                        iconAsset,
                        width: 18,
                        height: 18,
                        color: onPressed == null ? MomHomeTokens.muted : null,
                      )
                    : SvgPicture.asset(
                        iconAsset,
                        width: 18,
                        height: 18,
                        colorFilter: onPressed == null
                            ? const ColorFilter.mode(
                                MomHomeTokens.muted,
                                BlendMode.srcIn,
                              )
                            : null,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: MomHomeTokens.text(
                    14,
                    height: 18 / 14,
                    weight: FontWeight.w700,
                    color: onPressed == null
                        ? MomHomeTokens.muted
                        : MomHomeTokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: MomHomeTokens.text(
                    11,
                    height: 14 / 11,
                    color: MomHomeTokens.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isRunning = widget.isRunning;
    final isInputLocked = widget.isInputLocked;
    final images = widget.images;
    final imageCount = images.length;
    final files = widget.files;
    final fileCount = files.length;
    final canSend =
        widget.canSend &&
        (controller.text.trim().isNotEmpty || imageCount > 0 || fileCount > 0);
    final canAttachImage = widget.canAttachImage;
    final canAttachFile = widget.canAttachFile;
    final onChanged = widget.onChanged;
    final onSend = widget.onSend;
    final onCancel = widget.onCancel;
    final sendIsStop = isRunning && !canSend;
    final sendLooksActive = canSend || sendIsStop;
    const inputTextStyle = TextStyle(
      fontFamily: 'NotoSansSCHome',
      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
      fontSize: 16,
      height: 1.6,
    );

    return Padding(
      key: const ValueKey('agent-composer-bar'),
      // Figma's composer ends 20px above the 82px navigation chrome. The
      // route shell reserves the raised navigation hit area separately, so
      // only a 2px local inset belongs here.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageCount + fileCount > 0) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final width = largeText
                      ? math.min(320.0, constraints.maxWidth * .92)
                      : 64.0;
                  return SingleChildScrollView(
                    key: const ValueKey('agent-pending-attachments'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageCount > 0)
                          Row(
                            key: const ValueKey('agent-image-attachment-chip'),
                            children: [
                              for (var index = 0; index < imageCount; index++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: width,
                                    child: AgentComposerImageAttachment(
                                      key: ValueKey(
                                        'agent-image-attachment-$index',
                                      ),
                                      image: images[index],
                                      removeButtonKey: ValueKey(
                                        index == 0
                                            ? 'agent-remove-image-button'
                                            : 'agent-remove-image-$index',
                                      ),
                                      onRemove: isInputLocked
                                          ? null
                                          : () => widget.onRemoveImage(index),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (fileCount > 0)
                          Row(
                            key: const ValueKey('agent-file-attachment-chip'),
                            children: [
                              for (var index = 0; index < fileCount; index++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: index == fileCount - 1 ? 0 : 8,
                                  ),
                                  child: SizedBox(
                                    width: width,
                                    child: AgentComposerFileAttachment(
                                      key: ValueKey(
                                        'agent-file-attachment-$index',
                                      ),
                                      file: files[index],
                                      removeButtonKey: ValueKey(
                                        index == 0
                                            ? 'agent-remove-file-button'
                                            : 'agent-remove-file-$index',
                                      ),
                                      onRemove: isInputLocked
                                          ? null
                                          : () => widget.onRemoveFile(index),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 7),
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
                    : EdgeInsets.fromLTRB(
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
                  onTap: _attachmentMenuController.close,
                  controller: controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  enabled: !isInputLocked,
                  style: inputTextStyle,
                  onChanged: onChanged,
                  scrollPadding: const EdgeInsets.only(bottom: 96),
                  decoration: InputDecoration(
                    hintText: 'Ask Momcozy AI anything...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      fontFamily: 'NotoSansSCHome',
                      fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
                      fontSize: 16,
                      height: 1.6,
                      color: MomHomeTokens.secondary,
                    ),
                  ),
                );
                final inputFrame = Padding(
                  key: const ValueKey('agent-composer-input-frame'),
                  padding: inputPadding,
                  child: composerInput,
                );

                return MenuAnchor(
                  controller: _attachmentMenuController,
                  consumeOutsideTap: true,
                  alignmentOffset: const Offset(0, 8),
                  style: MenuStyle(
                    backgroundColor: const WidgetStatePropertyAll(
                      MomHomeTokens.surface,
                    ),
                    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: Color(0xFFE9DFE4)),
                      ),
                    ),
                    elevation: const WidgetStatePropertyAll(0),
                    shadowColor: WidgetStatePropertyAll(
                      MomHomeTokens.ink.withValues(alpha: 0.12),
                    ),
                  ),
                  menuChildren: [
                    SizedBox(
                      key: const ValueKey('agent-attachment-menu'),
                      width:
                          math.min(
                            MediaQuery.sizeOf(context).width - 32,
                            220 *
                                (MediaQuery.textScalerOf(context).scale(15) /
                                        15)
                                    .clamp(1, 1.2),
                          ) -
                          12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _attachmentMenuItem(
                            key: const ValueKey(
                              'agent-attachment-camera-button',
                            ),
                            label: 'Camera',
                            description: 'Take a photo',
                            iconAsset:
                                'assets/images/cozymate_attachment_camera.png',
                            onPressed: canAttachImage
                                ? widget.onTakePhoto
                                : null,
                          ),
                          _attachmentMenuItem(
                            key: const ValueKey(
                              'agent-attachment-photo-button',
                            ),
                            label: 'Photos',
                            description: 'JPG, PNG, WebP',
                            iconAsset:
                                'assets/images/cozymate_attachment_photo.svg',
                            onPressed: canAttachImage
                                ? widget.onPickPhoto
                                : null,
                          ),
                          _attachmentMenuItem(
                            key: const ValueKey('agent-attachment-file-button'),
                            label: 'Files',
                            description: 'PDF · Up to 10 MB',
                            iconAsset:
                                'assets/images/cozymate_attachment_file.svg',
                            onPressed: canAttachFile ? widget.onPickFile : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: DecoratedBox(
                    key: const ValueKey('agent-composer-surface'),
                    decoration: BoxDecoration(
                      color: MomHomeTokens.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: MomHomeTokens.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x052B2826),
                          blurRadius: 24,
                          offset: Offset(0, 5),
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
                            child: Builder(
                              builder: (context) {
                                final menuController =
                                    _attachmentMenuController;
                                final canOpenMenu =
                                    canAttachImage || canAttachFile;
                                return IconButton(
                                  key: const ValueKey(
                                    'agent-attachment-button',
                                  ),
                                  onPressed:
                                      canOpenMenu && !widget.isAttachmentPending
                                      ? () {
                                          if (menuController.isOpen) {
                                            menuController.close();
                                          } else {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            menuController.open();
                                          }
                                        }
                                      : null,
                                  icon: widget.isAttachmentPending
                                      ? SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            value:
                                                widget.attachmentUploadProgress,
                                          ),
                                        )
                                      : const Icon(Icons.add_rounded, size: 28),
                                  tooltip: 'Add attachment',
                                  color: MomHomeTokens.secondary,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints.tightFor(
                                    width: _attachmentControlSize,
                                    height: _attachmentControlSize,
                                  ),
                                  padding: EdgeInsets.zero,
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size.square(
                                      _attachmentControlSize,
                                    ),
                                    minimumSize: const Size.square(
                                      _attachmentControlSize,
                                    ),
                                    maximumSize: const Size.square(
                                      _attachmentControlSize,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                );
                              },
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
                                      ? MomHomeTokens.rose
                                      : MomHomeTokens.neutralSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox.square(
                                  dimension: _controlSize,
                                  child: Center(
                                    child: Icon(
                                      sendIsStop
                                          ? Icons.stop_rounded
                                          : Icons.arrow_upward_rounded,
                                      size: sendIsStop ? 18 : 16,
                                      color: sendLooksActive
                                          ? colorScheme.onPrimary
                                          : MomCozyColors.mutedForeground,
                                    ),
                                  ),
                                ),
                              ),
                              tooltip: sendIsStop ? 'Stop' : 'Send',
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
                  ),
                );
              },
            ),
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

  static const double _inputRightInset =
      _surfaceHorizontalInset + _controlSize + _controlGap;

  int _visualLineCountForWidth(
    BuildContext context,
    double maxWidth,
    TextStyle style,
  ) {
    final text = widget.controller.text.isEmpty
        ? 'Ask Momcozy AI anything...'
        : widget.controller.text;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 100,
    )..layout(maxWidth: maxWidth.clamp(1.0, double.infinity));
    return painter.computeLineMetrics().length.clamp(1, 100);
  }
}

bool _hasServerRunSignal(AgentStreamRunState state) {
  return state.runId?.trim().isNotEmpty == true ||
      state.lastSequence != null ||
      state.events.isNotEmpty ||
      state.textContent.isNotEmpty ||
      state.provisionalTextContent.isNotEmpty;
}

String? _stringField(Map<String, Object?> map, String key, [String? alias]) {
  return stringField(map, key) ??
      (alias == null ? null : stringField(map, alias));
}

String? _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;
  }
  return null;
}

String? _safeAgentErrorText(String? errorMessage, {String? fallback}) {
  final normalized = errorMessage?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized == _unsupportedActionMessage) return normalized;
  final lower = normalized.toLowerCase();
  if (lower.contains('timeoutexception') || lower.contains('timeout')) {
    return 'Request timed out. Try again later.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('offline')) {
    return 'No network connection. Check your connection and try again.';
  }
  return fallback ?? normalized;
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
  final projection = projectAgentWorkStatus(events);
  if (projection.isTerminal) return null;
  final projectedEvent = projection.statusEvent;
  if (projectedEvent != null) {
    final projectedTitle = _semanticStatusTitle(projectedEvent);
    if (projectedTitle != null) return projectedTitle;
  }

  for (final event in events.reversed) {
    if (event.semantic.isNotEmpty) continue;
    if (_eventStopsAgentLoopDecor(event)) return null;

    switch (event.type) {
      case 'run.queued':
      case 'run.started':
        return 'I have your message.';
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
  return 'I have your message.';
}

String? _activeAgentThinkingTitle(List<AgentStreamEvent> events) {
  for (final event in events.reversed) {
    if (event.semantic.isNotEmpty) {
      final semanticThinkingTitle = _semanticThinkingTitle(event);
      if (semanticThinkingTitle != null) return semanticThinkingTitle;
      if (_semanticClearsAgentThinking(event) ||
          _eventStopsAgentLoopDecor(event)) {
        return null;
      }
      continue;
    }

    if (event.type == 'run.progress') {
      final phase = _stringField(event.payload, 'phase')?.trim();
      if (phase == 'model_reasoning') {
        return _visibleAgentStatusTitle(
              _firstNonEmpty([
                _stringField(event.payload, 'label'),
                _stringField(event.payload, 'message'),
              ]),
            ) ??
            'Let me think…';
      }
      if (phase == 'model_reasoning_after_tool') {
        return _visibleAgentStatusTitle(
              _firstNonEmpty([
                _stringField(event.payload, 'label'),
                _stringField(event.payload, 'message'),
              ]),
            ) ??
            'Let me think…';
      }
      if (_runProgressClearsAgentThinking(event, phase)) return null;
    }

    if (_eventStopsAgentLoopDecor(event)) return null;
  }
  return null;
}

bool _eventStopsAgentLoopDecor(AgentStreamEvent event) {
  return (event.type == 'message.completed' && event.role != 'user') ||
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
  if (surface == 'thinking_note') return false;
  if (_semanticTargetsAgentStatus(semantic)) {
    return _semanticDisplayTitle(semantic) != null;
  }
  final lifecycle = _stringField(semantic, 'lifecycle')?.trim();
  return lifecycle == 'completed' || lifecycle == 'failed';
}

String? _semanticStatusTitle(AgentStreamEvent event) {
  final semantic = event.semantic;
  if (semantic.isEmpty) return null;
  if (event.semanticLifecycle == 'failed') return null;
  final surface = _stringField(semantic, 'surface')?.trim();
  if (surface == 'thinking_note' || surface == 'hidden') return null;
  if (_semanticTargetsAgentStatus(semantic)) {
    return _semanticDisplayTitle(semantic);
  }
  return null;
}

bool _semanticTargetsAgentStatus(Map<String, Object?> semantic) {
  const visibleTargets = {'status_bar', 'work_item', 'artifact', 'action'};
  final surface = _stringField(semantic, 'surface')?.trim();
  if (surface == 'thinking_note' || surface == 'hidden') return false;
  return visibleTargets.contains(surface);
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
    'context_loading' => 'I have your message.',
    'context_ready' => 'Let me understand what you need…',
    'model_followup' => 'Working on the next step…',
    'response_finalizing' => 'Putting together a response…',
    'quick_replies_preparing' => 'Preparing follow-up suggestions…',
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
    'Momcozy AI is joining the conversation' => 'I have your message.',
    '正在整理对话上下文' => 'I have your message.',
    '已整理好相关信息' => 'Let me understand what you need…',
    'Momcozy AI is thinking about how to help' => 'Let me think…',
    '正在整理回复' => 'Putting together a response…',
    _ => containsUnsupportedAssistantText(normalized) ? null : normalized,
  };
}

String _messageIdentity(AgentHubHistoryMessage message) =>
    message.id ??
    message.runState?.messageId ??
    (message.runState?.runId != null
        ? 'run:${message.runState!.runId}:assistant'
        : 'legacy:${identityHashCode(message)}');

List<AgentHubHistoryMessage> _mergeHistoryMessages(
  Iterable<AgentHubHistoryMessage> messages,
) {
  final byId = <String, AgentHubHistoryMessage>{};
  for (final message in messages) {
    byId[_messageIdentity(message)] = message;
  }
  final rows = byId.values.toList();
  final order = {
    for (var i = 0; i < rows.length; i++) _messageIdentity(rows[i]): i,
  };
  rows.sort((a, b) {
    if (a.id == 'local:welcome') return -1;
    if (b.id == 'local:welcome') return 1;
    if (a.sequence != null && b.sequence != null) {
      return a.sequence!.compareTo(b.sequence!);
    }
    if (a.createdAt != null && b.createdAt != null) {
      final result = a.createdAt!.compareTo(b.createdAt!);
      if (result != 0) return result;
    }
    return order[_messageIdentity(a)]!.compareTo(order[_messageIdentity(b)]!);
  });
  return rows;
}
