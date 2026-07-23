import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/agent_hub_greeting.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/birth_prep_profile_defaults.dart';

const agentHubProfileEndpoint = '/v1/profile/me';

class AgentHubProfileRepository {
  const AgentHubProfileRepository({required this.transport});

  final ApiJsonTransport transport;

  Future<AgentHubGreetingProfile> fetchGreetingProfile() async {
    final profile = await transport.getJson(agentHubProfileEndpoint);
    final birthPrepDefaults = BirthPrepProfileDefaults.fromProfileMap(profile);
    return AgentHubGreetingProfile(
      preferredName: _string(profile['preferred_name']).trim(),
      age: birthPrepDefaults.age,
      birthPrepDefaults: birthPrepDefaults,
    );
  }
}

String _string(Object? value) => value is String ? value : '';
