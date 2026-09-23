const _agentHubIntroductionBody =
    '来自 Momcozy 团队，是陪你一起照顾自己和宝宝的智能伙伴。\n\n'
    '关于喂养、宝宝的日常和产后恢复，都可以和我聊聊。我会帮你整理记录、梳理问题，陪你找到下一步。\n\n'
    '从你现在最关心的一件事开始吧。';

const agentHubDefaultGreeting =
    '嗨，初次见面，很高兴认识你，我是 Cozymate\n\n$_agentHubIntroductionBody';

class AgentHubGreetingProfile {
  const AgentHubGreetingProfile({
    this.displayName = '',
    this.age,
    this.onboardingSkipped = false,
  });

  final String displayName;
  final int? age;
  final bool onboardingSkipped;

  bool get needsOnboarding {
    if (onboardingSkipped) return false;
    return displayName.trim().isEmpty || age == null;
  }
}

typedef AgentHubGreetingProfileLoader =
    Future<AgentHubGreetingProfile?> Function();

String agentHubGreetingForProfile(AgentHubGreetingProfile? profile) {
  final name = profile?.displayName.trim() ?? '';
  if (name.isEmpty) return agentHubDefaultGreeting;
  return '嗨 $name，初次见面，很高兴认识你，我是 Cozymate\n\n$_agentHubIntroductionBody';
}
