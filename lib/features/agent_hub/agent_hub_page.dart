import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_run_state.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/routing/safe_link_target.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_runtime.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_mapper.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/artifacts/forms/agent_artifact_form_dialog.dart';
import 'package:momcozy_flutter_app/features/agent_hub/citations/agent_citation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/ibclc_consult_store.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/support_ticket_api_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_document_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_conversation.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_media_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/birth_prep_profile_defaults.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/ibclc_consult.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_image_input.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_voice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_file_previews.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_image_previews.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/agent_conversation_panel.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/ibclc_consult_store_scope.dart';
import 'package:momcozy_flutter_app/features/media/data/product_asset_repository.dart';
import 'package:momcozy_flutter_app/features/media/domain/media_upload.dart';
import 'package:momcozy_flutter_app/features/media/domain/product_asset.dart';
import 'package:momcozy_flutter_app/features/media/presentation/product_asset_image.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/domain/pregnancy_plan_change_store.dart';
import 'package:momcozy_flutter_app/features/schedule/domain/milk_plan_change_store.dart';
import 'package:video_player/video_player.dart';

export 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_model.dart';
export 'package:momcozy_flutter_app/features/agent_hub/artifacts/agent_artifact_panel.dart';

typedef AgentHubRequestBuilder = AgentStreamRequest Function(String message);
typedef AgentArtifactActionHandler =
    void Function(AgentArtifactActionView action);
typedef AgentHubNewSessionHandler = FutureOr<void> Function();
typedef HospitalBagCartUpdateHandler =
    void Function(HospitalBagCartArtifactSeed seed);

const _agentDefaultGreetingPlaybackId = 'agent-default-greeting';
const _agentSkillAssetBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _agentActiveRunPersistentWriteInterval = Duration(milliseconds: 750);
const _completedReplyRunSettlementTimeout = Duration(seconds: 2);
const _completedReplyCancelTimeout = Duration(seconds: 2);
const _agentRunAttachmentLimit = 20;
const _supportTicketSubmittedReply =
    '已经帮你提交工单啦，我们的人工客服团队会在 24 小时内主动联系你，陪你一起跟进这个问题。很抱歉这次没能直接帮你解决，给你添麻烦了。接下来还请稍微耐心等待一下，我们会尽力协助你把问题处理好。';

String _agentAssistantTextForState(
  AgentStreamRunState state, {
  required String greeting,
}) {
  final text = state.textContent.trim();
  if (text.isNotEmpty) return text;

  return switch (state.phase) {
    AgentStreamRunPhase.idle => greeting,
    AgentStreamRunPhase.streaming => '我已经收到你的消息啦～',
    AgentStreamRunPhase.cancelRequested => '我正在停止这次回复。',
    AgentStreamRunPhase.cancelled => '已停止本次回复。',
    AgentStreamRunPhase.waitingForConfirmation => '需要你确认后继续。',
    AgentStreamRunPhase.finished => '我已经处理完成，但这次没有返回可见内容。',
    AgentStreamRunPhase.error => '这次处理没有成功，暂时没有生成回复。你可以重试一次。',
    AgentStreamRunPhase.disconnected => '这次没有拿到回复，可能是连接中断了。你再发一次就好。',
  };
}

String _formSubmitRequestMessage(AgentArtifactActionView action) {
  final extra = action.routeExtra;
  final extraMap = extra is Map ? Map<String, Object?>.from(extra) : const {};
  final formId = extraMap['formId']?.toString().trim();
  return [
    '我已提交信息采集表单，请基于确认后的表单数据继续完成对应服务。',
    if (formId != null && formId.isNotEmpty) 'form_id: $formId',
  ].join('\n');
}

({String artifactId, String? formId, Map<String, Object?> values})?
_formSubmissionFromAction(AgentArtifactActionView action) {
  final extra = action.routeExtra;
  if (extra is! Map) return null;
  final artifactId = extra['artifactId']?.toString().trim();
  final rawValues = extra['values'];
  if (artifactId == null || artifactId.isEmpty || rawValues is! Map) {
    return null;
  }
  final values = <String, Object?>{};
  for (final entry in rawValues.entries) {
    final key = entry.key;
    if (key is String && key.trim().isNotEmpty) values[key] = entry.value;
  }
  final rawFormId = extra['formId']?.toString().trim();
  return (
    artifactId: artifactId,
    formId: rawFormId == null || rawFormId.isEmpty ? null : rawFormId,
    values: Map<String, Object?>.unmodifiable(values),
  );
}

Map<String, Object?> _formSubmissionMetadata(AgentArtifactActionView action) {
  final submission = _formSubmissionFromAction(action);
  final formId = submission?.formId;
  if (submission == null || formId == null) return const {};
  return {
    'form_submission': {
      'artifact_id': submission.artifactId,
      'form_id': formId,
      'values': submission.values,
    },
  };
}

String _formSubmissionIdempotencyKey({
  required String artifactId,
  required String? formId,
  required String? threadId,
  required Map<String, Object?> values,
}) {
  final canonicalPayload = jsonEncode(
    _canonicalJsonValue({
      'artifact_id': artifactId,
      'form_id': formId ?? '',
      'thread_id': threadId?.trim() ?? '',
      'values': values,
    }),
  );
  return 'agent-form-submit-${sha256.convert(utf8.encode(canonicalPayload))}';
}

