import 'package:flutter/foundation.dart';
import 'package:momcozy_flutter_app/features/body_profile/domain/body_profile.dart';

enum BodyProfilePhase { initial, loading, data, saving, error }

class BodyProfileState {
  const BodyProfileState({
    this.phase = BodyProfilePhase.initial,
    this.profile,
    this.error,
  });

  final BodyProfilePhase phase;
  final BodyProfile? profile;
  final Object? error;

  bool get isBusy =>
      phase == BodyProfilePhase.loading || phase == BodyProfilePhase.saving;
}

class BodyProfileController extends ValueNotifier<BodyProfileState> {
  BodyProfileController({required this.repository})
    : super(const BodyProfileState());

  final BodyProfileRepository repository;

  Future<void> load() async {
    if (value.phase == BodyProfilePhase.loading) return;
    final previous = value.profile;
    value = BodyProfileState(
      phase: BodyProfilePhase.loading,
      profile: previous,
    );
    try {
      final profile = await repository.fetchProfile();
      value = BodyProfileState(phase: BodyProfilePhase.data, profile: profile);
    } catch (error) {
      value = BodyProfileState(
        phase: BodyProfilePhase.error,
        profile: previous,
        error: error,
      );
    }
  }

  Future<bool> save(BodyProfile profile) async {
    if (value.phase == BodyProfilePhase.saving) return false;
    value = BodyProfileState(phase: BodyProfilePhase.saving, profile: profile);
    try {
      final saved = await repository.saveProfile(profile);
      value = BodyProfileState(phase: BodyProfilePhase.data, profile: saved);
      return true;
    } catch (error) {
      value = BodyProfileState(
        phase: BodyProfilePhase.error,
        profile: profile,
        error: error,
      );
      return false;
    }
  }
}
