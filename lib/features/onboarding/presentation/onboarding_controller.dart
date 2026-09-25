import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/text/english_error_text.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

enum OnboardingGatePhase { idle, loading, ready, failure }

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.runtimeController,
    this.onPrimaryInfantSelected,
    this.onAvatarActivated,
    this.releasePolicy = const NoopOnboardingReleasePolicy(),
  }) {
    runtimeController.addListener(_handleRuntimeChanged);
    _handleRuntimeChanged();
  }

  final MomCozyRuntimeController runtimeController;
  final Future<void> Function(String infantId)? onPrimaryInfantSelected;
  final ValueChanged<String?>? onAvatarActivated;
  final OnboardingReleasePolicy releasePolicy;
  OnboardingGatePhase _phase = OnboardingGatePhase.idle;
  OnboardingState? _state;
  String? _loadedUserId;
  String _errorMessage = '';
  bool _busy = false;
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
      isResolvedFor(userId) && !(_state?.canEnterApp ?? false);

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
      _loadedUserId = null;
      _state = null;
      _clearAvatarSelection();
      _phase = OnboardingGatePhase.idle;
      _errorMessage = '';
      _notify();
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
      await _markReleaseCompletedIfNeeded(userId, next);
      _applyState(next);
      _phase = OnboardingGatePhase.ready;
      _errorMessage = '';
    } catch (error) {
      if (runtimeController.currentSession.userId != userId) return;
      _errorMessage = _messageFor(error);
      _phase = silent && _state != null
          ? OnboardingGatePhase.ready
          : OnboardingGatePhase.failure;
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
      final next = await _repository.generateAvatar(fileId);
      await _markReleaseCompletedIfNeeded(
        runtimeController.currentSession.userId,
        next,
      );
      _applyState(next);
    });
  }

  void selectAvatarCandidate(String candidateId) {
    final normalized = candidateId.trim();
    final candidates = _state?.pendingAvatar?.candidates ?? const [];
    if (_state?.pendingAvatar?.status != OnboardingStatus.avatarReview ||
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

  Future<bool> dismissPendingAvatar() {
    return _run(() async {
      _applyState(await _repository.dismissPendingAvatar());
      _phase = OnboardingGatePhase.ready;
    });
  }

  Future<bool> _complete(Future<OnboardingState> Function() action) async {
    final userId = runtimeController.currentSession.userId;
    final succeeded = await _run(() async {
      final next = await action();
      await _markReleaseCompletedIfNeeded(userId, next);
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
    try {
      // Baby selection can replace the account runtime and its scoped caches,
      // so publish the avatar only after that transition has completed.
      onAvatarActivated?.call(_state?.activeAvatarFileId);
    } catch (_) {
      // The server selection is authoritative; local projections can refresh
      // again when their page is next opened.
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

  Future<void> _markReleaseCompletedIfNeeded(
    String userId,
    OnboardingState next,
  ) async {
    if (!next.canEnterApp) return;
    try {
      if (await releasePolicy.requiresResetFor(userId)) {
        await releasePolicy.markCompletedFor(userId);
      }
    } catch (_) {
      // Cloud onboarding state is authoritative. A failed local marker can
      // retry on the next load without blocking an already accepted job.
    }
  }

  void _applyState(OnboardingState next) {
    final previousGenerationId = _state?.pendingAvatar?.id;
    _state = next;
    final candidates = next.pendingAvatar?.candidates ?? const [];
    final selectionIsStillValid =
        next.pendingAvatar?.status == OnboardingStatus.avatarReview &&
        previousGenerationId == next.pendingAvatar?.id &&
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

  String _messageFor(Object error) {
    if (error is ApiHttpException) {
      return englishErrorText(
        error.errorMessage,
        fallback: 'We could not save that. Please try again.',
      );
    }
    if (error is FormatException) {
      return englishErrorText(
        error.message,
        fallback: 'We could not save that. Please try again.',
      );
    }
    return 'Something went wrong. Check your connection and try again.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    runtimeController.removeListener(_handleRuntimeChanged);
    super.dispose();
  }
}
