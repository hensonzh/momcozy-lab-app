import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('personalizes the introduction with a trimmed display name', () {
    const profile = AgentHubGreetingProfile(displayName: ' 小美 ', age: 29);

    expect(
      agentHubGreetingForProfile(profile),
      agentHubDefaultGreeting.replaceFirst('嗨，', '嗨 小美，'),
    );
  });

  test('personalizes the introduction without requiring age', () {
    expect(
      agentHubGreetingForProfile(
        const AgentHubGreetingProfile(displayName: '小美'),
      ),
      agentHubDefaultGreeting.replaceFirst('嗨，', '嗨 小美，'),
    );
  });

  test('missing names omit the name placeholder', () {
    for (final profile in [
      null,
      const AgentHubGreetingProfile(displayName: '  '),
    ]) {
      expect(agentHubGreetingForProfile(profile), agentHubDefaultGreeting);
    }
  });

  test('loads greeting fields from the profile endpoint', () async {
    final transport = FixtureApiJsonTransport({
      'user_id': 'user-profile',
      'display_name': ' 小美 ',
      'age': '29',
      'profile_onboarding_skipped': false,
      'birth_prep_top_worries': 'legacy value that must be ignored',
    });
    final repository = AgentHubProfileRepository(transport: transport);

    final profile = await repository.fetchGreetingProfile();

    expect(transport.lastPath, agentHubProfileEndpoint);
    expect(profile.displayName, '小美');
    expect(profile.age, 29);
    expect(profile.needsOnboarding, isFalse);
  });

  test('accepts the split Product Backend API profile schema', () async {
    final repository = AgentHubProfileRepository(
      transport: FixtureApiJsonTransport({'preferred_name': ' 小美 ', 'age': 29}),
    );

    final profile = await repository.fetchGreetingProfile();

    expect(profile.displayName, '小美');
    expect(profile.age, 29);
  });

  test('honors an explicit onboarding skip', () async {
    final repository = AgentHubProfileRepository(
      transport: FixtureApiJsonTransport({
        'display_name': '',
        'profile_onboarding_skipped': true,
      }),
    );

    final profile = await repository.fetchGreetingProfile();

    expect(profile.needsOnboarding, isFalse);
  });
}
