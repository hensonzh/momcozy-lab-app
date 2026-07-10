const agentHubDefaultGreeting =
    '嗨，我是 CozyMate，来自 Momcozy团队。\n\n你希望我怎么称呼你？今年多大啦？';

class AgentHubGreetingProfile {
  const AgentHubGreetingProfile({this.displayName = ''});

  final String displayName;
}

typedef AgentHubGreetingProfileLoader =
    Future<AgentHubGreetingProfile?> Function();

String agentHubGreetingForProfile(AgentHubGreetingProfile? profile) {
  final name = profile?.displayName.trim() ?? '';
  if (name.isEmpty) return agentHubDefaultGreeting;
  return '嗨 $name， \n\n今天想聊点什么呢？ \n\n把你现在最关心的事情告诉我就好，我会陪你一起梳理。';
}
