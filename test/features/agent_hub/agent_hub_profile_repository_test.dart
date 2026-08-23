import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('builds the personalized greeting when name and age are known', () {
    const profile = AgentHubGreetingProfile(displayName: ' 小美 ', age: 29);

    expect(
      agentHubGreetingForProfile(profile),
      '嗨 小美， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。',
    );
  });

  test('keeps the onboarding greeting until both name and age are known', () {
    expect(
      agentHubGreetingForProfile(
        const AgentHubGreetingProfile(displayName: '小美'),
      ),
      agentHubDefaultGreeting,
    );
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

  test('accepts the split Product API profile schema', () async {
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
