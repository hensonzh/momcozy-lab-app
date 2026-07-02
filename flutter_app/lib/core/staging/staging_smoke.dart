import 'dart:async';

import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_io_transport.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/privacy/log_redactor.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';
import 'package:momcozy_flutter_app/features/media/data/media_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/data/pump_workstate_api_repository.dart';
import 'package:momcozy_flutter_app/features/pump_session/domain/pump_workstate.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/schedule/data/schedule_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

class StagingSmokeConfig {
  const StagingSmokeConfig({
    required this.enabled,
    required this.apiBaseUri,
    required this.agentSseUri,
    required this.session,
    this.includeMutating = false,
    this.includeAgentStream = false,
    this.timeout = const Duration(seconds: 12),
  });

  factory StagingSmokeConfig.fromEnvironment(Map<String, String> env) {
    final apiBase = Uri.parse(
      _envOrDefault(env, 'MOMCOZY_API_BASE_URL', 'http://127.0.0.1:8769'),
    );
    final agentSseUrl = _envOrNull(env, 'MOMCOZY_AGENT_SSE_URL');
    return StagingSmokeConfig(
      enabled: _flag(env, 'MOMCOZY_STAGING_SMOKE'),
      includeMutating: _flag(env, 'MOMCOZY_STAGING_SMOKE_MUTATE'),
      includeAgentStream: _flag(env, 'MOMCOZY_STAGING_SMOKE_AGENT'),
      apiBaseUri: apiBase,
      agentSseUri: agentSseUrl == null
          ? apiBase.replace(path: '/api/ag-ui-ws')
          : Uri.parse(agentSseUrl),
      session: MomCozySession.fromEnvironment(
        accessToken: _envOrDefault(env, 'MOMCOZY_API_TOKEN', ''),
        refreshToken: _envOrDefault(env, 'MOMCOZY_REFRESH_TOKEN', ''),
        userId: _envOrDefault(env, 'MOMCOZY_DEFAULT_USER_ID', 'demo-user'),
        babyId: _envOrDefault(env, 'MOMCOZY_DEFAULT_BABY_ID', 'demo-baby'),
        locale: _envOrDefault(env, 'MOMCOZY_LOCALE', 'zh-CN'),
      ),
    );
  }

  final bool enabled;
  final bool includeMutating;
  final bool includeAgentStream;
  final Uri apiBaseUri;
  final Uri agentSseUri;
  final MomCozySession session;
  final Duration timeout;
}

abstract interface class StagingSmokeProbe {
  String get name;

  bool get requiresMutation;

  bool get requiresAgentStream;

  Future<void> run();
}

class StagingSmokeProbeResult {
  const StagingSmokeProbeResult({
    required this.name,
    required this.status,
    required this.elapsed,
    this.message,
  });

  final String name;
  final StagingSmokeStatus status;
  final Duration elapsed;
  final String? message;

  bool get passed => status == StagingSmokeStatus.passed;

  bool get failed => status == StagingSmokeStatus.failed;

  bool get skipped => status == StagingSmokeStatus.skipped;
}

enum StagingSmokeStatus { passed, failed, skipped }

class StagingSmokeReport {
  const StagingSmokeReport(this.results);

  final List<StagingSmokeProbeResult> results;

  bool get hasFailures => results.any((result) => result.failed);

  int get passedCount => results.where((result) => result.passed).length;

  int get skippedCount => results.where((result) => result.skipped).length;

  int get failedCount => results.where((result) => result.failed).length;
}

class StagingSmokeRunner {
  const StagingSmokeRunner({required this.config, required this.probes});

  final StagingSmokeConfig config;
  final List<StagingSmokeProbe> probes;

