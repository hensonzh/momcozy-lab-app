import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';

const _defaultAgentHubRunsUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_RUNS_URL',
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

AgentStreamRequest buildSessionAgentHubRequest(
  String message, {
  required MomCozySession session,
  String? threadId,
}) {
  return AgentStreamRequest(
    userId: session.userId,
    threadId: _resolvedThreadId(session, threadId),
    message: message,
    locale: session.locale,
    metadata: const {'source': 'flutter-agent-hub'},
  );
}

AgentStreamRunner createDefaultAgentHubRunner({AgentStreamEndpoint? endpoint}) {
  return AgentStreamRunner(
    SseAgentStreamClient(
      ProductionAgentSseTransport(
        runsEndpoint: endpoint ?? defaultAgentHubSseEndpoint(),
        payloadFactory: buildDefaultAgentHubPayload,
      ),
    ),
  );
}

AgentStreamRunner createSessionAgentHubRunner(
  MomCozySession session, {
  AgentStreamEndpoint? endpoint,
}) {
  return AgentStreamRunner(
    SseAgentStreamClient(
      ProductionAgentSseTransport(
        runsEndpoint: endpoint ?? sessionAgentHubSseEndpoint(session),
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

AgentStreamCancelClient createSessionAgentHubCancelClient(
  MomCozySession session, {
  AgentStreamEndpoint? endpoint,
}) {
  return AgentStreamCancelClient(
    endpoint: endpoint ?? sessionAgentHubCancelEndpoint(session),
  );
}

AgentStreamEndpoint defaultAgentHubSseEndpoint() {
  final explicitRunsUrl = _defaultAgentHubRunsUrl.trim();
  return _agentHubEndpoint(
    explicitRunsUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitRunsUrl),
  );
}

AgentStreamEndpoint defaultAgentHubCancelEndpoint() {
  final explicitCancelUrl = _defaultAgentHubCancelUrl.trim();
  return _agentHubEndpoint(
    explicitCancelUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitCancelUrl),
  );
}

AgentStreamEndpoint sessionAgentHubSseEndpoint(MomCozySession session) {
  final explicitRunsUrl = _defaultAgentHubRunsUrl.trim();
  return _agentHubEndpoint(
    explicitRunsUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitRunsUrl),
    token: session.accessToken,
  );
}

AgentStreamEndpoint sessionAgentHubCancelEndpoint(MomCozySession session) {
  final explicitCancelUrl = _defaultAgentHubCancelUrl.trim();
  return _agentHubEndpoint(
    explicitCancelUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitCancelUrl),
    token: session.accessToken,
  );
}

AgentStreamEndpoint _agentHubEndpoint(Uri uri, {String? token}) {
  final authToken = (token ?? _defaultAgentHubToken).trim();
  return AgentStreamEndpoint(
    uri: uri,
    token: authToken.isEmpty ? null : authToken,
    headers: const {'X-Momcozy-Client': 'flutter'},
  );
}

Uri _agentHubApiUri(String path) {
  final base = Uri.parse(_defaultAgentHubApiBaseUrl);
  return base.replace(path: path);
}

Map<String, Object?> buildDefaultAgentHubPayload(AgentStreamRequest request) {
  return buildProductionAgentRunPayload(request);
}

String _resolvedThreadId(MomCozySession session, String? threadId) {
  final explicitThreadId = threadId?.trim();
  if (explicitThreadId != null && explicitThreadId.isNotEmpty) {
    return explicitThreadId;
  }
  final dartDefinedThreadId = _defaultAgentHubThreadId.trim();
  if (dartDefinedThreadId.isNotEmpty && dartDefinedThreadId != 'thread-demo') {
    return dartDefinedThreadId;
  }
  return 'thread-${session.userId}';
}
