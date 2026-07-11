import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/agent_hub/data/agent_hub_profile_repository.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'builds the legacy personalized greeting when name and age are known',
    () {
      const profile = AgentHubGreetingProfile(displayName: ' 小美 ', age: 29);

      expect(
        agentHubGreetingForProfile(profile),
        '嗨 小美， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。',
      );
    },
  );

  test('keeps the onboarding greeting until both name and age are known', () {
    expect(
      agentHubGreetingForProfile(
        const AgentHubGreetingProfile(displayName: '小美'),
      ),
      agentHubDefaultGreeting,
    );
  });

  test(
    'loads greeting and birth-prep defaults from the profile endpoint',
    () async {
      final transport = FixtureApiJsonTransport({
        'user_id': 'user-profile',
        'display_name': ' 小美 ',
        'age': 29,
        'delivery_date': '2026-09-20',
        'profile_onboarding_skipped': false,
        'birth_prep_fetus_count': '单胎',
        'birthPrepBirthHospital': '深圳市妇幼',
        'birth_prep_top_worries': '怕漏买,怕母乳不够',
      });
      final repository = AgentHubProfileRepository(transport: transport);

      final profile = await repository.fetchGreetingProfile();

      expect(transport.lastPath, agentHubProfileEndpoint);
      expect(profile.displayName, '小美');
      expect(profile.age, 29);
      expect(profile.needsOnboarding, isFalse);
      expect(profile.birthPrepDefaults.toFormDefaultValues(), {
        'age': 29,
        'due_date_or_week': '2026-09-20',
        'fetus_count': '单胎',
        'birth_hospital': '深圳市妇幼',
        'birth_setting': '深圳市妇幼',
        'top_worries': '怕漏买,怕母乳不够',
      });
    },
  );

  test('drops legacy placeholder defaults', () async {
    final repository = AgentHubProfileRepository(
      transport: FixtureApiJsonTransport({
        'display_name': '',
        'age': null,
        'birth_prep_due_date_or_week': '待确认',
        'birth_prep_birth_path': 'to confirm',
        'birth_prep_support_person': '还没想好',
      }),
    );

    final profile = await repository.fetchGreetingProfile();

    expect(profile.birthPrepDefaults.toFormDefaultValues(), isEmpty);
  });
}
