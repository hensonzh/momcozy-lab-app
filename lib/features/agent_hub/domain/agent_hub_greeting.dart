import 'package:momcozy_flutter_app/features/agent_hub/domain/birth_prep_profile_defaults.dart';

const agentHubDefaultGreeting =
    '嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？';

class AgentHubGreetingProfile {
  const AgentHubGreetingProfile({
    this.preferredName = '',
    this.age,
    this.birthPrepDefaults = const BirthPrepProfileDefaults(),
  });

  final String preferredName;
  final int? age;
  final BirthPrepProfileDefaults birthPrepDefaults;

  bool get needsOnboarding => preferredName.trim().isEmpty || age == null;
}

typedef AgentHubGreetingProfileLoader =
    Future<AgentHubGreetingProfile?> Function();

String agentHubGreetingForProfile(AgentHubGreetingProfile? profile) {
  final name = profile?.preferredName.trim() ?? '';
  if (name.isEmpty || profile?.age == null) return agentHubDefaultGreeting;
  return '嗨 $name， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。';
}