Object? _canonicalJsonValue(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .where((entry) => entry.key is String)
            .map((entry) => MapEntry(entry.key as String, entry.value))
            .toList(growable: false)
          ..sort((left, right) => left.key.compareTo(right.key));
    return {
      for (final entry in entries) entry.key: _canonicalJsonValue(entry.value),
    };
  }
  if (value is List) {
    return value.map(_canonicalJsonValue).toList(growable: false);
  }
  return value;
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
  List<AgentStreamFileInput> attachedFiles = const <AgentStreamFileInput>[];
  bool autoVoiceEnabled = true;
  AgentStreamRequest? activeRequest;
  Map<String, String> localActionStatuses = const <String, String>{};
  Map<String, AgentArtifactFormSubmission> formSubmissions =
      const <String, AgentArtifactFormSubmission>{};
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
    this.conversationRepository,
    this.interactionStateStore,
    this.greetingProfileLoader,
    this.requestBuilder = buildDefaultAgentHubRequest,
    this.pickImage,
    this.pickDocument,
    this.mediaRepository,
    this.loadImageContent,
    this.voiceInputController,
    this.voicePlaybackCoordinator,
    this.voicePlaybackPlayer,
    this.productAssetRepository,
    this.ibclcConsultStore,
    this.supportTicketSubmitter,
    this.onArtifactAction,
    this.onHospitalBagCartUpdate,
    this.onHospitalBagCartContextRequired,
    this.onPregnancyDiaryChange,
    this.onPregnancyPlanChange,
    this.onMilkPlanChange,
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
  final AgentConversationRepository? conversationRepository;
  final AgentHubInteractionStateStore? interactionStateStore;
  final AgentHubGreetingProfileLoader? greetingProfileLoader;
  final AgentHubRequestBuilder requestBuilder;
  final AgentHubImagePicker? pickImage;
  final AgentHubDocumentPicker? pickDocument;
  final MediaRepository? mediaRepository;
  final AgentImageContentLoader? loadImageContent;
  final AgentVoiceInputController? voiceInputController;
  final AgentVoicePlaybackCoordinator? voicePlaybackCoordinator;
  final AgentVoicePlaybackPlayer? voicePlaybackPlayer;
  final ProductAssetRepository? productAssetRepository;
  final IbclcConsultStore? ibclcConsultStore;
  final SupportTicketSubmitter? supportTicketSubmitter;
  final AgentArtifactActionHandler? onArtifactAction;
  final HospitalBagCartUpdateHandler? onHospitalBagCartUpdate;
  final VoidCallback? onHospitalBagCartContextRequired;
  final ValueChanged<PregnancyDiaryChange>? onPregnancyDiaryChange;
  final ValueChanged<PregnancyPlanChange>? onPregnancyPlanChange;
  final ValueChanged<MilkPlanChange>? onMilkPlanChange;
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
  final FocusNode _composerFocusNode = FocusNode();
  _AgentHubInteractionState? _interactionState;
  StreamSubscription<AgentStreamRunState>? _runSubscription;
  Completer<bool>? _runAcceptanceCompleter;
  Completer<void>? _runSettlementCompleter;
  Future<void>? _pendingServerCancel;
  bool _followUpStartPending = false;
  bool _newSessionStartPending = false;
  bool _supportTicketSubmitPending = false;
  bool _conversationSwitchPending = false;
  int _sessionOperationGeneration = 0;
  int? _conversationHistoryBeforeSequence;
  bool _olderConversationHistoryLoading = false;
  bool _olderConversationHistoryLoadArmed = false;
  Object? _olderConversationHistoryError;
  AgentStreamRequest? _activeRequest;
  AgentVoiceState _voiceState = const AgentVoiceState();
  Future<AgentVoiceInputPermissionState>? _voiceCaptureStart;
  int _voiceCaptureGeneration = 0;
  final List<AgentStreamImageInput> _attachedImages = <AgentStreamImageInput>[];
  final List<AgentStreamFileInput> _attachedFiles = <AgentStreamFileInput>[];
  final Set<String> _pendingActionIds = <String>{};
  final Map<String, String> _localActionStatuses = <String, String>{};
  final Set<String> _appliedHospitalBagCartUpdates = <String>{};
  final Set<String> _appliedPregnancyDiaryChangeEventIds = <String>{};
  final Set<String> _appliedPregnancyPlanChangeEventIds = <String>{};
  final Set<String> _appliedMilkPlanChangeEventIds = <String>{};
  bool _hospitalBagCartLinkContextApplied = false;
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _activeArtifactPanelKey = GlobalKey();
  final ValueNotifier<AgentStreamRunState> _runStateNotifier =
      ValueNotifier<AgentStreamRunState>(const AgentStreamRunState());
  final ValueNotifier<bool> _visibleReplyRunningNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _composerLockedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> _sessionMutationPendingNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _conversationSwitchEnabledNotifier =
      ValueNotifier<bool>(true);
  final ValueNotifier<_AgentResponseLightRailMode>
  _responseLightRailModeNotifier = ValueNotifier<_AgentResponseLightRailMode>(
    _AgentResponseLightRailMode.idle,
  );
  final ValueNotifier<String?> _activeVoicePlaybackIdNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<int> _actionStateRevisionNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, AgentArtifactFormSubmission>>
  _formSubmissionsNotifier =
      ValueNotifier<Map<String, AgentArtifactFormSubmission>>(
        const <String, AgentArtifactFormSubmission>{},
      );
  final AgentArtifactFormPresentationSession _formPresentationSession =
      AgentArtifactFormPresentationSession();
  bool _autoVoiceEnabled = true;
  bool _interactionRestoreResolved = false;
  bool _showLatestButton = false;
  bool _attachmentUploadPending = false;
  Timer? _persistentWriteTimer;
  Timer? _activeRunPersistentWriteTimer;
  AgentHubInteractionSnapshot? _pendingPersistentSnapshot;
  bool _scrollToLatestFrameScheduled = false;
  bool _scheduledScrollToLatestSmooth = false;
  int _scheduledScrollToLatestIntentVersion = 0;
  bool _artifactFocusFrameScheduled = false;
  bool _preserveArtifactFocus = false;
  int _scrollIntentVersion = 0;
  _PendingAutoVoiceReplay? _pendingAutoVoiceReplay;
  String? _activeAutoVoicePlaybackId;
  String _autoVoiceAppendedText = '';
  bool _autoVoiceHasSubmittedContent = false;
  AgentVoiceRealtimePlaybackSession? _autoVoiceSession;
  bool _autoVoiceSessionFinished = false;
  final Set<String> _autoVoiceSubmittedArtifactTexts = <String>{};
  final Set<String> _autoVoiceSubmittedMediaNarrations = <String>{};
  Object? _mediaVoiceEventIdentity;
  AgentMediaVoiceNarrationIndex _mediaVoiceNarrationIndex =
      AgentMediaVoiceNarrationIndex.fromEvents(const []);
  VoidCallback? _unsubscribeVoicePlaybackIdle;
  bool _consumedInitialAutoSend = false;
  bool _dismissComposerKeyboardOnRunAccepted = false;
  String _greeting = agentHubDefaultGreeting;
  AgentHubGreetingProfile? _profile;
  int _greetingRefreshGeneration = 0;
  int _lastHandledIbclcCompletionRevision = 0;

  @override
  void initState() {
    super.initState();
    _restoreCachedInteractionState();
    _seedExistingFormPresentations();
    _applyHospitalBagCartUpdates(_state);
    _applyPregnancyDiaryChanges(_state);
    _applyPregnancyPlanChanges(_state);
    _applyMilkPlanChanges(_state);
    _applyHospitalBagCartLinkContext(_state);
    _publishRunState(_state);
    _composerController.addListener(_persistInteractionState);
    _chatScrollController.addListener(_handleChatScroll);
    _syncVoicePlaybackIdleSubscription();
    _syncIbclcConsultStore(null, widget.ibclcConsultStore);
    _initializeInteractionState();
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
      if (_interactionRestoreResolved) {
        _applyInitialComposerText();
        _scheduleInitialAutoSendIfNeeded();
      }
    } else if (oldWidget.initialAutoSend != widget.initialAutoSend &&
        _interactionRestoreResolved) {
      _scheduleInitialAutoSendIfNeeded();
    }
    if (oldWidget.voicePlaybackCoordinator != widget.voicePlaybackCoordinator) {
      _syncVoicePlaybackIdleSubscription();
    }
    if (oldWidget.ibclcConsultStore != widget.ibclcConsultStore) {
      _syncIbclcConsultStore(
        oldWidget.ibclcConsultStore,
        widget.ibclcConsultStore,
      );
    }
    if (oldWidget.onPregnancyDiaryChange != widget.onPregnancyDiaryChange) {
      _applyPregnancyDiaryChanges(_state);
    }
    if (oldWidget.onPregnancyPlanChange != widget.onPregnancyPlanChange) {
      _applyPregnancyPlanChanges(_state);
    }
    if (oldWidget.onMilkPlanChange != widget.onMilkPlanChange) {
      _applyMilkPlanChanges(_state);
    }
  }

  @override
  void dispose() {
    _voiceCaptureGeneration += 1;
    unawaited(widget.voiceInputController?.cancelCapture());
    _cancelRunSubscription();
    _unsubscribeVoicePlaybackIdle?.call();
    widget.ibclcConsultStore?.removeListener(_handleIbclcConsultStoreChanged);
    _persistInteractionState();
    _flushPersistentInteractionState();
    _composerController.removeListener(_persistInteractionState);
    _chatScrollController
      ..removeListener(_handleChatScroll)
      ..dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _runStateNotifier.dispose();
    _visibleReplyRunningNotifier.dispose();
    _composerLockedNotifier.dispose();
    _sessionMutationPendingNotifier.dispose();
    _conversationSwitchEnabledNotifier.dispose();
    _responseLightRailModeNotifier.dispose();
    _activeVoicePlaybackIdNotifier.dispose();
    _actionStateRevisionNotifier.dispose();
    _formSubmissionsNotifier.dispose();
    _formPresentationSession.clear();
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

  void _syncIbclcConsultStore(
    IbclcConsultStore? oldStore,
    IbclcConsultStore? newStore,
  ) {
    oldStore?.removeListener(_handleIbclcConsultStoreChanged);
    _lastHandledIbclcCompletionRevision = newStore?.completionRevision ?? 0;
    newStore?.addListener(_handleIbclcConsultStoreChanged);
  }

  void _handleIbclcConsultStoreChanged() {
    final store = widget.ibclcConsultStore;
    if (store == null ||
        store.completionRevision <= _lastHandledIbclcCompletionRevision) {
      return;
    }
    _lastHandledIbclcCompletionRevision = store.completionRevision;
    final routeState = store.lastCompletedRouteState;
    if (routeState == null || routeState.returnPath != '/') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final position = _chatScrollController.position;
      final offset = routeState.returnScrollOffset
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      position.jumpTo(offset);
      _updateLatestButtonVisibility();
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
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
    _syncConversationSwitchEnabled();
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
    _attachedFiles.addAll(interactionState.attachedFiles);
    _autoVoiceEnabled = interactionState.autoVoiceEnabled;
    _activeRequest = interactionState.activeRequest;
    _localActionStatuses.addAll(interactionState.localActionStatuses);
    _formSubmissionsNotifier.value =
        Map<String, AgentArtifactFormSubmission>.of(
          interactionState.formSubmissions,
        );
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
        ..autoVoiceEnabled = _autoVoiceEnabled
        ..activeRequest = _activeRequest
        ..localActionStatuses = {..._localActionStatuses}
        ..formSubmissions = _completedFormSubmissions();
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

  void _initializeInteractionState() {
    if (widget.interactionStateStore == null || _hasLocalInteraction()) {
      _interactionRestoreResolved = true;
      _applyInitialComposerText();
      _scheduleInitialAutoSendIfNeeded();
      _scheduleInitialInteractionPostFrame();
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
        snapshot?.hasConversationHistory == true && !_hasLocalInteraction();
    setState(() {
      if (shouldRestore) _applyInteractionSnapshot(snapshot!);
      _interactionRestoreResolved = true;
    });
    if (shouldRestore) {
      _applyHospitalBagCartUpdates(_state);
      _applyPregnancyDiaryChanges(_state);
      _applyPregnancyPlanChanges(_state);
      _applyMilkPlanChanges(_state);
      _applyHospitalBagCartLinkContext(_state);
    }
    _applyInitialComposerText();
    _scheduleInitialAutoSendIfNeeded();
    if (shouldRestore) _persistInteractionState();
    _scheduleInitialInteractionPostFrame(scrollToLatest: shouldRestore);
  }

  void _scheduleInitialInteractionPostFrame({bool scrollToLatest = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_interactionRestoreResolved) return;
      _updateLatestButtonVisibility();
      if (scrollToLatest) {
        _scheduleScrollToLatest();
      }
      unawaited(_refreshGreetingAndMaybePlayVoice());
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
        _activeRequest != null ||
        _localActionStatuses.isNotEmpty ||
        _formSubmissionsNotifier.value.isNotEmpty;
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
        .toList();
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
    _autoVoiceEnabled = snapshot.autoVoiceEnabled;
    _activeRequest = snapshot.activeRequest;
    _localActionStatuses
      ..clear()
      ..addAll(snapshot.localActionStatuses);
    _formSubmissionsNotifier.value =
        Map<String, AgentArtifactFormSubmission>.of(snapshot.formSubmissions);
    _seedExistingFormPresentations();
  }

  void _seedExistingFormPresentations() {
    _formPresentationSession.seedExistingFormIds([
      ..._formArtifactIdsForState(_state),
      for (final message in _historyMessages)
        if (message.runState case final runState?)
          ..._formArtifactIdsForState(runState),
    ]);
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
      attachedFiles: [..._attachedFiles],
      autoVoiceEnabled: _autoVoiceEnabled,
      activeRequest: _activeRequest,
      localActionStatuses: {..._localActionStatuses},
      formSubmissions: _completedFormSubmissions(),
    );
  }

  Map<String, AgentArtifactFormSubmission> _completedFormSubmissions() {
    return {
      for (final entry in _formSubmissionsNotifier.value.entries)
        if (entry.value.isSubmitted) entry.key: entry.value,
    };
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
    if (_preserveArtifactFocus &&
        position.maxScrollExtent - position.pixels <= 20) {
      _preserveArtifactFocus = false;
    }
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
    setState(() {
      _olderConversationHistoryLoading = true;
      _olderConversationHistoryError = null;
    });
    try {
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
        _historyMessages.insertAll(0, olderMessages);
        _conversationHistoryBeforeSequence = page.nextBeforeSequence;
        _olderConversationHistoryLoading = false;
        _olderConversationHistoryError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_chatScrollController.hasClients) return;
        final position = _chatScrollController.position;
        final target = (oldPixels + position.maxScrollExtent - oldExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        position.jumpTo(target);
        _updateLatestButtonVisibility();
      });
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

  Future<void> _scrollToLatestFromUser() {
    _preserveArtifactFocus = false;
    _scrollIntentVersion += 1;
    return _scrollToLatest();
  }

  void _scheduleArtifactFocus({int attempt = 0, int? intentVersion}) {
    if (_artifactFocusFrameScheduled) return;
    final focusIntentVersion = intentVersion ?? ++_scrollIntentVersion;
    _artifactFocusFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _artifactFocusFrameScheduled = false;
      if (!mounted || focusIntentVersion != _scrollIntentVersion) return;
      final artifactContext = _activeArtifactPanelKey.currentContext;
      if (artifactContext == null) {
        if (attempt < 2) {
          _scheduleArtifactFocus(
            attempt: attempt + 1,
            intentVersion: focusIntentVersion,
          );
        }
        return;
      }
      final renderObject = artifactContext.findRenderObject();
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (renderObject == null ||
          viewport == null ||
          !_chatScrollController.hasClients) {
        if (attempt < 2) {
          _scheduleArtifactFocus(
            attempt: attempt + 1,
            intentVersion: focusIntentVersion,
          );
        }
        return;
      }
      final position = _chatScrollController.position;
      final artifactLeadingOffset = viewport
          .getOffsetToReveal(renderObject, 0)
          .offset;
      final targetOffset =
          (artifactLeadingOffset - position.viewportDimension * 0.25).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
      unawaited(
        _chatScrollController
            .animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            )
            .then((_) => _updateLatestButtonVisibility()),
      );
    });
  }

  bool _isComposerLockedForState(AgentStreamRunState state) =>
      state.phase == AgentStreamRunPhase.waitingForConfirmation ||
      state.phase == AgentStreamRunPhase.cancelRequested;

  bool _isVisibleReplyRunningForState(AgentStreamRunState state) =>
      state.isAwaitingVisibleReply;

  bool _canRetryForState(AgentStreamRunState state) =>
      widget.runner != null && state.canRetry && _activeRequest != null;

  bool get _isComposerLocked =>
      _followUpStartPending ||
      _newSessionStartPending ||
      _supportTicketSubmitPending ||
      _conversationSwitchPending ||
      _attachmentUploadPending ||
      _isComposerLockedForState(_state);

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
      ).timeout(_completedReplyCancelTimeout, onTimeout: () {});
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

    _cancelCurrentBubblePlaybackForNewTurn();
    await _waitForCompletedReplyRunSettlement();
    await _waitForPendingServerCancel();
    if (!mounted || _isComposerLocked) return;

    final requestMessage = message.isNotEmpty
        ? message
        : (_attachedFiles.isNotEmpty && _attachedImages.isEmpty
              ? '请查看这个文件'
              : '请看这张图片');
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
          role: AgentHubHistoryRole.user,
          content: message,
          images: sentImages,
          files: sentFiles,
        ),
      );
      _attachedImages.clear();
      _attachedFiles.clear();
      _pendingAutoVoiceReplay = null;
    });
    _persistInteractionState();
    _scheduleScrollToLatest();
    _dismissComposerKeyboardOnRunAccepted = true;
    await _startRun(request);
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

    _cancelCurrentBubblePlaybackForNewTurn();
    await _waitForCompletedReplyRunSettlement();
    await _waitForPendingServerCancel();
    if (!mounted || _isComposerLocked) return false;
    final interruptedState = _state.isActive ? _state : null;
    final interruptedRequest = _state.isActive ? _activeRequest : null;
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
      _attachedFiles.clear();
      _pendingAutoVoiceReplay = null;
    });
    _persistInteractionState();
    _scheduleScrollToLatest();
    return _startRun(request, awaitServerRunSignal: awaitServerRunSignal);
  }

  void _handleArtifactAction(AgentArtifactActionView action) {
    if (action.kind == 'form.submit') {
      unawaited(_handleArtifactFormSubmit(action));
      return;
    }
    var resolvedAction = action;
    if (action.routePath == '/ibclc-chat.html') {
      final rawExtra = action.routeExtra;
      final fallbackState = rawExtra is IbclcConsultRouteDraft
          ? rawExtra.resolve(
              threadId: _state.threadId ?? _activeRequest?.threadId ?? '',
              runId: _state.runId ?? _activeRequest?.runId ?? '',
            )
          : rawExtra is IbclcConsultRouteState
          ? rawExtra
          : null;
      final routeState = fallbackState?.withReturnContext(
        returnPath: '/',
        returnScrollOffset: _chatScrollController.hasClients
            ? _chatScrollController.offset
            : 0,
      );
      if (routeState == null) {
        widget.onArtifactAction?.call(action);
        return;
      }
      resolvedAction = AgentArtifactActionView(
        label: action.label,
        icon: action.icon,
        kind: action.kind,
        value: action.value,
        routePath: action.routePath,
        routeExtra: routeState,
        externalUri: action.externalUri,
        hospitalBagCartSeed: action.hospitalBagCartSeed,
      );
    }
    widget.onArtifactAction?.call(resolvedAction);
  }

  Future<bool> _handleArtifactFormSubmit(AgentArtifactActionView action) async {
    final submission = _formSubmissionFromAction(action);
    if (submission == null) return false;
    final artifactId = submission.artifactId;
    final existing = _formSubmissionsNotifier.value[artifactId];
    if (existing?.isSubmitted == true) return true;
    if (existing?.isSubmitting == true) return false;

    _setFormSubmission(
      artifactId,
      AgentArtifactFormSubmission.submitting(values: submission.values),
    );
    final idempotencyKey = _formSubmissionIdempotencyKey(
      artifactId: artifactId,
      formId: submission.formId,
      threadId: _state.threadId ?? _activeRequest?.threadId,
      values: submission.values,
    );

    var accepted = false;
    try {
      accepted = submission.formId == 'support_ticket'
          ? await _submitSupportTicket(
              artifactId: artifactId,
              values: submission.values,
              idempotencyKey: idempotencyKey,
            )
          : await _sendSyntheticUserMessage(
              requestMessage: _formSubmitRequestMessage(action),
              optimisticContent: '已提交信息采集表单',
              metadata: _formSubmissionMetadata(action),
              idempotencyKey: idempotencyKey,
              awaitServerRunSignal: true,
            );
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return accepted;

    if (accepted) {
      _setFormSubmission(
        artifactId,
        AgentArtifactFormSubmission.submitted(values: submission.values),
      );
    } else {
      _removeFormSubmission(artifactId);
    }
    _persistInteractionState();
    return accepted;
  }

  Future<bool> _submitSupportTicket({
    required String artifactId,
    required Map<String, Object?> values,
    required String idempotencyKey,
  }) async {
    final submitter = widget.supportTicketSubmitter;
    if (submitter == null) return false;
    _supportTicketSubmitPending = true;
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
    try {
      await submitter(
        SupportTicketSubmitRequest(
          artifactId: artifactId,
          values: values,
          idempotencyKey: idempotencyKey,
          threadId: _state.threadId ?? _activeRequest?.threadId,
          locale: _activeRequest?.locale,
        ),
      );
      if (!mounted) return true;

      _cancelCurrentBubblePlaybackForNewTurn();
      final archivedAssistantMessage = _currentAssistantHistoryMessage();
      final threadId = _state.threadId ?? _activeRequest?.threadId;
      setState(() {
        if (archivedAssistantMessage != null) {
          _historyMessages.add(archivedAssistantMessage);
        }
        _historyMessages.add(
          const AgentHubHistoryMessage(
            role: AgentHubHistoryRole.user,
            content: '已提交售后工单',
          ),
        );
        _setRunState(
          AgentStreamRunState(
            phase: AgentStreamRunPhase.finished,
            threadId: threadId,
            textContent: _supportTicketSubmittedReply,
            completedAssistantMessageReceived: true,
          ),
        );
        _pendingAutoVoiceReplay = null;
      });
      _persistInteractionState();
      _scheduleScrollToLatest();
      return true;
    } catch (_) {
      return false;
    } finally {
      _supportTicketSubmitPending = false;
      if (mounted) {
        _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
      }
    }
  }

  void _setFormSubmission(
    String artifactId,
    AgentArtifactFormSubmission submission,
  ) {
    _formSubmissionsNotifier.value = {
      ..._formSubmissionsNotifier.value,
      artifactId: submission,
    };
  }

  void _removeFormSubmission(String artifactId) {
    if (!_formSubmissionsNotifier.value.containsKey(artifactId)) return;
    final next = Map<String, AgentArtifactFormSubmission>.of(
      _formSubmissionsNotifier.value,
    )..remove(artifactId);
    _formSubmissionsNotifier.value = next;
  }

  AgentHubHistoryMessage? _currentAssistantHistoryMessage() {
    final state = _state;
    final text = _agentAssistantTextForState(state, greeting: _greeting).trim();
    if (text.isEmpty) return null;
    return AgentHubHistoryMessage(
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
        final bytes = _decodeAgentImageBytes(image.dataUrl);
        final uploaded = await mediaRepository.uploadFile(
          file: ApiUploadFile(
            name: image.name.trim().isEmpty ? 'image.png' : image.name.trim(),
            mimeType: image.mimeType.trim().isEmpty
                ? 'image/png'
                : image.mimeType.trim(),
            sizeBytes: bytes.length,
            bytes: bytes,
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
    if (!mounted) return;
    setState(() {
      _attachmentUploadPending = false;
      if (image != null && failure == null) {
        _attachedImages.add(image);
      }
    });
    _publishAttachmentUploadState();
    if (failure != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片上传失败，请重试。')));
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
    if (!mounted) return;
    setState(() {
      _attachmentUploadPending = false;
      if (file != null && failure == null) {
        _attachedFiles.add(file);
      }
    });
    _publishAttachmentUploadState();
    if (failure != null) {
      final message = switch (failure) {
        AgentDocumentInputException(code: 'file_too_large') => '文件不能超过 10MB。',
        AgentDocumentInputException(code: 'unsupported_file_type') =>
          '暂仅支持 PDF 文件。',
        _ => '文件上传失败，请重试。',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (file == null) return;
    _persistInteractionState();
  }

  void _setAttachmentUploadPending(bool value) {
    if (_attachmentUploadPending == value) return;
    setState(() {
      _attachmentUploadPending = value;
    });
    _publishAttachmentUploadState();
  }

  void _publishAttachmentUploadState() {
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
    _syncConversationSwitchEnabled();
  }

  bool get _canAddAttachment =>
      _attachedImages.length + _attachedFiles.length < _agentRunAttachmentLimit;

  void _startVoiceInput() {
    if (widget.voiceInputController == null ||
        _isComposerLocked ||
        _voiceState.isInputActive) {
      return;
    }

    setState(() {
      _setVoiceState(_voiceState.startListening());
    });

    final controller = widget.voiceInputController;
    if (controller == null) return;
    final generation = ++_voiceCaptureGeneration;
    final start = _beginVoiceCapture(controller, generation);
    _voiceCaptureStart = start;
  }

  Future<AgentVoiceInputPermissionState> _beginVoiceCapture(
    AgentVoiceInputController controller,
    int generation,
  ) async {
    try {
      final permission = await controller.startCapture();
      if (mounted &&
          generation == _voiceCaptureGeneration &&
          permission != AgentVoiceInputPermissionState.granted) {
        setState(() {
          _setVoiceState(_voiceState.markPermissionDenied(permission));
        });
      }
      return permission;
    } catch (error) {
      if (mounted && generation == _voiceCaptureGeneration) {
        setState(() {
          _setVoiceState(_voiceState.fail(error));
        });
      }
      return AgentVoiceInputPermissionState.unknown;
    }
  }

  Future<void> _finishVoiceInput({required bool submit}) async {
    final controller = widget.voiceInputController;
    final start = _voiceCaptureStart;
    _voiceCaptureStart = null;

    if (controller == null) {
      if (mounted) setState(() => _setVoiceState(const AgentVoiceState()));
      return;
    }

    final permission = start == null
        ? AgentVoiceInputPermissionState.unknown
        : await start;
    if (!submit) {
      try {
        await controller.cancelCapture();
      } catch (error) {
        if (mounted) setState(() => _setVoiceState(_voiceState.fail(error)));
        return;
      }
      if (mounted) setState(() => _setVoiceState(const AgentVoiceState()));
      return;
    }
    if (permission != AgentVoiceInputPermissionState.granted) return;

    if (mounted) {
      setState(() {
        _setVoiceState(
          _voiceState.startTranscribing(draft: _composerController.text),
        );
      });
    }

    try {
      final result = await controller.finishCapture();
      if (!mounted) return;
      _applyVoiceInputResult(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _setVoiceState(_voiceState.fail(error));
      });
    }
  }

  void _applyVoiceInputResult(AgentVoiceInputResult result) {
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
  }

  void _removeAttachedImage(int index) {
    if (index < 0 || index >= _attachedImages.length) return;
    setState(() {
      _attachedImages.removeAt(index);
    });
    _persistInteractionState();
  }

  void _removeAttachedFile(int index) {
    if (index < 0 || index >= _attachedFiles.length) return;
    setState(() {
      _attachedFiles.removeAt(index);
    });
    _persistInteractionState();
  }

  Future<void> _openConversationHistory() async {
    final repository = widget.conversationRepository;
    if (repository == null ||
        _isSessionMutationPending ||
        _attachmentUploadPending) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await showAgentConversationPanel(
      context: context,
      repository: repository,
      activeThreadId: _state.threadId ?? _activeRequest?.threadId,
      canSwitchListenable: _conversationSwitchEnabledNotifier,
      onSelected: _switchConversation,
      onDismissed: _cancelPendingConversationSwitch,
    );
  }

  Future<bool> _switchConversation(String threadId) async {
    final repository = widget.conversationRepository;
    final normalizedThreadId = threadId.trim();
    if (repository == null ||
        normalizedThreadId.isEmpty ||
        _isVisibleReplyRunning ||
        _attachmentUploadPending ||
        _conversationSwitchPending ||
        _newSessionStartPending) {
      return false;
    }
    if (normalizedThreadId == (_state.threadId ?? _activeRequest?.threadId)) {
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

      widget.voicePlaybackCoordinator?.cancel();
      _cancelRunSubscription();
      _composerController.clear();
      _formPresentationSession.clear();
      _formSubmissionsNotifier.value =
          const <String, AgentArtifactFormSubmission>{};
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
        _pendingActionIds.clear();
        _localActionStatuses.clear();
        _activeRequest = null;
        _setVoiceState(const AgentVoiceState());
        _pendingAutoVoiceReplay = null;
        _resetAutoVoiceProgress();
      });
      _seedExistingFormPresentations();
      _notifyActionStateChanged();
      _persistInteractionState();
      _flushPersistentInteractionState();
      _scheduleScrollToLatest();
      _armOlderConversationHistoryLoading();

      if (history.currentState.isActive &&
          history.currentState.runId?.trim().isNotEmpty == true &&
          widget.runner != null) {
        await _resumeCurrentRun(preserveActionState: true);
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

  void _cancelPendingConversationSwitch() {
    if (!_conversationSwitchPending) return;
    _sessionOperationGeneration += 1;
    _setConversationSwitchPending(false);
  }

  void _setConversationSwitchPending(bool value) {
    if (_conversationSwitchPending == value) return;
    _conversationSwitchPending = value;
    _publishSessionMutationState();
  }

  Future<void> _startNewSession() async {
    if (_isVisibleReplyRunning ||
        _attachmentUploadPending ||
        _newSessionStartPending ||
        _conversationSwitchPending) {
      return;
    }
    final operationGeneration = ++_sessionOperationGeneration;
    _setNewSessionStartPending(true);
    try {
      if (_state.isActive) {
        _sendBestEffortServerCancel(_state, _activeRequest);
      }
      widget.voicePlaybackCoordinator?.cancel();
      await widget.onNewSession?.call();
      if (!mounted || operationGeneration != _sessionOperationGeneration) {
        return;
      }
      _dismissComposerKeyboardOnRunAccepted = false;
      _cancelRunSubscription();
      _composerController.clear();
      _formSubmissionsNotifier.value =
          const <String, AgentArtifactFormSubmission>{};
      _formPresentationSession.clear();
      setState(() {
        _setRunState(const AgentStreamRunState());
        _historyMessages.clear();
        _conversationHistoryBeforeSequence = null;
        _olderConversationHistoryLoading = false;
        _olderConversationHistoryLoadArmed = false;
        _olderConversationHistoryError = null;
        _attachedImages.clear();
        _attachedFiles.clear();
        _pendingActionIds.clear();
        _localActionStatuses.clear();
        _activeRequest = null;
        _setVoiceState(const AgentVoiceState());
        _pendingAutoVoiceReplay = null;
        _appliedHospitalBagCartUpdates.clear();
        _hospitalBagCartLinkContextApplied = false;
        _resetAutoVoiceProgress();
      });
      _notifyActionStateChanged();
      _persistInteractionState();
      _flushPersistentInteractionState();
      unawaited(_refreshGreetingAndMaybePlayVoice());
    } catch (_) {
      // Keep the current session visible when its durable cart clear fails.
    } finally {
      if (operationGeneration == _sessionOperationGeneration) {
        if (mounted) {
          _setNewSessionStartPending(false);
        } else {
          _newSessionStartPending = false;
        }
      }
    }
  }

  void _setNewSessionStartPending(bool value) {
    if (_newSessionStartPending == value) return;
    _newSessionStartPending = value;
    _publishSessionMutationState();
  }

  bool get _isSessionMutationPending =>
      _newSessionStartPending || _conversationSwitchPending;

  void _publishSessionMutationState() {
    _setNotifierValue(
      _sessionMutationPendingNotifier,
      _isSessionMutationPending,
    );
    _setNotifierValue(_composerLockedNotifier, _isComposerLocked);
    _syncConversationSwitchEnabled();
  }

  void _syncConversationSwitchEnabled() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncConversationSwitchEnabled();
      });
      return;
    }
    _setNotifierValue(
      _conversationSwitchEnabledNotifier,
      !_isVisibleReplyRunning &&
          !_isSessionMutationPending &&
          !_attachmentUploadPending,
    );
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

  Future<void> _refreshGreetingAndMaybePlayVoice() async {
    final loader = widget.greetingProfileLoader;
    if (loader == null) {
      _maybeStartGreetingVoicePlayback();
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
        _profile = profile;
        if (isShowingFreshGreeting) _greeting = nextGreeting;
      });
    }
    if (!isShowingFreshGreeting) return;
    _maybeStartGreetingVoicePlayback();
  }

  bool get _isShowingFreshGreeting =>
      _state.phase == AgentStreamRunPhase.idle &&
      _state.textContent.trim().isEmpty &&
      _state.provisionalTextContent.trim().isEmpty &&
      _historyMessages.isEmpty &&
      _activeRequest == null;

  void _maybeStartGreetingVoicePlayback() {
    final coordinator = widget.voicePlaybackCoordinator;
    final player = widget.voicePlaybackPlayer;
    if (!_interactionRestoreResolved ||
        !_isShowingFreshGreeting ||
        coordinator == null ||
        player == null ||
        !_autoVoiceEnabled) {
      return;
    }

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
    _startVoicePlayback(handle: handle, text: _greeting);
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
    _updateComposerFocusForRun(nextState);
    final shouldFollowLatest = _isNearLatest() || nextState.isActive;
    _formPresentationSession.registerLiveFormIds(
      _formArtifactIdsForState(nextState),
    );
    final artifactProjectionChanged = _artifactProjectionChanged(
      _state,
      nextState,
    );
    final hospitalBagCartProjectionChanged =
        artifactProjectionChanged ||
        _hasNewHospitalBagCartChangedEvent(_state, nextState);
    if (hospitalBagCartProjectionChanged) {
      _applyHospitalBagCartUpdates(nextState);
    }
    _applyPregnancyDiaryChanges(nextState);
    _applyPregnancyPlanChanges(nextState);
    _applyMilkPlanChanges(nextState);
    _applyHospitalBagCartLinkContext(
      nextState,
      checkArtifacts: artifactProjectionChanged,
    );
    final previousArtifactId = _latestVisibleArtifactId(_state);
    final nextArtifactId = _latestVisibleArtifactId(nextState);
    final shouldFocusArtifact =
        nextArtifactId != null && nextArtifactId != previousArtifactId;
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      _activeRequest = _requestWithThreadId(activeRequest, nextState.threadId);
    }
    _applyRunStateUpdate(
      nextState,
      shouldFollowLatest: shouldFollowLatest,
      shouldFocusArtifact: shouldFocusArtifact,
    );
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
    bool shouldFocusArtifact = false,
  }) {
    if (!mounted) return;
    _setRunState(nextState);
    if (nextState.isActive) {
      _persistActiveInteractionStateThrottled();
    } else {
      _persistInteractionState();
    }
    _maybeStartAutoVoicePlayback(nextState);
    if (shouldFocusArtifact) {
      _preserveArtifactFocus = true;
      _scheduleArtifactFocus();
    } else if (shouldFollowLatest && !_preserveArtifactFocus) {
      _scheduleScrollToLatest();
    }
  }

  void _applyHospitalBagCartUpdates(AgentStreamRunState state) {
    if (_newSessionStartPending) return;
    final onUpdate = widget.onHospitalBagCartUpdate;
    if (onUpdate == null) return;
    for (final card in _artifactCardsFromEvents(
      _artifactEventsForState(state),
    )) {
      if (card.presentationKind !=
          AgentArtifactPresentationKind.hospitalBagCart) {
        continue;
      }
      final cartUpdate =
          card.payload['cart_update'] ?? card.payload['cartUpdate'];
      final seed = HospitalBagCartArtifactSeed.tryFromCartUpdate(
        artifactId: card.id,
        cartUpdate: cartUpdate,
      );
      if (seed != null) _applyHospitalBagCartSeed(seed, onUpdate);
    }
    for (final event in state.events) {
      if (event.type != 'hospital_bag.cart.changed') continue;
      final actionId = event.actionId?.trim();
      if (actionId == null || actionId.isEmpty) continue;
      final cartUpdate =
          event.payload['cart_update'] ?? event.payload['cartUpdate'];
      final seed = HospitalBagCartArtifactSeed.tryFromCartUpdate(
        artifactId: 'action:$actionId',
        cartUpdate: cartUpdate,
      );
      if (seed != null) _applyHospitalBagCartSeed(seed, onUpdate);
    }
  }

  void _applyHospitalBagCartSeed(
    HospitalBagCartArtifactSeed seed,
    HospitalBagCartUpdateHandler onUpdate,
  ) {
    final signature =
        '${seed.artifactId}:${jsonEncode(seed.snapshot.toAgentContext())}';
    if (!_appliedHospitalBagCartUpdates.add(signature)) return;
    onUpdate(seed);
  }

  void _applyPregnancyDiaryChanges(AgentStreamRunState state) {
    final onChange = widget.onPregnancyDiaryChange;
    if (onChange == null) return;
    for (final event in state.events) {
      final change = PregnancyDiaryChange.tryFromEvent(event);
      if (change == null ||
          !_appliedPregnancyDiaryChangeEventIds.add(change.eventId)) {
        continue;
      }
      onChange(change);
    }
  }

  void _applyPregnancyPlanChanges(AgentStreamRunState state) {
    final onChange = widget.onPregnancyPlanChange;
    if (onChange == null) return;
    for (final event in state.events) {
      final change = PregnancyPlanChange.tryFromEvent(event);
      if (change == null ||
          !_appliedPregnancyPlanChangeEventIds.add(change.eventId)) {
        continue;
      }
      onChange(change);
    }
  }

  void _applyMilkPlanChanges(AgentStreamRunState state) {
    final onChange = widget.onMilkPlanChange;
    if (onChange == null) return;
    for (final event in state.events) {
      final change = MilkPlanChange.tryFromEvent(event);
      if (change == null ||
          !_appliedMilkPlanChangeEventIds.add(change.eventId)) {
        continue;
      }
      onChange(change);
    }
  }

  void _applyHospitalBagCartLinkContext(
    AgentStreamRunState state, {
    bool checkArtifacts = true,
  }) {
    if (_hospitalBagCartLinkContextApplied ||
        widget.onHospitalBagCartContextRequired == null) {
      return;
    }
    const cartPath = '/hospital-bag-cart';
    final text = state.textContent;
    final tailStart = math.max(0, text.length - cartPath.length - 16);
    final hasTextLink = checkArtifacts
        ? text.contains(cartPath)
        : text.indexOf(cartPath, tailStart) >= 0;
    final hasArtifactLink =
        checkArtifacts &&
        _artifactCardsFromEvents(_artifactEventsForState(state)).any(
          (card) => card.actions.any((action) => action.routePath == cartPath),
        );
    final hasCartLink = hasTextLink || hasArtifactLink;
    if (!hasCartLink) return;
    _hospitalBagCartLinkContextApplied = true;
    widget.onHospitalBagCartContextRequired!.call();
  }

  Future<bool> _startRun(
    AgentStreamRequest request, {
    AgentStreamRunState? initialState,
    bool preserveActionState = false,
    bool awaitServerRunSignal = false,
  }) async {
    final runner = widget.runner;
    if (runner == null || (initialState == null && _isComposerLocked)) {
      return false;
    }
    final requestWithThread = _requestWithConversationThread(request);

    _cancelRunSubscription();
    final acceptance = awaitServerRunSignal ? Completer<bool>() : null;
    final settlement = Completer<void>();
    _runAcceptanceCompleter = acceptance;
    _runSettlementCompleter = settlement;
    _preserveArtifactFocus = false;
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

  void _maybeStartAutoVoicePlayback(AgentStreamRunState nextState) {
    final coordinator = widget.voicePlaybackCoordinator;
    final player = widget.voicePlaybackPlayer;
    final text = nextState.textContent.trim();
    final artifactText = _autoVoiceArtifactTextForState(nextState);
    final mediaNarrations = _autoVoiceMediaNarrationsForState(nextState);
    if (coordinator == null ||
        player == null ||
        !_autoVoiceEnabled ||
        !_canAutoVoicePlayback(nextState.phase) ||
        (text.isEmpty && artifactText == null && mediaNarrations.isEmpty)) {
      return;
    }

    final playbackId = _autoVoicePlaybackId(nextState);
    final isNewPlayback = _activeAutoVoicePlaybackId != playbackId;
    if (isNewPlayback) {
      _cancelActiveAutoVoiceSession();
      _activeAutoVoicePlaybackId = playbackId;
      _autoVoiceAppendedText = '';
      _autoVoiceHasSubmittedContent = false;
      _autoVoiceSessionFinished = false;
      _autoVoiceSubmittedArtifactTexts.clear();
      _autoVoiceSubmittedMediaNarrations.clear();
    }

    final textToAppend = _nextAutoVoiceTextToAppend(text);
    final hasUnsubmittedArtifact =
        artifactText != null &&
        !_autoVoiceSubmittedArtifactTexts.contains(artifactText);
    final hasUnsubmittedMedia = mediaNarrations.any(
      (narration) =>
          !_autoVoiceSubmittedMediaNarrations.contains(narration.trim()),
    );
    if (_autoVoiceSession == null &&
        textToAppend.trim().isEmpty &&
        !hasUnsubmittedArtifact &&
        !hasUnsubmittedMedia) {
      return;
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
    if (textToAppend.trim().isNotEmpty) {
      session.append(textToAppend);
      _autoVoiceAppendedText = text;
      _autoVoiceHasSubmittedContent = true;
    }
    if (mediaNarrations.isNotEmpty &&
        _shouldFinishAutoVoicePlayback(nextState)) {
      session.flush();
    }
    final supplementalTexts = <String>[
      if (artifactText != null &&
          _autoVoiceSubmittedArtifactTexts.add(artifactText))
        artifactText,
      ...mediaNarrations.map(_claimAutoVoiceMediaNarration).whereType<String>(),
    ];
    if (supplementalTexts.isNotEmpty) {
      final separator = _autoVoiceAppendedText.isEmpty ? '' : '\n';
      session.append('$separator${supplementalTexts.join(' ')}');
      _autoVoiceHasSubmittedContent = true;
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

    final session = player.startRealtimeSession(
      mediaNarrationResolver: ({required url, required alt}) =>
          _resolveMediaVoiceNarration(url: url),
    );
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

  String? _resolveMediaVoiceNarration({required String url}) {
    final narration = _mediaVoiceNarrationIndexForState(
      _state,
    ).resolve(url)?.trim();
    if (narration == null || narration.isEmpty) return null;
    _autoVoiceSubmittedMediaNarrations.add(narration);
    return narration;
  }

  AgentMediaVoiceNarrationIndex _mediaVoiceNarrationIndexForState(
    AgentStreamRunState state,
  ) {
    final identity = state.events;
    if (!identical(identity, _mediaVoiceEventIdentity)) {
      _mediaVoiceEventIdentity = identity;
      _mediaVoiceNarrationIndex = AgentMediaVoiceNarrationIndex.fromEvents(
        state.events,
      );
    }
    return _mediaVoiceNarrationIndex;
  }

  List<String> _autoVoiceMediaNarrationsForState(AgentStreamRunState state) {
    if (!_shouldFinishAutoVoicePlayback(state)) return const <String>[];
    return _mediaVoiceNarrationIndexForState(state).autoSpeakableTexts;
  }

  String? _autoVoiceArtifactTextForState(AgentStreamRunState state) {
    if (state.textContent.trim().isNotEmpty ||
        !_shouldFinishAutoVoicePlayback(state) ||
        !state.canPublishArtifactEvents) {
      return null;
    }
    return agentArtifactVoiceFallbackText(
      _artifactCardsFromEvents(
        _artifactEventsForState(state),
        profileDefaults:
            _profile?.birthPrepDefaults ?? const BirthPrepProfileDefaults(),
      ),
    );
  }

  String? _claimAutoVoiceMediaNarration(String? narration) {
    final text = narration?.trim();
    if (text == null ||
        text.isEmpty ||
        !_autoVoiceSubmittedMediaNarrations.add(text)) {
      return null;
    }
    return text;
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
            _autoVoiceHasSubmittedContent)) {
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
    _autoVoiceHasSubmittedContent = false;
    _autoVoiceSubmittedArtifactTexts.clear();
    _autoVoiceSubmittedMediaNarrations.clear();
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
    if (pending.attempts >= 3 || !_hasAutoVoicePlaybackContent(pending.state)) {
      _pendingAutoVoiceReplay = null;
      return;
    }

    _pendingAutoVoiceReplay = pending.incrementAttempts();
    _maybeStartAutoVoicePlayback(pending.state);
  }

  bool _hasAutoVoicePlaybackContent(AgentStreamRunState state) {
    return state.textContent.trim().isNotEmpty ||
        _autoVoiceArtifactTextForState(state) != null ||
        _autoVoiceMediaNarrationsForState(state).isNotEmpty;
  }

  void _cancelRun() {
    if (!_state.isActive) return;
    final activeState = _state;
    final activeRequest = _activeRequest;
    widget.voicePlaybackCoordinator?.cancel();
    _dismissComposerKeyboardOnRunAccepted = false;
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
    try {
      await _cancelServerRun(
        activeState,
        activeRequest,
      ).timeout(_completedReplyCancelTimeout);
    } catch (_) {
      // Cancellation is best effort; a new run may still proceed after the
      // bounded settlement window.
    }
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

  Future<void> _cancelServerRun(
    AgentStreamRunState activeState,
    AgentStreamRequest? activeRequest,
  ) async {
    final cancelClient = widget.cancelClient;
    if (cancelClient == null) return;

    final runId = activeState.runId;
    if (runId == null || runId.trim().isEmpty) return;

    await cancelClient.cancel(
      AgentStreamCancelRequest(
        threadId: activeState.threadId ?? activeRequest?.threadId ?? '',
        runId: runId,
        reason: 'user_cancelled',
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
    _applyPregnancyDiaryChanges(nextState);
    _applyPregnancyPlanChanges(nextState);
    _applyMilkPlanChanges(nextState);
    _setRunState(nextState);
  }

  @override
  Widget build(BuildContext context) {
    final profileDefaults =
        _profile?.birthPrepDefaults ?? const BirthPrepProfileDefaults();
    final page = ColoredBox(
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
              ListenableBuilder(
                listenable: Listenable.merge([
                  _visibleReplyRunningNotifier,
                  _sessionMutationPendingNotifier,
                ]),
                builder: (context, child) {
                  final isVisibleReplyRunning =
                      _visibleReplyRunningNotifier.value;
                  final isSessionMutationPending =
                      _sessionMutationPendingNotifier.value;
                  return AgentHubTopBar(
                    showControls: _interactionRestoreResolved,
                    autoVoiceEnabled: _autoVoiceEnabled,
                    isRunning:
                        isVisibleReplyRunning ||
                        isSessionMutationPending ||
                        _attachmentUploadPending,
                    onOpenConversations:
                        widget.conversationRepository == null ||
                            isSessionMutationPending ||
                            _attachmentUploadPending
                        ? null
                        : _openConversationHistory,
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
                                  12,
                                  14,
                                  12,
                                  0,
                                ),
                                sliver: AgentHubHistorySliver(
                                  messages: _historyMessages,
                                  loadImageContent: widget.loadImageContent,
                                  productAssetRepository:
                                      widget.productAssetRepository,
                                  onArtifactAction: _handleArtifactAction,
                                  onFormSubmit: _handleArtifactFormSubmit,
                                  formSubmissionsListenable:
                                      _formSubmissionsNotifier,
                                  formPresentationSession:
                                      _formPresentationSession,
                                  profileDefaults: profileDefaults,
                                ),
                              ),
                            if (_historyMessages.isNotEmpty)
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 18),
                              ),
                            if (_interactionRestoreResolved)
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
                                      greeting: _greeting,
                                      stateListenable: _runStateNotifier,
                                      activeVoicePlaybackIdListenable:
                                          _activeVoicePlaybackIdNotifier,
                                      actionStateRevisionListenable:
                                          _actionStateRevisionNotifier,
                                      artifactPanelKey: _activeArtifactPanelKey,
                                      canRetryForState: _canRetryForState,
                                      onRetry: _retryRun,
                                      onArtifactAction: _handleArtifactAction,
                                      onFormSubmit: _handleArtifactFormSubmit,
                                      formSubmissionsListenable:
                                          _formSubmissionsNotifier,
                                      formPresentationSession:
                                          _formPresentationSession,
                                      // Generated quick replies are temporarily hidden
                                      // while the follow-up interaction is redesigned.
                                      onQuickReplySelected: null,
                                      pendingActionIds: _pendingActionIds,
                                      localActionStatuses: _localActionStatuses,
                                      productAssetRepository:
                                          widget.productAssetRepository,
                                      profileDefaults: profileDefaults,
                                      onConfirmAction:
                                          widget.actionClient == null
                                          ? null
                                          : _confirmAction,
                                      onRejectAction:
                                          widget.actionClient == null
                                          ? null
                                          : _rejectAction,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverToBoxAdapter(
                                child: SizedBox(height: transcriptMinHeight),
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
                              onPressed: _scrollToLatestFromUser,
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
                  final isRestoring = !_interactionRestoreResolved;
                  return AgentComposerBar(
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
                    canUseVoice:
                        !isRestoring &&
                        widget.voiceInputController != null &&
                        !_isVisibleReplyRunningForState(runState) &&
                        !isComposerLocked &&
                        _voiceState.phase != AgentVoicePhase.transcribing,
                    voicePhase: _voiceState.phase,
                    voicePlaybackFailed:
                        _voiceState.phase == AgentVoicePhase.error &&
                        _voiceState.playbackId != null,
                    onChanged: (_) {},
                    onSend: _sendMessage,
                    onCancel: _cancelRun,
                    onTakePhoto: () =>
                        unawaited(_attachImage(AgentImageInputSource.camera)),
                    onPickPhoto: () =>
                        unawaited(_attachImage(AgentImageInputSource.gallery)),
                    onPickFile: () => unawaited(_attachDocument()),
                    onRemoveImage: _removeAttachedImage,
                    onRemoveFile: _removeAttachedFile,
                    onVoiceStart: _startVoiceInput,
                    onVoiceEnd: (submit) =>
                        unawaited(_finishVoiceInput(submit: submit)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
    final consultStore = widget.ibclcConsultStore;
    return consultStore == null
        ? page
        : IbclcConsultStoreScope(store: consultStore, child: page);
  }
}

class AgentHubTopBar extends StatelessWidget {
  const AgentHubTopBar({
    super.key,
    required this.showControls,
    required this.autoVoiceEnabled,
    required this.isRunning,
    this.onOpenConversations,
    required this.onToggleAutoVoice,
    required this.onNewSession,
  });

  final bool showControls;
  final bool autoVoiceEnabled;
  final bool isRunning;
  final VoidCallback? onOpenConversations;
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
          children: [
            if (showControls && onOpenConversations != null)
              IconButton(
                key: const ValueKey('agent-conversation-history-button'),
                onPressed: onOpenConversations,
                icon: const Icon(Icons.menu_rounded, size: 20),
                tooltip: '打开会话历史',
                color: const Color(0xff3b2f36),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  fixedSize: const Size.square(36),
                  minimumSize: const Size.square(36),
                  padding: EdgeInsets.zero,
                ),
              )
            else
              const SizedBox.square(dimension: 36),
            const Spacer(),
            if (showControls) ...[
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
            ],
          ],
        ),
      ),
    );
  }
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
                label: Text(failed ? '加载失败，点击重试' : '加载更早消息'),
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
    this.runState,
    this.images = const <AgentStreamImageInput>[],
    this.files = const <AgentStreamFileInput>[],
  });

  final AgentHubHistoryRole role;
  final String content;
  final AgentStreamRunState? runState;
  final List<AgentStreamImageInput> images;
  final List<AgentStreamFileInput> files;

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
    content: message.content,
    runState: message.runState,
    images: message.images,
    files: message.files,
  );
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

  final structuredEvents = <String, AgentStreamEvent>{};
  final artifactEvents = state.canPublishArtifactEvents
      ? _artifactEventsForState(
          state,
        ).where((event) => event.type.startsWith('artifact.'))
      : const <AgentStreamEvent>[];
  for (final event in artifactEvents) {
    final key = event.artifactId ?? event.eventId ?? event.mergeKey;
    structuredEvents['artifact:$key'] = event;
  }
  final visibleActionTimeline = _actionEventsForState(
    state,
  ).toList(growable: false);
  final finalActionIds = visibleActionTimeline
      .where((event) => _isFinalActionStatus(_actionStatus(event)))
      .map((event) => event.actionId?.trim())
      .whereType<String>()
      .where((actionId) => actionId.isNotEmpty)
      .toSet();
  for (var index = 0; index < visibleActionTimeline.length; index += 1) {
    final event = visibleActionTimeline[index];
    final actionId = event.actionId?.trim();
    if (actionId == null || !finalActionIds.contains(actionId)) continue;
    final eventKey = event.eventId ?? '$index:${event.type}';
    structuredEvents['action:$actionId:$eventKey'] = event;
  }
  for (final event in state.events.where(AgentCitationMapper.isCitationEvent)) {
    final key = event.messageId ?? event.eventId ?? event.mergeKey;
    structuredEvents['citation:$key'] = event;
  }
  if (structuredEvents.isEmpty) return null;

  final events = List<AgentStreamEvent>.unmodifiable(structuredEvents.values);
  return AgentStreamRunState(
    phase: AgentStreamRunPhase.finished,
    events: events,
    threadId: state.threadId,
    runId: state.runId,
    messageId: state.messageId,
    textContent: message.content,
    artifactEvents: {for (final event in events) ?event.artifactId: event},
    actionEvents: {for (final event in events) ?event.actionId: event},
    completedAssistantMessageReceived: true,
  );
}

