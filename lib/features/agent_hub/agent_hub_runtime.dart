import 'package:app/core/agent_stream/agent_stream_client.dart';
import 'package:app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:app/core/agent_stream/agent_stream_runner.dart';
import 'package:app/core/auth/momcozy_session.dart';
import 'package:app/features/agent_hub/agent_hub_interaction_store.dart';

const _defaultAgentHubApiBaseUrl = String.fromEnvironment(
  'MOMCOZY_AGENT_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8010',
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
  final hospitalBagCart = clientContext?['hospital_bag_cart'];
  return AgentStreamRequest(
    threadId: _resolvedThreadId(threadId),
    message: message,
    locale: session.locale,
    metadata: {
      'source': 'flutter-agent-hub',
      if (hospitalBagCart is Map) 'hospital_bag_cart': hospitalBagCart,
    },
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
  return _agentHubEndpoint(_agentHubApiUri('/v1/agent/runs'));
}

AgentStreamEndpoint defaultAgentHubCancelEndpoint() {
  return _agentHubEndpoint(_agentHubApiUri('/v1/agent/runs'));
}

AgentStreamEndpoint defaultAgentHubActionEndpoint() {
  return _agentHubEndpoint(_agentHubApiUri('/v1/agent/actions'));
}

AgentStreamEndpoint sessionAgentHubSseEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  return _agentHubEndpoint(
    _agentHubApiUri('/v1/agent/runs'),
    token: session.accessToken,
    tokenProvider: accessTokenProvider,
  );
}

AgentStreamEndpoint sessionAgentHubCancelEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  return _agentHubEndpoint(
    _agentHubApiUri('/v1/agent/runs'),
    token: session.accessToken,
    tokenProvider: accessTokenProvider,
  );
}

AgentStreamEndpoint sessionAgentHubActionEndpoint(
  MomCozySession session, {
  String? Function()? accessTokenProvider,
}) {
  return _agentHubEndpoint(
    _agentHubApiUri('/v1/agent/actions'),
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
  final base = Uri.parse(_defaultAgentHubApiBaseUrl.trim());
  final normalizedBasePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$normalizedBasePath$normalizedPath',
  );
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
