const _agentHubIntroductionBody =
    'I\'m your AI companion from Momcozy, here to support you and your baby.\n\n'
    'Ask me about feeding, your baby\'s daily care, or postpartum recovery. I can help you make sense of your records, think through questions, and find a next step.\n\n'
    'What\'s on your mind today?';

const agentHubDefaultGreeting =
    'Hi, I\'m Momcozy AI. It\'s lovely to meet you.\n\n$_agentHubIntroductionBody';

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

// Keep the former product name out of generated greetings. User names in
// any language are otherwise preserved.
final _unsupportedGreetingName = RegExp(
  r'cozy[\s-]*mate',
  caseSensitive: false,
  unicode: true,
);

String agentHubGreetingForProfile(AgentHubGreetingProfile? profile) {
  final name = profile?.displayName.trim() ?? '';
  if (name.isEmpty || _unsupportedGreetingName.hasMatch(name)) {
    return agentHubDefaultGreeting;
  }
  return 'Hi $name, I\'m Momcozy AI. It\'s lovely to meet you.\n\n$_agentHubIntroductionBody';
}
