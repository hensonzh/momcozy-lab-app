import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('builds the legacy personalized greeting when a name is known', () {
    const profile = AgentHubGreetingProfile(displayName: ' 小美 ');

    expect(
      agentHubGreetingForProfile(profile),
      '嗨 小美， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。',
    );
  });

  test('keeps the onboarding greeting when no name is known', () {
    expect(
      agentHubGreetingForProfile(const AgentHubGreetingProfile()),
      agentHubDefaultGreeting,
    );
  });

  test('loads and trims the greeting name from the profile endpoint', () async {
    final transport = FixtureApiJsonTransport({
      'user_id': 'user-profile',
      'display_name': ' 小美 ',
      'age': 29,
    });
    final repository = AgentHubProfileRepository(transport: transport);

    final profile = await repository.fetchGreetingProfile();

    expect(transport.lastPath, agentHubProfileEndpoint);
    expect(profile.displayName, '小美');
  });
}