  Future<StagingSmokeReport> run() async {
    if (!config.enabled) {
      return StagingSmokeReport([
        StagingSmokeProbeResult(
          name: 'staging smoke disabled',
          status: StagingSmokeStatus.skipped,
          elapsed: Duration.zero,
          message: 'Set MOMCOZY_STAGING_SMOKE=1 to run against a backend.',
        ),
      ]);
    }

    final results = <StagingSmokeProbeResult>[];
    for (final probe in probes) {
      if (probe.requiresMutation && !config.includeMutating) {
        results.add(
          StagingSmokeProbeResult(
            name: probe.name,
            status: StagingSmokeStatus.skipped,
            elapsed: Duration.zero,
            message: 'Set MOMCOZY_STAGING_SMOKE_MUTATE=1 to run this probe.',
          ),
        );
        continue;
      }
      if (probe.requiresAgentStream && !config.includeAgentStream) {
        results.add(
          StagingSmokeProbeResult(
            name: probe.name,
            status: StagingSmokeStatus.skipped,
            elapsed: Duration.zero,
            message: 'Set MOMCOZY_STAGING_SMOKE_AGENT=1 to run this probe.',
          ),
        );
        continue;
      }

      final stopwatch = Stopwatch()..start();
      try {
        await probe.run().timeout(config.timeout);
        stopwatch.stop();
        results.add(
          StagingSmokeProbeResult(
            name: probe.name,
            status: StagingSmokeStatus.passed,
            elapsed: stopwatch.elapsed,
          ),
        );
      } catch (error) {
        stopwatch.stop();
        results.add(
          StagingSmokeProbeResult(
            name: probe.name,
            status: StagingSmokeStatus.failed,
            elapsed: stopwatch.elapsed,
            message: _redactSmokeError(error),
          ),
        );
      }
    }

    return StagingSmokeReport(results);
  }
}

List<StagingSmokeProbe> buildDefaultStagingSmokeProbes(
  StagingSmokeConfig config,
) {
  final headers = const {'X-Momcozy-Client': 'flutter-staging-smoke'};
  final token = config.session.accessToken;
  final jsonTransport = IoApiJsonTransport(
    baseUri: config.apiBaseUri,
    token: token,
    headers: headers,
  );
  final multipartTransport = IoApiMultipartTransport(
    baseUri: config.apiBaseUri,
    token: token,
    headers: headers,
  );
  final controlEndpoint = AgentStreamEndpoint(
    uri: config.apiBaseUri.replace(path: '/api/client-event'),
    token: token,
    headers: headers,
  );
  final agentEndpoint = AgentStreamEndpoint(
    uri: config.agentSseUri,
    token: token,
    headers: headers,
  );

  return [
    _StatusProbe(config, StatusApiRepository(transport: jsonTransport)),
    _ScheduleProbe(config, ScheduleApiRepository(transport: jsonTransport)),
    _RecordsProbe(config, RecordsApiRepository(transport: jsonTransport)),
    _PumpWorkstateProbe(
      config,
      PumpWorkstateApiRepository(transport: jsonTransport),
    ),
    _ClientEventProbe(
      config,
      AgentStreamClientEventClient(endpoint: controlEndpoint),
    ),
    _HospitalBagProbe(
      config,
      HospitalBagCartApiRepository(transport: jsonTransport),
    ),
    _MediaUploadProbe(
      config,
      MediaApiRepository(transport: multipartTransport),
    ),
    _AgentSseProbe(config, agentEndpoint),
  ];
}

class _StatusProbe implements StagingSmokeProbe {
  const _StatusProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final StatusApiRepository repository;

  @override
  String get name => 'status /v1/profile/me + /v1/profile/infants';

  @override
  bool get requiresMutation => false;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    await repository.fetchOverview(userId: config.session.userId);
  }
}

class _ScheduleProbe implements StagingSmokeProbe {
  const _ScheduleProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final ScheduleApiRepository repository;

  @override
  String get name => 'schedule /v1/plan/query-task';

  @override
  bool get requiresMutation => false;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    await repository.fetchDayPlan(
      userId: config.session.userId,
      day: DateTime.now(),
    );
  }
}

class _RecordsProbe implements StagingSmokeProbe {
  const _RecordsProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final RecordsApiRepository repository;

  @override
  String get name => 'records feeding/pump/growth';

  @override
  bool get requiresMutation => false;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    final today = DateTime.now();
    await repository.fetchFeedingRecords(
      userId: config.session.userId,
      date: today,
    );
    await repository.fetchPumpMilkRecords(
      userId: config.session.userId,
      date: today,
    );
    await repository.fetchGrowthRecords(
      userId: config.session.userId,
      babyId: config.session.babyId,
    );
  }
}

class _PumpWorkstateProbe implements StagingSmokeProbe {
  const _PumpWorkstateProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final PumpWorkstateApiRepository repository;

  @override
  String get name => 'pump /v1/pump/workstate';

