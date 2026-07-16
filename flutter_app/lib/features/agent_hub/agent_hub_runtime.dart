import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_interaction_store.dart';

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
const _defaultAgentHubActionsUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_ACTIONS_URL',
);
const _defaultAgentHubToken = String.fromEnvironment('MOMCOZY_API_TOKEN');
const _defaultAgentHubThreadId = String.fromEnvironment(
  'MOMCOZY_AGENT_THREAD_ID',
);
const _defaultAgentHubLocale = String.fromEnvironment(
  'MOMCOZY_LOCALE',
  defaultValue: 'zh-CN',
);

AgentStreamRequest buildDefaultAgentHubRequest(String message) {
  return AgentStreamRequest(
    threadId: _resolvedThreadId(_defaultAgentHubThreadId),
    message: message,
    locale: _defaultAgentHubLocale,
    metadata: const {'source': 'flutter-agent-hub'},
  );
}

AgentStreamRequest buildSessionAgentHubRequest(
  String message, {
  required MomCozySession session,
  String? threadId,
  Map<String, Object?>? clientContext,
}) {
  return AgentStreamRequest(
    threadId: _resolvedThreadId(threadId),
    message: message,
    locale: session.locale,
    metadata: {'source': 'flutter-agent-hub', ...?clientContext},
  );
}

AgentStreamRunner createDefaultAgentHubRunner({AgentStreamEndpoint? endpoint}) {
  final resolvedEndpoint = endpoint ?? defaultAgentHubSseEndpoint();
  return AgentStreamRunner(
    SseAgentStreamClient(
      ProductionAgentSseTransport(
        runsEndpoint: resolvedEndpoint,
        payloadFactory: buildDefaultAgentHubPayload,
      ),
    ),
    reconnectPolicy: const AgentStreamReconnectPolicy(),
    runStatusReader: ProductionAgentRunStatusReader(
      runsEndpoint: resolvedEndpoint,
    ),
  );
}

AgentStreamRunner createSessionAgentHubRunner(
  MomCozySession session, {
  AgentStreamEndpoint? endpoint,
  String? Function()? accessTokenProvider,
  AgentStreamUnauthorizedHandler? onUnauthorized,
}) {
  final resolvedEndpoint =
      endpoint ??
      sessionAgentHubSseEndpoint(
        session,
        accessTokenProvider: accessTokenProvider,
      );
  return AgentStreamRunner(
    SseAgentStreamClient(
      ProductionAgentSseTransport(
        runsEndpoint: resolvedEndpoint,
        payloadFactory: buildDefaultAgentHubPayload,
        onUnauthorized: onUnauthorized,
      ),
    ),
    reconnectPolicy: const AgentStreamReconnectPolicy(),
    runStatusReader: ProductionAgentRunStatusReader(
      runsEndpoint: resolvedEndpoint,
      onUnauthorized: onUnauthorized,
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
  String? Function()? accessTokenProvider,
}) {
  return AgentStreamCancelClient(
    endpoint:
        endpoint ??
        sessionAgentHubCancelEndpoint(
          session,
          accessTokenProvider: accessTokenProvider,
        ),
  );
}

AgentStreamActionClient createDefaultAgentHubActionClient({
  AgentStreamEndpoint? endpoint,
}) {
  return AgentStreamActionClient(
    endpoint: endpoint ?? defaultAgentHubActionEndpoint(),
  );
}

AgentStreamActionClient createSessionAgentHubActionClient(
  MomCozySession session, {
  AgentStreamEndpoint? endpoint,
  String? Function()? accessTokenProvider,
}) {
  return AgentStreamActionClient(
    endpoint:
        endpoint ??
        sessionAgentHubActionEndpoint(
          session,
          accessTokenProvider: accessTokenProvider,
        ),
  );
}

AgentStreamClientEventClient createSessionAgentHubClientEventClient(
  MomCozySession session, {
  AgentStreamEndpoint? endpoint,
  String? Function()? accessTokenProvider,
}) {
  return AgentStreamClientEventClient(
    endpoint:
        endpoint ??
        sessionAgentHubSseEndpoint(
          session,
          accessTokenProvider: accessTokenProvider,
        ),
  );
}

AgentHubInteractionStateStore createSessionAgentHubInteractionStateStore(
  MomCozySession session,
) {
  return FlutterSecureAgentHubInteractionStateStore(userId: session.userId);
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

AgentStreamEndpoint defaultAgentHubActionEndpoint() {
  final explicitActionsUrl = _defaultAgentHubActionsUrl.trim();
  return _agentHubEndpoint(
    explicitActionsUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/actions')
        : Uri.parse(explicitActionsUrl),
  );
}

AgentStreamEndpoint sessionAgentHubSseEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  final explicitRunsUrl = _defaultAgentHubRunsUrl.trim();
  return _agentHubEndpoint(
    explicitRunsUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitRunsUrl),
    token: session.accessToken,
    tokenProvider: accessTokenProvider,
  );
}

AgentStreamEndpoint sessionAgentHubCancelEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  final explicitCancelUrl = _defaultAgentHubCancelUrl.trim();
  return _agentHubEndpoint(
    explicitCancelUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/runs')
        : Uri.parse(explicitCancelUrl),
    token: session.accessToken,
    tokenProvider: accessTokenProvider,
  );
}

AgentStreamEndpoint sessionAgentHubActionEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  final explicitActionsUrl = _defaultAgentHubActionsUrl.trim();
  return _agentHubEndpoint(
    explicitActionsUrl.isEmpty
        ? _agentHubApiUri('/v1/agent/actions')
        : Uri.parse(explicitActionsUrl),
    token: session.accessToken,
    tokenProvider: accessTokenProvider,
  );
}

AgentStreamEndpoint _agentHubEndpoint(
  Uri uri, {
  String? token,
  String? Function()? tokenProvider,
}) {
  final authToken = (token ?? _defaultAgentHubToken).trim();
  return AgentStreamEndpoint(
    uri: uri,
    token: authToken.isEmpty ? null : authToken,
    tokenProvider: tokenProvider,
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

String? _resolvedThreadId(String? threadId) {
  final explicitThreadId = threadId?.trim();
  if (explicitThreadId != null && explicitThreadId.isNotEmpty) {
    return explicitThreadId;
  }
  final dartDefinedThreadId = _defaultAgentHubThreadId.trim();
  if (dartDefinedThreadId.isNotEmpty && dartDefinedThreadId != 'thread-demo') {
    return dartDefinedThreadId;
  }
  return null;
}
