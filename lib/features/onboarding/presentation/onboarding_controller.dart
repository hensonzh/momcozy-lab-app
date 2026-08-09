import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

enum OnboardingGatePhase { idle, loading, ready, failure }

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.runtimeController,
    this.onPrimaryInfantSelected,
    this.releasePolicy = const NoopOnboardingReleasePolicy(),
  }) {
    runtimeController.addListener(_handleRuntimeChanged);
    _handleRuntimeChanged();
  }

  final MomCozyRuntimeController runtimeController;
  final Future<void> Function(String infantId)? onPrimaryInfantSelected;
  final OnboardingReleasePolicy releasePolicy;
  OnboardingGatePhase _phase = OnboardingGatePhase.idle;
  OnboardingState? _state;
  String? _loadedUserId;
  String _errorMessage = '';
  bool _busy = false;
  Timer? _pollTimer;
  bool _disposed = false;
  String? _resetUserId;
  String? _resetReleaseId;
  Future<void>? _resetInFlight;
  String? _resetInFlightUserId;
  String? _selectedAvatarCandidateId;
  bool _defaultAvatarSelected = false;

  OnboardingGatePhase get phase => _phase;
  OnboardingState? get state => _state;
  String get errorMessage => _errorMessage;
  bool get busy => _busy;
  String? get loadedUserId => _loadedUserId;
  String? get selectedAvatarCandidateId => _selectedAvatarCandidateId;
  bool get defaultAvatarSelected => _defaultAvatarSelected;
  bool get hasAvatarSelection =>
      _selectedAvatarCandidateId != null || _defaultAvatarSelected;

  bool isResolvedFor(String userId) =>
      _loadedUserId == userId && _phase == OnboardingGatePhase.ready;

  bool requiresOnboardingFor(String userId) =>
      isResolvedFor(userId) && !(_state?.isCompleted ?? false);

  OnboardingApiRepository get _repository {
    final runtime = runtimeController.runtime;
    return OnboardingApiRepository(
      transport: runtime.jsonTransport,
      multipartTransport: runtime.multipartTransport,
    );
  }

  void _handleRuntimeChanged() {
    final session = runtimeController.currentSession;
    if (!session.isAuthenticated) {
      _pollTimer?.cancel();
      _clearResetTracking();
      _loadedUserId = null;
      _state = null;
      _clearAvatarSelection();
      _phase = OnboardingGatePhase.idle;
      _notify();
      return;
    }
    if (_loadedUserId != null && _loadedUserId != session.userId) {
      _clearResetTracking();
    }
    if (_loadedUserId == session.userId && _phase != OnboardingGatePhase.idle) {
      return;
    }
    unawaited(load());
  }

  Future<void> load({bool silent = false}) async {
    final session = runtimeController.currentSession;
    if (!session.isAuthenticated) return;
    final userId = session.userId;
    _loadedUserId = userId;
    if (!silent) {
      _phase = OnboardingGatePhase.loading;
      _errorMessage = '';
      _notify();
    }
    try {
      final repository = _repository;
      await _ensureReleaseReset(userId, repository);
      if (runtimeController.currentSession.userId != userId) return;
      final next = await repository.fetchState();
      if (runtimeController.currentSession.userId != userId) return;
      if (next.isCompleted && await releasePolicy.requiresResetFor(userId)) {
        await releasePolicy.markCompletedFor(userId);
      }
      _applyState(next);
      _phase = OnboardingGatePhase.ready;
      _errorMessage = '';
      _schedulePollIfNeeded();
    } catch (error) {
      if (runtimeController.currentSession.userId != userId) return;
      _phase = OnboardingGatePhase.failure;
      _errorMessage = _messageFor(error);
    }
    _notify();
  }

  Future<bool> confirmProfile(OnboardingProfileDraft draft) async {
    return _run(() async {
      _applyState(await _repository.confirmProfile(draft));
      _phase = OnboardingGatePhase.ready;
    });
  }

  Future<bool> uploadAndGenerate(OnboardingPortrait portrait) async {
    return _run(() async {
      final fileId = await _repository.uploadPortrait(portrait);
      _applyState(await _repository.generateAvatar(fileId));
      _schedulePollIfNeeded();
    });
  }

  void selectAvatarCandidate(String candidateId) {
    final normalized = candidateId.trim();
    final candidates = _state?.avatar?.candidates ?? const [];
    if (_state?.status != OnboardingStatus.avatarReview ||
        !candidates.any((candidate) => candidate.id == normalized)) {
      return;
    }
    if (_selectedAvatarCandidateId == normalized && !_defaultAvatarSelected) {
      return;
    }
    _selectedAvatarCandidateId = normalized;
    _defaultAvatarSelected = false;
    _notify();
  }

  void selectDefaultAvatar() {
    if (!(_state?.canContinueWithDefault ?? false)) return;
    if (_defaultAvatarSelected && _selectedAvatarCandidateId == null) return;
    _selectedAvatarCandidateId = null;
    _defaultAvatarSelected = true;
    _notify();
  }

  Future<bool> confirmAvatarSelection() {
    if (_defaultAvatarSelected) return completeWithDefaultAvatar();
    final candidateId = _selectedAvatarCandidateId;
    if (candidateId == null || candidateId.isEmpty) {
      return Future.value(false);
    }
    return _complete(() => _repository.completeWithAvatar(candidateId));
  }

  Future<bool> completeWithDefaultAvatar() {
    return _complete(_repository.completeWithDefault);
  }

  Future<bool> _complete(Future<OnboardingState> Function() action) async {
    final userId = runtimeController.currentSession.userId;
    final succeeded = await _run(() async {
      final next = await action();
      if (next.isCompleted) await releasePolicy.markCompletedFor(userId);
      _applyState(next);
      _phase = OnboardingGatePhase.ready;
    });
    if (!succeeded) return false;
    final infantId = _state?.primaryInfantId;
    if (infantId != null && infantId.isNotEmpty) {
      try {
        await onPrimaryInfantSelected?.call(infantId);
      } catch (_) {
        // Completion is authoritative on the server; baby selection can recover
        // from the returned primary id on the next session refresh.
      }
    }
    _notify();
    return true;
  }

  Future<void> _ensureReleaseReset(
    String userId,
    OnboardingApiRepository repository,
  ) async {
    if (_resetUserId == userId && _resetReleaseId == releasePolicy.releaseId) {
      return;
    }
    if (!await releasePolicy.requiresResetFor(userId)) return;

    final pending = _resetInFlight;
    if (pending != null && _resetInFlightUserId == userId) {
      await pending;
      return;
    }
    final reset = repository
        .resetForRelease(releasePolicy.releaseId)
        .then<void>((_) {});
    _resetInFlight = reset;
    _resetInFlightUserId = userId;
    try {
      await reset;
      if (runtimeController.currentSession.userId == userId) {
        _resetUserId = userId;
        _resetReleaseId = releasePolicy.releaseId;
      }
    } finally {
      if (identical(_resetInFlight, reset)) {
        _resetInFlight = null;
        _resetInFlightUserId = null;
      }
    }
  }

  void _clearResetTracking() {
    _resetUserId = null;
    _resetReleaseId = null;
    _resetInFlight = null;
    _resetInFlightUserId = null;
  }

  void _applyState(OnboardingState next) {
    final previousGenerationId = _state?.avatar?.id;
    _state = next;
    final candidates = next.avatar?.candidates ?? const [];
    final selectionIsStillValid =
        next.status == OnboardingStatus.avatarReview &&
        previousGenerationId == next.avatar?.id &&
        (_selectedAvatarCandidateId == null ||
            candidates.any(
              (candidate) => candidate.id == _selectedAvatarCandidateId,
            ));
    if (!selectionIsStillValid) _clearAvatarSelection();
  }

  void _clearAvatarSelection() {
    _selectedAvatarCandidateId = null;
    _defaultAvatarSelected = false;
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = '';
    _notify();
    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void clearError() {
    if (_errorMessage.isEmpty) return;
    _errorMessage = '';
    _notify();
  }

  void _schedulePollIfNeeded() {
    _pollTimer?.cancel();
    if (_state?.status != OnboardingStatus.avatarGenerating) return;
    _pollTimer = Timer(const Duration(seconds: 2), () async {
      await load(silent: true);
    });
  }

  String _messageFor(Object error) {
    if (error is ApiHttpException) {
      return error.errorMessage ?? 'We could not save that. Please try again.';
    }
    if (error is FormatException) return error.message;
    return 'Something went wrong. Check your connection and try again.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    runtimeController.removeListener(_handleRuntimeChanged);
    super.dispose();
  }
}
