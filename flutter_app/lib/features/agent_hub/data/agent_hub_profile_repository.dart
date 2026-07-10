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
        profile['display_name'] ?? profile['displayName'],
      ).trim(),
    );
  }
}

String _string(Object? value) => value is String ? value : '';
