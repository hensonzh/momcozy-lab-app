import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:app/features/agent_hub/domain/agent_hub_greeting.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test('builds the personalized greeting when name and age are known', () {
    const profile = AgentHubGreetingProfile(preferredName: ' 小美 ', age: 29);

    expect(
      agentHubGreetingForProfile(profile),
      '嗨 小美， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。',
    );
  });

  test('keeps the onboarding greeting until both name and age are known', () {
    expect(
      agentHubGreetingForProfile(
        const AgentHubGreetingProfile(preferredName: '小美'),
      ),
      agentHubDefaultGreeting,
    );
  });

  test(
    'loads greeting and birth-prep defaults from the profile endpoint',
    () async {
      final transport = FixtureApiJsonTransport({
        'preferred_name': ' 小美 ',
        'age': 29,
        'estimated_due_date': '2026-09-20',
      });
      final repository = AgentHubProfileRepository(transport: transport);

      final profile = await repository.fetchGreetingProfile();

      expect(transport.lastPath, agentHubProfileEndpoint);
      expect(profile.preferredName, '小美');
      expect(profile.age, 29);
      expect(profile.needsOnboarding, isFalse);
      expect(profile.birthPrepDefaults.toFormDefaultValues(), {
        'age': 29,
        'due_date_or_week': '2026-09-20',
      });
    },
  );

  test('drops blank profile defaults', () async {
    final repository = AgentHubProfileRepository(
      transport: FixtureApiJsonTransport({
        'preferred_name': null,
        'age': null,
        'estimated_due_date': null,
      }),
    );

    final profile = await repository.fetchGreetingProfile();

    expect(profile.birthPrepDefaults.toFormDefaultValues(), isEmpty);
  });
}