class AgentHubHistoryPanel extends StatelessWidget {
  const AgentHubHistoryPanel({
    super.key,
    required this.messages,
    this.productAssetRepository,
    this.loadImageContent,
    this.onArtifactAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.profileDefaults = const BirthPrepProfileDefaults(),
  });

  final List<AgentHubHistoryMessage> messages;
  final ProductAssetRepository? productAssetRepository;
  final AgentImageContentLoader? loadImageContent;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final BirthPrepProfileDefaults profileDefaults;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('agent-history-panel'),
      children: [
        for (var index = 0; index < messages.length; index++) ...[
          _AgentHistoryBubble(
            key: ValueKey('agent-history-$index'),
            message: messages[index],
            loadImageContent: loadImageContent,
            productAssetRepository: productAssetRepository,
            onArtifactAction: onArtifactAction,
            onFormSubmit: onFormSubmit,
            formSubmissionsListenable: formSubmissionsListenable,
            formPresentationSession: formPresentationSession,
            profileDefaults: profileDefaults,
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
    this.productAssetRepository,
    this.loadImageContent,
    this.onArtifactAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.profileDefaults = const BirthPrepProfileDefaults(),
  });

  final List<AgentHubHistoryMessage> messages;
  final ProductAssetRepository? productAssetRepository;
  final AgentImageContentLoader? loadImageContent;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final BirthPrepProfileDefaults profileDefaults;

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
          loadImageContent: loadImageContent,
          productAssetRepository: productAssetRepository,
          onArtifactAction: onArtifactAction,
          onFormSubmit: onFormSubmit,
          formSubmissionsListenable: formSubmissionsListenable,
          formPresentationSession: formPresentationSession,
          profileDefaults: profileDefaults,
        );
      }, childCount: itemCount),
    );
  }
}

