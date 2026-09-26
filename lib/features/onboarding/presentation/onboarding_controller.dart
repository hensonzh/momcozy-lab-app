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
  bool _disposed = false;
  String? _resetUserId;
  String? _resetReleaseId;
  Future<void>? _resetInFlight;
  String? _resetInFlightUserId;

  OnboardingGatePhase get phase => _phase;
  OnboardingState? get state => _state;
  String get errorMessage => _errorMessage;
  bool get busy => _busy;
  String? get loadedUserId => _loadedUserId;
  bool isResolvedFor(String userId) =>
      _loadedUserId == userId && _phase == OnboardingGatePhase.ready;

  bool requiresOnboardingFor(String userId) =>
      isResolvedFor(userId) && !(_state?.canEnterApp ?? false);

  OnboardingApiRepository get _repository {
    final runtime = runtimeController.runtime;
    return OnboardingApiRepository(transport: runtime.jsonTransport);
  }

  void _handleRuntimeChanged() {
    final session = runtimeController.currentSession;
    if (!session.isAuthenticated) {
      _clearResetTracking();
      _loadedUserId = null;
      _state = null;
      _phase = OnboardingGatePhase.idle;
      _notify();
      return;
    }
    if (_loadedUserId != null && _loadedUserId != session.userId) {
      _clearResetTracking();
      _loadedUserId = null;
      _state = null;
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
    final userId = runtimeController.currentSession.userId;
    final succeeded = await _run(() async {
      final next = await _repository.confirmProfile(draft);
      if (!next.profileConfirmed) {
        throw const FormatException('Profile confirmation was not accepted.');
      }
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
        // The confirmed profile remains authoritative; selection can recover.
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
    _state = next;
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
