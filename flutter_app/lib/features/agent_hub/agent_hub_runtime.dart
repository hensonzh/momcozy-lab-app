import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';

const _defaultAgentHubSseUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_SSE_URL',
  defaultValue: 'http://127.0.0.1:8768/api/ag-ui',
);
const _defaultAgentHubApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8769',
);
const _defaultAgentHubCancelUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_CANCEL_URL',
);
const _defaultAgentHubToken = String.fromEnvironment('MOMCOZY_API_TOKEN');
const _defaultAgentHubUserId = String.fromEnvironment(
  'MOMCOZY_DEFAULT_USER_ID',
  defaultValue: 'demo-user',
);
const _defaultAgentHubThreadId = String.fromEnvironment(
  'MOMCOZY_AGENT_THREAD_ID',
  defaultValue: 'thread-demo',
);
const _defaultAgentHubLocale = String.fromEnvironment(
  'MOMCOZY_LOCALE',
  defaultValue: 'zh-CN',
);

AgentStreamRequest buildDefaultAgentHubRequest(String message) {
  return AgentStreamRequest(
    userId: _defaultAgentHubUserId,
    threadId: _defaultAgentHubThreadId,
    message: message,
    locale: _defaultAgentHubLocale,
    metadata: const {'source': 'flutter-agent-hub'},
  );
}

AgentStreamRunner createDefaultAgentHubRunner({AgentStreamEndpoint? endpoint}) {
  return AgentStreamRunner(
    SseAgentStreamClient(
      AgentSseHttpTransport(
        endpoint: endpoint ?? defaultAgentHubSseEndpoint(),
        payloadFactory: buildDefaultAgentHubPayload,
      ),
    ),
  );
}

AgentStreamCancelClient createDefaultAgentHubCancelClient({
  AgentStreamEndpoint? endpoint,
}) {
  return AgentStreamCancelClient(
    endpoint: endpoint ?? defaultAgentHubCancelEndpoint(),
  );
}

AgentStreamEndpoint defaultAgentHubSseEndpoint() {
  return _agentHubEndpoint(Uri.parse(_defaultAgentHubSseUrl));
}

AgentStreamEndpoint defaultAgentHubCancelEndpoint() {
  final explicitCancelUrl = _defaultAgentHubCancelUrl.trim();
  return _agentHubEndpoint(
    explicitCancelUrl.isEmpty
        ? _agentHubApiUri('/api/ag-ui-cancel')
        : Uri.parse(explicitCancelUrl),
  );
}

AgentStreamEndpoint _agentHubEndpoint(Uri uri) {
  final token = _defaultAgentHubToken.trim();
  return AgentStreamEndpoint(
    uri: uri,
    token: token.isEmpty ? null : token,
    headers: const {'X-Momcozy-Client': 'flutter'},
  );
}

Uri _agentHubApiUri(String path) {
  final base = Uri.parse(_defaultAgentHubApiBaseUrl);
  return base.replace(path: path);
}

Map<String, Object?> buildDefaultAgentHubPayload(AgentStreamRequest request) {
  return buildAgentRunPayload(
    request,
    runId: _timestampedId('run-flutter'),
    messageId: _timestampedId('msg-flutter'),
  );
}

String _timestampedId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