class _AgentHistoryBubble extends StatelessWidget {
  const _AgentHistoryBubble({
    super.key,
    required this.message,
    this.productAssetRepository,
    this.loadImageContent,
    this.onArtifactAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.profileDefaults = const BirthPrepProfileDefaults(),
  });

  final AgentHubHistoryMessage message;
  final ProductAssetRepository? productAssetRepository;
  final AgentImageContentLoader? loadImageContent;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final BirthPrepProfileDefaults profileDefaults;

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
          productAssetRepository: productAssetRepository,
          onArtifactAction: onArtifactAction,
          onFormSubmit: onFormSubmit,
          formSubmissionsListenable: formSubmissionsListenable,
          formPresentationSession: formPresentationSession,
          allowFormAutoPresentation: false,
          profileDefaults: profileDefaults,
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AgentAssistantAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: AgentMarkdownText(
              message.content,
              style: textStyle,
              onArtifactAction: onArtifactAction,
              productAssetRepository: productAssetRepository,
            ),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.images.isNotEmpty)
                    AgentSentImages(
                      images: message.images,
                      loadImageContent: loadImageContent,
                    ),
                  if (message.images.isNotEmpty && message.files.isNotEmpty)
                    const SizedBox(height: 8),
                  if (message.files.isNotEmpty)
                    AgentSentFiles(files: message.files),
                  if ((message.images.isNotEmpty || message.files.isNotEmpty) &&
                      message.content.isNotEmpty)
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
    required this.greeting,
    required this.stateListenable,
    required this.activeVoicePlaybackIdListenable,
    required this.actionStateRevisionListenable,
    this.artifactPanelKey,
    required this.canRetryForState,
    this.onRetry,
    this.onArtifactAction,
    this.onFormSubmit,
    required this.formSubmissionsListenable,
    required this.formPresentationSession,
    this.onQuickReplySelected,
    required this.pendingActionIds,
    required this.localActionStatuses,
    this.productAssetRepository,
    this.profileDefaults = const BirthPrepProfileDefaults(),
    this.onConfirmAction,
    this.onRejectAction,
  });

  final String greeting;
  final ValueListenable<AgentStreamRunState> stateListenable;
  final ValueListenable<String?> activeVoicePlaybackIdListenable;
  final ValueListenable<int> actionStateRevisionListenable;
  final Key? artifactPanelKey;
  final bool Function(AgentStreamRunState state) canRetryForState;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession formPresentationSession;
  final ValueChanged<String>? onQuickReplySelected;
  final Set<String> pendingActionIds;
  final Map<String, String> localActionStatuses;
  final ProductAssetRepository? productAssetRepository;
  final BirthPrepProfileDefaults profileDefaults;
  final ValueChanged<AgentActionCardView>? onConfirmAction;
  final ValueChanged<AgentActionCardView>? onRejectAction;

  @override
  State<_AgentRunTranscriptListenable> createState() =>
      _AgentRunTranscriptListenableState();
}

