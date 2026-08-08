import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

enum OnboardingGatePhase { idle, loading, ready, failure }

class OnboardingController extends ChangeNotifier {
  OnboardingController({
    required this.runtimeController,
    this.onPrimaryInfantSelected,
  }) {
    runtimeController.addListener(_handleRuntimeChanged);
    _handleRuntimeChanged();
  }

  final MomCozyRuntimeController runtimeController;
  final Future<void> Function(String infantId)? onPrimaryInfantSelected;
  OnboardingGatePhase _phase = OnboardingGatePhase.idle;
  OnboardingState? _state;
  String? _loadedUserId;
  String _errorMessage = '';
  bool _busy = false;
  Timer? _pollTimer;
  bool _disposed = false;

  OnboardingGatePhase get phase => _phase;
  OnboardingState? get state => _state;
  String get errorMessage => _errorMessage;
  bool get busy => _busy;
  String? get loadedUserId => _loadedUserId;

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
      _loadedUserId = null;
      _state = null;
      _phase = OnboardingGatePhase.idle;
      _notify();
      return;
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
      final next = await _repository.fetchState();
      if (runtimeController.currentSession.userId != userId) return;
      _state = next;
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
      _state = await _repository.confirmProfile(draft);
      _phase = OnboardingGatePhase.ready;
    });
  }

  Future<bool> uploadAndGenerate(OnboardingPortrait portrait) async {
    return _run(() async {
      final fileId = await _repository.uploadPortrait(portrait);
      _state = await _repository.generateAvatar(fileId);
      _schedulePollIfNeeded();
    });
  }

  Future<bool> completeWithGeneratedAvatar() async {
    final generationId = _state?.avatar?.id;
    if (generationId == null || generationId.isEmpty) return false;
    return _complete(() => _repository.completeWithAvatar(generationId));
  }

  Future<bool> completeWithDefaultAvatar() {
    return _complete(_repository.completeWithDefault);
  }

  Future<bool> _complete(Future<OnboardingState> Function() action) async {
    final succeeded = await _run(() async {
      _state = await action();
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