  @override
  bool get requiresMutation => true;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    await repository.uploadWorkstate(
      userId: config.session.userId,
      left: const PumpSideWorkstate(state: 1, mode: 'staging_smoke', level: 1),
    );
  }
}

class _ClientEventProbe implements StagingSmokeProbe {
  const _ClientEventProbe(this.config, this.client);

  final StagingSmokeConfig config;
  final AgentStreamClientEventClient client;

  @override
  String get name => 'client-event /api/client-event';

  @override
  bool get requiresMutation => true;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    final result = await client.post(
      AgentStreamClientEventRequest(
        threadId: 'staging-smoke-${config.session.userId}',
        userId: config.session.userId,
        eventType: 'flutter_staging_smoke',
        label: 'Flutter staging smoke',
        locale: config.session.locale,
        occurredAt: DateTime.now().toUtc().toIso8601String(),
        metadata: const {'source': 'flutter_staging_smoke'},
      ),
    );
    if (!result.sent) {
      throw StateError(
        'client event failed: ${result.statusCode ?? result.error}',
      );
    }
  }
}

class _HospitalBagProbe implements StagingSmokeProbe {
  const _HospitalBagProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final HospitalBagCartApiRepository repository;

  @override
  String get name => 'hospital-bag /api/hospital-bag/cart-update';

  @override
  bool get requiresMutation => true;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    await repository.syncCart(
      userId: config.session.userId,
      items: const [
        HospitalBagPackedItem(
          id: 'flutter-staging-smoke',
          title: 'Flutter staging smoke',
          packed: false,
        ),
      ],
    );
  }
}

class _MediaUploadProbe implements StagingSmokeProbe {
  const _MediaUploadProbe(this.config, this.repository);

  final StagingSmokeConfig config;
  final MediaApiRepository repository;

  @override
  String get name => 'media /v1/files/upload';

  @override
  bool get requiresMutation => true;

  @override
  bool get requiresAgentStream => false;

  @override
  Future<void> run() async {
    await repository.uploadFile(
      userId: config.session.userId,
      file: const ApiUploadFile(
        name: 'flutter-staging-smoke.txt',
        mimeType: 'text/plain',
        sizeBytes: 13,
        bytes: [102, 108, 117, 116, 116, 101, 114, 45, 115, 109, 111, 107, 101],
      ),
    );
  }
}

class _AgentSseProbe implements StagingSmokeProbe {
  const _AgentSseProbe(this.config, this.endpoint);

  final StagingSmokeConfig config;
  final AgentStreamEndpoint endpoint;

  @override
  String get name => 'agent SSE ${endpoint.uri.path}';

  @override
  bool get requiresMutation => false;

  @override
  bool get requiresAgentStream => true;

  @override
  Future<void> run() async {
    final client = SseAgentStreamClient(
      AgentSseHttpTransport(
        endpoint: endpoint,
        payloadFactory: (request) {
          final suffix = DateTime.now().microsecondsSinceEpoch;
          return buildAgentRunPayload(
            request,
            runId: 'run-flutter-smoke-$suffix',
            messageId: 'msg-flutter-smoke-$suffix',
          );
        },
      ),
    );
    final event = await client
        .stream(
          AgentStreamRequest(
            userId: config.session.userId,
            threadId: 'thread-flutter-smoke-${config.session.userId}',
            locale: config.session.locale,
            message: 'Reply with a short staging smoke acknowledgement.',
            metadata: const {'source': 'flutter_staging_smoke'},
          ),
        )
        .firstWhere((event) => event.isTerminal);
    if (!event.isTerminal) {
      throw StateError('agent stream did not reach a terminal event');
    }
  }
}

String _envOrDefault(Map<String, String> env, String key, String fallback) {
  return _envOrNull(env, key) ?? fallback;
}

String? _envOrNull(Map<String, String> env, String key) {
  final value = env[key]?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

bool _flag(Map<String, String> env, String key) {
  final value = _envOrNull(env, key)?.toLowerCase();
  return value == '1' || value == 'true' || value == 'yes';
}

String _redactSmokeError(Object error) {
  final redacted = redactLogValue(error.toString()).toString();
  return redacted
      .replaceAll(
        RegExp(r'Bearer\s+[^\s,;]+', caseSensitive: false),
        'Bearer ***',
      )
      .replaceAll(RegExp(r'(token=)[^&\s]+', caseSensitive: false), r'$1***');
}