class _AgentRunTranscriptListenableState
    extends State<_AgentRunTranscriptListenable> {
  Object? _artifactSourceIdentity;
  Object? _artifactProfileDefaultsIdentity;
  List<AgentArtifactCardView> _artifactCards = const <AgentArtifactCardView>[];
  Object? _actionSourceIdentity;
  int? _actionRevision;
  List<AgentActionCardView> _actionCards = const <AgentActionCardView>[];
  Object? _citationSourceIdentity;
  String? _citationMessageId;
  List<AgentCitationView> _citations = const <AgentCitationView>[];

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
          greeting: widget.greeting,
          activeVoicePlaybackId: widget.activeVoicePlaybackIdListenable.value,
          canRetry: widget.canRetryForState(state),
          onRetry: widget.onRetry,
          onArtifactAction: widget.onArtifactAction,
          onFormSubmit: widget.onFormSubmit,
          formSubmissionsListenable: widget.formSubmissionsListenable,
          formPresentationSession: widget.formPresentationSession,
          allowFormAutoPresentation: true,
          artifactPanelKey: widget.artifactPanelKey,
          onQuickReplySelected: widget.onQuickReplySelected,
          pendingActionIds: widget.pendingActionIds,
          productAssetRepository: widget.productAssetRepository,
          profileDefaults: widget.profileDefaults,
          artifactCards: _artifactCardsForState(state),
          actionCards: _actionCardsForState(state, actionRevision),
          citations: _citationsForState(state),
          onConfirmAction: widget.onConfirmAction,
          onRejectAction: widget.onRejectAction,
        );
      },
    );
  }

  List<AgentArtifactCardView> _artifactCardsForState(
    AgentStreamRunState state,
  ) {
    if (!state.canPublishArtifactEvents) return const [];
    final identity = state.artifactEvents.isNotEmpty
        ? state.artifactEvents
        : state.events;
    if (identical(identity, _artifactSourceIdentity) &&
        identical(widget.profileDefaults, _artifactProfileDefaultsIdentity)) {
      return _artifactCards;
    }
    _artifactSourceIdentity = identity;
    _artifactProfileDefaultsIdentity = widget.profileDefaults;
    _artifactCards = _artifactCardsFromEvents(
      _artifactEventsForState(state),
      profileDefaults: widget.profileDefaults,
    );
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

  List<AgentCitationView> _citationsForState(AgentStreamRunState state) {
    if (identical(state.events, _citationSourceIdentity) &&
        state.messageId == _citationMessageId) {
      return _citations;
    }
    _citationSourceIdentity = state.events;
    _citationMessageId = state.messageId;
    _citations = AgentCitationMapper.citationsFromEvents(
      state.events,
      messageId: state.messageId,
    );
    return _citations;
  }
}

