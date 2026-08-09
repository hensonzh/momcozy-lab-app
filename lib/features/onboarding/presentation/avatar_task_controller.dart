import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

enum AvatarTaskStatus {
  hidden,
  queued,
  generating,
  reviewRequired,
  failed,
  completed,
}

class AvatarTaskController extends ChangeNotifier {
  AvatarTaskController({
    required this.onboardingController,
    this.pollInterval = const Duration(seconds: 5),
    this.completionDisplayDuration = const Duration(seconds: 2),
  }) {
    onboardingController.addListener(_handleOnboardingChanged);
    _status = _statusFor(onboardingController.state);
    _generationId = onboardingController.state?.avatar?.id;
    _schedulePollIfNeeded();
  }

  final OnboardingController onboardingController;
  final Duration pollInterval;
  final Duration completionDisplayDuration;
  AvatarTaskStatus _status = AvatarTaskStatus.hidden;
  String? _generationId;
  Timer? _pollTimer;
  Timer? _completionTimer;
  bool _foreground = true;
  bool _disposed = false;

  AvatarTaskStatus get status => _status;
  String? get generationId => _generationId;
  bool get isVisible => _status != AvatarTaskStatus.hidden;

  Future<void> refresh() => onboardingController.load(silent: true);

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (!value) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    unawaited(refresh());
    _schedulePollIfNeeded();
  }

  void _handleOnboardingChanged() {
    final state = onboardingController.state;
    final next = _statusFor(state);
    final previous = _status;
    final completedTransition =
        _isPending(previous) && state?.avatarSetupCompleted == true;

    if (completedTransition) {
      _status = AvatarTaskStatus.completed;
      _completionTimer?.cancel();
      _completionTimer = Timer(completionDisplayDuration, _hideCompletion);
    } else if (!(_status == AvatarTaskStatus.completed &&
        _completionTimer?.isActive == true &&
        next == AvatarTaskStatus.hidden)) {
      _status = next;
    }
    _generationId = state?.avatar?.id;
    _schedulePollIfNeeded();
    if (previous != _status || completedTransition) _notify();
  }

  AvatarTaskStatus _statusFor(OnboardingState? state) {
    if (state == null || !state.canEnterApp || state.avatarSetupCompleted) {
      return AvatarTaskStatus.hidden;
    }
    return switch (state.status) {
      OnboardingStatus.avatarGenerating =>
        state.avatar?.phase == OnboardingAvatarGenerationPhase.queued
            ? AvatarTaskStatus.queued
            : AvatarTaskStatus.generating,
      OnboardingStatus.avatarReview => AvatarTaskStatus.reviewRequired,
      OnboardingStatus.avatarFailed => AvatarTaskStatus.failed,
      _ => AvatarTaskStatus.hidden,
    };
  }

  bool _isPending(AvatarTaskStatus value) => switch (value) {
    AvatarTaskStatus.queued ||
    AvatarTaskStatus.generating ||
    AvatarTaskStatus.reviewRequired ||
    AvatarTaskStatus.failed => true,
    AvatarTaskStatus.hidden || AvatarTaskStatus.completed => false,
  };

  void _schedulePollIfNeeded() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!_foreground ||
        (_status != AvatarTaskStatus.queued &&
            _status != AvatarTaskStatus.generating)) {
      return;
    }
    _pollTimer = Timer(pollInterval, () async {
      await refresh();
    });
  }

  void _hideCompletion() {
    if (_status != AvatarTaskStatus.completed) return;
    _status = AvatarTaskStatus.hidden;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _completionTimer?.cancel();
    onboardingController.removeListener(_handleOnboardingChanged);
    super.dispose();
  }
}
