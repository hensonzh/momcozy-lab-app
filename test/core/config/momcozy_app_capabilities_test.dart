import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/config/momcozy_app_capabilities.dart';

void main() {
  test('capabilities read the compile environment and default to false', () {
    const capabilities = MomCozyAppCapabilities.fromEnvironment();
    const expectedOnboarding = bool.fromEnvironment(
      'MOMCOZY_ENABLE_ONBOARDING',
      defaultValue: false,
    );
    const expectedReleaseReset = bool.fromEnvironment(
      'MOMCOZY_ENABLE_RELEASE_RESET',
      defaultValue: false,
    );
    const expectedAgentHistory = bool.fromEnvironment(
      'MOMCOZY_ENABLE_AGENT_HISTORY',
      defaultValue: false,
    );
    const expectedExtendedProductApi = bool.fromEnvironment(
      'MOMCOZY_ENABLE_EXTENDED_PRODUCT_API',
      defaultValue: false,
    );

    expect(capabilities.onboardingGateEnabled, expectedOnboarding);
    expect(capabilities.releaseResetEnabled, expectedReleaseReset);
    expect(capabilities.agentConversationHistoryEnabled, expectedAgentHistory);
    expect(capabilities.extendedProductApiEnabled, expectedExtendedProductApi);
  });

  test('internal test builds can explicitly enable each capability', () {
    const capabilities = MomCozyAppCapabilities(
      onboardingGateEnabled: true,
      releaseResetEnabled: true,
      agentConversationHistoryEnabled: true,
      extendedProductApiEnabled: true,
    );

    expect(capabilities.onboardingGateEnabled, isTrue);
    expect(capabilities.releaseResetEnabled, isTrue);
    expect(capabilities.agentConversationHistoryEnabled, isTrue);
    expect(capabilities.extendedProductApiEnabled, isTrue);
    expect(capabilities.isRouteEnabled('/motion-assessment'), isTrue);
  });

  test('unsupported backend routes fail closed by default', () {
    const capabilities = MomCozyAppCapabilities();

    expect(capabilities.isRouteEnabled('/'), isTrue);
    expect(capabilities.isRouteEnabled('/plan'), isTrue);
    expect(capabilities.isRouteEnabled('/more'), isFalse);
    expect(capabilities.isRouteEnabled('/more/body-profile/edit'), isFalse);
    expect(capabilities.isRouteEnabled('/motion-assessment'), isFalse);
  });

  test(
    'release reset is active only when onboarding and reset are enabled',
    () {
      for (final entry in const [
        (onboarding: false, reset: false, expected: false),
        (onboarding: false, reset: true, expected: false),
        (onboarding: true, reset: false, expected: false),
        (onboarding: true, reset: true, expected: true),
      ]) {
        final capabilities = MomCozyAppCapabilities(
          onboardingGateEnabled: entry.onboarding,
          releaseResetEnabled: entry.reset,
        );

        expect(
          capabilities.releaseResetLifecycleEnabled,
          entry.expected,
          reason: 'onboarding=${entry.onboarding}, releaseReset=${entry.reset}',
        );
      }
    },
  );
}