class AgentRunTranscript extends StatelessWidget {
  const AgentRunTranscript({
    super.key,
    required this.state,
    this.greeting = agentHubDefaultGreeting,
    this.activeVoicePlaybackId,
    this.canRetry = false,
    this.onRetry,
    this.onArtifactAction,
    this.onFormSubmit,
    this.formSubmissionsListenable,
    this.formPresentationSession,
    this.allowFormAutoPresentation = false,
    this.artifactPanelKey,
    this.onQuickReplySelected,
    this.pendingActionIds = const <String>{},
    this.localActionStatuses = const <String, String>{},
    this.productAssetRepository,
    this.profileDefaults = const BirthPrepProfileDefaults(),
    this.artifactCards,
    this.actionCards,
    this.citations,
    this.onConfirmAction,
    this.onRejectAction,
  });

  final AgentStreamRunState state;
  final String greeting;
  final String? activeVoicePlaybackId;
  final bool canRetry;
  final VoidCallback? onRetry;
  final AgentArtifactActionHandler? onArtifactAction;
  final AgentArtifactFormSubmitHandler? onFormSubmit;
  final ValueListenable<Map<String, AgentArtifactFormSubmission>>?
  formSubmissionsListenable;
  final AgentArtifactFormPresentationSession? formPresentationSession;
  final bool allowFormAutoPresentation;
  final Key? artifactPanelKey;
  final ValueChanged<String>? onQuickReplySelected;
  final Set<String> pendingActionIds;
  final Map<String, String> localActionStatuses;
  final ProductAssetRepository? productAssetRepository;
  final BirthPrepProfileDefaults profileDefaults;
  final List<AgentArtifactCardView>? artifactCards;
  final List<AgentActionCardView>? actionCards;
  final List<AgentCitationView>? citations;
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
    final allowsSupplementaryContent =
        state.phase != AgentStreamRunPhase.error &&
        state.phase != AgentStreamRunPhase.cancelled;
    final artifactCards =
        allowsSupplementaryContent && state.canPublishArtifactEvents
        ? this.artifactCards ??
              _artifactCardsFromEvents(
                _artifactEventsForState(state),
                profileDefaults: profileDefaults,
              )
        : const <AgentArtifactCardView>[];
    final canShowFormEntries =
        state.hasCompletedAssistantMessage ||
        (!state.isActive && state.textContent.trim().isNotEmpty);
    final visibleArtifactCards = artifactCards
        .where((card) => !card.isForm || canShowFormEntries)
        .toList(growable: false);
    final actionCards = allowsSupplementaryContent
        ? this.actionCards ??
              _actionCardsFromEvents(
                _actionEventsForState(state),
                localActionStatuses,
              )
        : const <AgentActionCardView>[];
    final citations = allowsSupplementaryContent
        ? this.citations ??
              AgentCitationMapper.citationsFromEvents(
                state.events,
                messageId: state.messageId,
              )
        : const <AgentCitationView>[];
    final quickReplies = state.quickReplies;
    final artifactActionForState = onArtifactAction == null
        ? null
        : (AgentArtifactActionView action) {
            if (action.routePath == '/ibclc-chat.html' &&
                action.routeExtra is IbclcConsultRouteDraft) {
              final draft = action.routeExtra! as IbclcConsultRouteDraft;
              onArtifactAction!(
                AgentArtifactActionView(
                  label: action.label,
                  icon: action.icon,
                  kind: action.kind,
                  value: action.value,
                  routePath: action.routePath,
                  routeExtra: draft.resolve(
                    threadId: state.threadId ?? '',
                    runId: state.runId ?? '',
                  ),
                  externalUri: action.externalUri,
                  hospitalBagCartSeed: action.hospitalBagCartSeed,
                ),
              );
              return;
            }
            onArtifactAction!(action);
          };
    final shouldRenderQuickReplies =
        allowsSupplementaryContent &&
        quickReplies.length == 3 &&
        !state.isAwaitingVisibleReply &&
        !artifactCards.any((card) => card.isForm) &&
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
                      productAssetRepository: productAssetRepository,
                      citations: citations,
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
              if (allowsSupplementaryContent && canRetry) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  key: const ValueKey('agent-retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ],
              if (visibleArtifactCards.isNotEmpty) ...[
                const SizedBox(height: 16),
                AgentArtifactPanel(
                  key: artifactPanelKey,
                  cards: visibleArtifactCards,
                  onAction: artifactActionForState,
                  onFormSubmit: onFormSubmit,
                  formSubmissionsListenable: formSubmissionsListenable,
                  formPresentationSession: formPresentationSession,
                  autoPresentForms:
                      allowFormAutoPresentation &&
                      state.hasCompletedAssistantMessage,
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
              if (citations.isNotEmpty) ...[
                const SizedBox(height: 16),
                AgentCitationList(
                  citations: citations,
                  onAction: onArtifactAction,
                ),
              ],
              if (shouldRenderQuickReplies) ...[
                SizedBox(height: citations.isNotEmpty ? 20 : 16),
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
      return const _AgentLoopDecorState(statusTitle: '正在组织答案～');
    }
    if (state.textContent.trim().isNotEmpty) {
      return const _AgentLoopDecorState();
    }
    return _agentLoopDecorStateFromEvents(state.events);
  }

  String? get _supportingText {
    if (state.phase == AgentStreamRunPhase.waitingForConfirmation) {
      return '等待确认后继续';
    }
    if (state.phase == AgentStreamRunPhase.disconnected) {
      return _safeAgentErrorText(state.errorMessage, fallback: '连接暂时中断，可重试') ??
          '连接暂时中断，可重试';
    }
    if (state.phase == AgentStreamRunPhase.error) {
      return _safeAgentErrorText(
            state.errorMessage,
            fallback: '服务执行失败，请稍后重试',
          ) ??
          '服务执行失败，请稍后重试';
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

class AgentCitationList extends StatelessWidget {
  const AgentCitationList({super.key, required this.citations, this.onAction});

  final List<AgentCitationView> citations;
  final AgentArtifactActionHandler? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('agent-citation-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              child: Divider(height: 1, color: Color(0xffdbc3cb)),
            ),
            const SizedBox(width: 6),
            Text(
              '专业信息源',
              style: textTheme.labelSmall?.copyWith(
                color: const Color(0xff8f7a84),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < citations.length; index++) ...[
          _AgentCitationLink(
            citation: citations[index],
            onTap: onAction == null
                ? null
                : () => onAction!(
                    AgentArtifactActionView(
                      label: citations[index].title,
                      icon: Icons.open_in_new_rounded,
                      kind: 'citation',
                      value: citations[index].url.toString(),
                      externalUri: citations[index].url,
                    ),
                  ),
          ),
          if (index < citations.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _AgentCitationLink extends StatelessWidget {
  const _AgentCitationLink({required this.citation, this.onTap});

  final AgentCitationView citation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '[${citation.index}]',
            style: textTheme.labelSmall?.copyWith(
              color: const Color(0xffaa929f),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            key: ValueKey('agent-citation-link-${citation.index}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                citation.displayText,
                overflow: TextOverflow.visible,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xff3d7d85),
                  fontSize: 11,
                  height: 1.35,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xffb8d7d4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AgentMarkdownText extends StatelessWidget {
  const AgentMarkdownText(
    this.text, {
    super.key,
    this.style,
    this.onArtifactAction,
    this.productAssetRepository,
    this.citations = const <AgentCitationView>[],
    this.parseMarkdown = true,
  });

  final String text;
  final TextStyle? style;
  final AgentArtifactActionHandler? onArtifactAction;
  final ProductAssetRepository? productAssetRepository;
  final List<AgentCitationView> citations;
  final bool parseMarkdown;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trim();
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    if (!parseMarkdown) {
      return Text(normalized, style: baseStyle);
    }
    final preparedMarkdown = _prepareAgentMarkdown(
      replaceCitationLinksWithIndexes(normalized, citations),
    );
    final hospitalBagCartUrl = _firstHospitalBagCartPreviewUrl(
      preparedMarkdown,
    );
    final markdown = hospitalBagCartUrl == null
        ? preparedMarkdown
        : _stripHospitalBagCartPreviewLinks(preparedMarkdown);
    final markdownBody = markdown.trim().isEmpty
        ? null
        : !_containsMarkdown(markdown)
        ? Text(markdown, style: baseStyle)
        : MarkdownBody(
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
                repository: productAssetRepository,
                onTap: () => _openMarkdownMedia(url: url, title: alt ?? title),
              );
            },
            onTapLink: (label, href, title) {
              final url = href?.trim();
              if (url == null || url.isEmpty) return;
              if (_isHospitalBagCartPath(url)) {
                onArtifactAction?.call(AgentArtifactActions.hospitalBagCart);
                return;
              }
              if (_openMarkdownMedia(url: url, title: label.trim())) return;
              final target = SafeLinkTarget.tryParse(url);
              if (target == null) return;
              onArtifactAction?.call(
                AgentArtifactActionView(
                  label: label.trim().isEmpty ? '打开链接' : label.trim(),
                  icon: Icons.open_in_new_rounded,
                  kind: 'link',
                  value: url,
                  routePath: target.internalPath,
                  externalUri: target.externalUri,
                ),
              );
            },
          );

    if (hospitalBagCartUrl == null) {
      return markdownBody ?? Text('', style: baseStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?markdownBody,
        if (markdownBody != null) const SizedBox(height: 8),
        _AgentHospitalBagCartPreview(
          onTap: onArtifactAction == null
              ? null
              : () => onArtifactAction!(AgentArtifactActions.hospitalBagCart),
        ),
      ],
    );
  }

  bool _openMarkdownMedia({required String url, String? title}) {
    final kind = _viewerKindForUrl(url);
    if (kind == null) return false;
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
    return true;
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

class _AgentHospitalBagCartPreview extends StatelessWidget {
  const _AgentHospitalBagCartPreview({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '打开待产包购物车',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('agent-hospital-bag-cart-preview'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xfffff9fb),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe8d7df)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14532f40),
                  blurRadius: 22,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 92),
                child: Stack(
                  children: [
                    const Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xff24889a), Color(0xffd86b91)],
                          ),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 80),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MOMCOZY CART',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    semanticsLabel: 'Momcozy Cart',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: const Color(0xff8a6d7a),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '待产包母婴用品一键打包',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelMedium?.copyWith(
                                      color: const Color(0xff372330),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '已把妈妈护理、宝宝出院和母乳喂养用品整理成购物车，方便一起核对下单。',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: const Color(0xff725b67),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      height: 1.3,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xff24889a),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentMarkdownImage extends StatelessWidget {
  const _AgentMarkdownImage({
    required this.url,
    this.title,
    this.repository,
    this.onTap,
  });

  final String url;
  final String? title;
  final ProductAssetRepository? repository;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = title?.trim().isNotEmpty == true ? title!.trim() : '查看图片';
    final productAsset = ProductAssetReference.tryParse(
      url,
      kind: ProductAssetKind.image.routeValue,
      title: label,
    );
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
            child: productAsset != null
                ? ProductAssetImage(
                    reference: productAsset,
                    repository: repository,
                    fit: BoxFit.contain,
                    semanticLabel: label,
                    loadingBuilder: (context) {
                      return _AgentMarkdownImagePlaceholder(
                        label: label,
                        loading: true,
                      );
                    },
                    errorBuilder: (context, error, retry) {
                      return _AgentMarkdownImagePlaceholder(
                        label: label,
                        onRetry: retry,
                      );
                    },
                  )
                : displayUrl == null
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
  const _AgentMarkdownImagePlaceholder({
    required this.label,
    this.loading = false,
    this.onRetry,
  });

  final String label;
  final bool loading;
  final VoidCallback? onRetry;

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
            const SizedBox(height: 6),
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (onRetry != null)
              IconButton(
                key: ValueKey('agent-markdown-image-retry-$label'),
                tooltip: '重新加载',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: MomCozyColors.mutedForeground,
                visualDensity: VisualDensity.compact,
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
  final productAsset = ProductAssetReference.tryParse(url);
  if (productAsset != null) return productAsset.kind.routeValue;
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

String? _firstHospitalBagCartPreviewUrl(String markdown) {
  for (final match in _hospitalBagCartMarkdownLinkPattern.allMatches(
    markdown,
  )) {
    final url = match.group(1)?.trim();
    if (url != null && _isHospitalBagCartPath(url)) return url;
  }
  for (final match in _hospitalBagCartBareUrlPattern.allMatches(markdown)) {
    final url = match.group(0)?.trim();
    if (url != null && _isHospitalBagCartPath(url)) return url;
  }
  return null;
}

String _stripHospitalBagCartPreviewLinks(String markdown) {
  final withoutStandaloneLines = markdown
      .split('\n')
      .where((line) => !_isStandaloneHospitalBagCartLinkLine(line))
      .join('\n');
  final withoutMarkdownLinks = withoutStandaloneLines.replaceAllMapped(
    _hospitalBagCartMarkdownLinkPattern,
    (match) {
      final url = match.group(1)?.trim();
      return url != null && _isHospitalBagCartPath(url)
          ? ''
          : match.group(0) ?? '';
    },
  );
  return withoutMarkdownLinks
      .replaceAllMapped(_hospitalBagCartBareUrlPattern, (match) {
        final url = match.group(0)?.trim();
        return url != null && _isHospitalBagCartPath(url)
            ? ''
            : match.group(0) ?? '';
      })
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

bool _isStandaloneHospitalBagCartLinkLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return false;
  final markdownMatch = _standaloneHospitalBagCartMarkdownLinkPattern
      .firstMatch(trimmed);
  final markdownUrl = markdownMatch?.group(1)?.trim();
  if (markdownUrl != null && _isHospitalBagCartPath(markdownUrl)) return true;
  final bareMatch = _standaloneHospitalBagCartBareUrlPattern.firstMatch(
    trimmed,
  );
  final bareUrl = bareMatch?.group(1)?.trim();
  return bareUrl != null && _isHospitalBagCartPath(bareUrl);
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
final _hospitalBagCartMarkdownLinkPattern = RegExp(
  r'''(?:[*_]{1,3})?\s*\[[^\]\n]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)\s*(?:[*_]{1,3})?''',
);
final _standaloneHospitalBagCartMarkdownLinkPattern = RegExp(
  r'''^(?:[*_]{1,3})?\s*\[[^\]\n]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)\s*(?:[*_]{1,3})?$''',
);
final _hospitalBagCartBareUrlPattern = RegExp(
  r'(?:https?://[^\s)]+|/hospital-bag-cart(?:[?#][^\s)]*)?)',
  caseSensitive: false,
);
final _standaloneHospitalBagCartBareUrlPattern = RegExp(
  r'^(?:[*_]{1,3})?\s*((?:https?://[^\s)]+|/hospital-bag-cart(?:[?#][^\s)]*)?))\s*(?:[*_]{1,3})?$',
  caseSensitive: false,
);

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
    final title = widget.title;

    return Semantics(
      label: title,
      child: Container(
        key: const ValueKey('agent-run-status-line'),
        constraints: const BoxConstraints(maxWidth: double.infinity),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _AgentSweepText(
          title,
          sweepKey: const ValueKey('agent-run-status-title-sweep'),
          animation: _sweepController,
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
  static const _sweepDuration = Duration(milliseconds: 640);

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
        padding: EdgeInsets.zero,
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
      _AgentAssistantAvatarMode.speaking => MomCozyAssets.agentSpeakingAvatar,
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
    final videoController = mode == null ? null : _videoControllers[mode];
    final videoReady = mode != null && _videoReadyModes.contains(mode);

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
        ],
      ),
    );
  }
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
    this.focusNode,
    required this.canSend,
    required this.isRunning,
    required this.isInputLocked,
    required this.images,
    required this.files,
    required this.canAttachImage,
    required this.canAttachFile,
    required this.isAttachmentPending,
    required this.canUseVoice,
    required this.voicePhase,
    this.voicePlaybackFailed = false,
    required this.onChanged,
    required this.onSend,
    required this.onCancel,
    required this.onTakePhoto,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onRemoveImage,
    required this.onRemoveFile,
    required this.onVoiceStart,
    required this.onVoiceEnd,
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
  final bool canUseVoice;
  final AgentVoicePhase voicePhase;
  final bool voicePlaybackFailed;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final ValueChanged<int> onRemoveImage;
  final ValueChanged<int> onRemoveFile;
  final VoidCallback onVoiceStart;
  final ValueChanged<bool> onVoiceEnd;

  @override
  State<AgentComposerBar> createState() => _AgentComposerBarState();
}

class _AgentComposerBarState extends State<AgentComposerBar> {
  static const double _controlSize = 32;
  static const double _attachmentControlSize = 40;
  static const double _surfaceMinHeight = 48;
  static const double _surfaceHorizontalInset = 12;
  static const double _surfaceVerticalInset = 8;
  static const double _controlGap = 8;
  static const double _inputLeftInset =
      _surfaceHorizontalInset + _attachmentControlSize + _controlGap;
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
    widget.onVoiceStart();
  }

  void _finishVoiceHold({required bool submit}) {
    if (!_voicePressed) return;
    setState(() {
      _voicePressed = false;
      _voiceMode = false;
      _textDraftBeforeVoice = null;
    });
    widget.onVoiceEnd(submit);
  }

  Widget _attachmentMenuItem({
    required Key key,
    required String label,
    required IconData icon,
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
        minimumSize: const Size(220, 60),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: MomCozyColors.muted,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(icon, size: 24, color: MomCozyColors.foreground),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: MomCozyTypography.fontFamily,
              fontFamilyFallback: MomCozyTypography.fontFamilyFallback,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: MomCozyColors.foreground,
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
    final canUseVoice = widget.canUseVoice;
    final voicePhase = widget.voicePhase;
    final onChanged = widget.onChanged;
    final onSend = widget.onSend;
    final onCancel = widget.onCancel;
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
            if (imageCount > 0) ...[
              SizedBox(
                key: const ValueKey('agent-image-attachment-chip'),
                height: 78,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '图片 $imageCount',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: MomCozyColors.mutedForeground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageCount,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return AgentComposerImageAttachment(
                            key: ValueKey('agent-image-attachment-$index'),
                            image: images[index],
                            removeButtonKey: ValueKey(
                              index == 0
                                  ? 'agent-remove-image-button'
                                  : 'agent-remove-image-$index',
                            ),
                            onRemove: isInputLocked
                                ? null
                                : () => widget.onRemoveImage(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (fileCount > 0) ...[
              SizedBox(
                key: const ValueKey('agent-file-attachment-chip'),
                height: 78,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '文件 $fileCount',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: MomCozyColors.mutedForeground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: fileCount,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return AgentComposerFileAttachment(
                            key: ValueKey('agent-file-attachment-$index'),
                            file: files[index],
                            removeButtonKey: ValueKey(
                              index == 0
                                  ? 'agent-remove-file-button'
                                  : 'agent-remove-file-$index',
                            ),
                            onRemove: isInputLocked
                                ? null
                                : () => widget.onRemoveFile(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                          child: MenuAnchor(
                            controller: _attachmentMenuController,
                            consumeOutsideTap: true,
                            alignmentOffset: const Offset(-12, -8),
                            style: MenuStyle(
                              backgroundColor: const WidgetStatePropertyAll(
                                MomCozyColors.card,
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.all(8),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: MomCozyColors.border.withValues(
                                      alpha: 0.62,
                                    ),
                                  ),
                                ),
                              ),
                              elevation: const WidgetStatePropertyAll(12),
                              shadowColor: WidgetStatePropertyAll(
                                const Color(0xff754c5e).withValues(alpha: 0.2),
                              ),
                            ),
                            menuChildren: [
                              SizedBox(
                                key: const ValueKey('agent-attachment-menu'),
                                width: 228,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _attachmentMenuItem(
                                      key: const ValueKey(
                                        'agent-attachment-camera-button',
                                      ),
                                      label: '相机',
                                      icon: Icons.photo_camera_outlined,
                                      onPressed: canAttachImage
                                          ? widget.onTakePhoto
                                          : null,
                                    ),
                                    _attachmentMenuItem(
                                      key: const ValueKey(
                                        'agent-attachment-photo-button',
                                      ),
                                      label: '照片',
                                      icon: Icons.photo_library_outlined,
                                      onPressed: canAttachImage
                                          ? widget.onPickPhoto
                                          : null,
                                    ),
                                    _attachmentMenuItem(
                                      key: const ValueKey(
                                        'agent-attachment-file-button',
                                      ),
                                      label: '文件',
                                      icon: Icons.attach_file_rounded,
                                      onPressed: canAttachFile
                                          ? widget.onPickFile
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            builder: (context, menuController, child) {
                              final canOpenMenu =
                                  canAttachImage || canAttachFile;
                              return IconButton(
                                key: const ValueKey('agent-attachment-button'),
                                onPressed:
                                    canOpenMenu && !widget.isAttachmentPending
                                    ? () {
                                        if (menuController.isOpen) {
                                          menuController.close();
                                        } else {
                                          menuController.open();
                                        }
                                      }
                                    : null,
                                icon: widget.isAttachmentPending
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded, size: 28),
                                tooltip: '添加附件',
                                color: MomCozyColors.foreground,
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

bool _artifactProjectionChanged(
  AgentStreamRunState previous,
  AgentStreamRunState next,
) {
  if (!identical(previous.artifactEvents, next.artifactEvents)) return true;
  if (!identical(previous.events, next.events) &&
      next.events.length > previous.events.length) {
    return next.events
        .skip(previous.events.length)
        .any((event) => event.type.startsWith('artifact.'));
  }
  return false;
}

bool _hasNewHospitalBagCartChangedEvent(
  AgentStreamRunState previous,
  AgentStreamRunState next,
) {
  if (identical(previous.events, next.events) ||
      next.events.length <= previous.events.length) {
    return false;
  }
  return next.events
      .skip(previous.events.length)
      .any((event) => event.type == 'hospital_bag.cart.changed');
}

bool _hasServerRunSignal(AgentStreamRunState state) {
  return state.runId?.trim().isNotEmpty == true ||
      state.lastSequence != null ||
      state.events.isNotEmpty ||
      state.textContent.isNotEmpty ||
      state.provisionalTextContent.isNotEmpty;
}

Iterable<AgentStreamEvent> _artifactEventsForState(AgentStreamRunState state) {
  return state.artifactEvents.isNotEmpty
      ? state.artifactEvents.values
      : state.events;
}

Set<String> _formArtifactIdsForState(AgentStreamRunState state) {
  return _artifactCardsFromEvents(
    _artifactEventsForState(state),
  ).where((card) => card.isForm).map((card) => card.id).toSet();
}

String? _latestVisibleArtifactId(AgentStreamRunState state) {
  if (!state.canPublishArtifactEvents) return null;
  final canShowForms =
      state.hasCompletedAssistantMessage ||
      (!state.isActive && state.textContent.trim().isNotEmpty);
  for (final card in _artifactCardsFromEvents(
    _artifactEventsForState(state),
  ).reversed) {
    if (!card.isForm || canShowForms) return card.id;
  }
  return null;
}

Iterable<AgentStreamEvent> _actionEventsForState(AgentStreamRunState state) {
  final timeline = state.events
      .where((event) => event.type.startsWith('action.'))
      .toList(growable: false);
  return userVisibleAgentActionEvents(
    timeline.isNotEmpty ? timeline : state.actionEvents.values,
  );
}

List<AgentArtifactCardView> _artifactCardsFromEvents(
  Iterable<AgentStreamEvent> events, {
  BirthPrepProfileDefaults profileDefaults = const BirthPrepProfileDefaults(),
}) {
  return AgentArtifactMapper.cardsFromEvents(
    events,
    profileDefaults: profileDefaults,
  );
}

List<AgentActionCardView> _actionCardsFromEvents(
  Iterable<AgentStreamEvent> events,
  Map<String, String> localStatuses,
) {
  final cards = <String, AgentActionCardView>{};
  for (final event in userVisibleAgentActionEvents(events)) {
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
  for (final event in events.reversed) {
    if (event.semantic.isNotEmpty) {
      final semanticTitle = _semanticStatusTitle(event);
      if (semanticTitle != null) return semanticTitle;
      if (_eventStopsAgentLoopDecor(event)) return null;
      continue;
    }
    if (_eventStopsAgentLoopDecor(event)) return null;

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
            '我想一下';
      }
      if (phase == 'model_reasoning_after_tool') {
        return _visibleAgentStatusTitle(
              _firstNonEmpty([
                _stringField(event.payload, 'label'),
                _stringField(event.payload, 'message'),
              ]),
            ) ??
            '我想一下';
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
    'context_loading' => '我已经收到你的消息啦～',
    'context_ready' => '我先理解一下你的需求～',
    'model_followup' => '我接着处理下一步',
    'response_finalizing' => '我在组织回复～',
    'quick_replies_preparing' => '我在帮你准备下一轮的快捷输入～',
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
