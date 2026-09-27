/// Backend-dependent product capabilities that are safe to opt into per build.
class MomCozyAppCapabilities {
  const MomCozyAppCapabilities({
    this.onboardingGateEnabled = true,
    this.releaseResetEnabled = false,
    this.extendedProductApiEnabled = false,
  });

  const MomCozyAppCapabilities.fromEnvironment()
    : onboardingGateEnabled = const bool.fromEnvironment(
        'MOMCOZY_ENABLE_ONBOARDING',
        defaultValue: true,
      ),
      releaseResetEnabled = const bool.fromEnvironment(
        'MOMCOZY_ENABLE_RELEASE_RESET',
        defaultValue: false,
      ),
      extendedProductApiEnabled = const bool.fromEnvironment(
        'MOMCOZY_ENABLE_EXTENDED_PRODUCT_API',
        defaultValue: false,
      );

  final bool onboardingGateEnabled;
  final bool releaseResetEnabled;
  final bool extendedProductApiEnabled;

  /// Resetting onboarding/session state is meaningful only when onboarding is
  /// part of this build. Keeping the conjunction here prevents callers from
  /// accidentally enabling a destructive startup action with one flag alone.
  bool get releaseResetLifecycleEnabled =>
      onboardingGateEnabled && releaseResetEnabled;

  bool isRouteEnabled(String path) {
    if (path == '/motion-assessment') {
      return extendedProductApiEnabled;
    }
    return true;
  }
}
