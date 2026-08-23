import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';

const agentHubProfileEndpoint = '/v1/profile/me';

class AgentHubProfileRepository {
  const AgentHubProfileRepository({required this.transport});

  final ApiJsonTransport transport;

  Future<AgentHubGreetingProfile> fetchGreetingProfile() async {
    final profile = await transport.getJson(agentHubProfileEndpoint);
    return AgentHubGreetingProfile(
      displayName: _string(
        profile['display_name'] ??
            profile['displayName'] ??
            profile['preferred_name'] ??
            profile['preferredName'],
      ).trim(),
      age: _age(profile['age']),
      onboardingSkipped:
          profile['profile_onboarding_skipped'] == true ||
          profile['profileOnboardingSkipped'] == true,
    );
  }
}

String _string(Object? value) => value is String ? value : '';

int? _age(Object? value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
}
