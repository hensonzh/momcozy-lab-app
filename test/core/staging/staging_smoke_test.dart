import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/staging/staging_smoke.dart';

void main() {
  test('StagingSmokeConfig reads env flags and session context', () {
    final config = StagingSmokeConfig.fromEnvironment({
      'MOMCOZY_STAGING_SMOKE': '1',
      'MOMCOZY_STAGING_SMOKE_MUTATE': 'true',
      'MOMCOZY_STAGING_SMOKE_AGENT': 'yes',
      'MOMCOZY_API_BASE_URL': 'https://api.example.test/base',
      'MOMCOZY_AGENT_API_BASE_URL': 'https://agent.example.test/runtime',
      'MOMCOZY_API_TOKEN': ' secret-token ',
      'MOMCOZY_REFRESH_TOKEN': ' refresh-token ',
      'MOMCOZY_DEFAULT_USER_ID': ' user-001 ',
      'MOMCOZY_DEFAULT_BABY_ID': ' baby-001 ',
      'MOMCOZY_LOCALE': ' en-US ',
    });

    expect(config.enabled, isTrue);
    expect(config.includeMutating, isTrue);
    expect(config.includeAgentStream, isTrue);
    expect(config.apiBaseUri, Uri.parse('https://api.example.test/base'));
    expect(
      config.agentRunsUri,
      Uri.parse('https://agent.example.test/runtime/v1/agent/runs'),
    );
    expect(config.session.userId, 'user-001');
    expect(config.session.babyId, 'baby-001');
    expect(config.session.locale, 'en-US');
    expect(config.session.accessToken, 'secret-token');
    expect(config.session.refreshToken, 'refresh-token');
  });

  test('runner skips every probe when staging smoke is disabled', () async {
    final runner = StagingSmokeRunner(
      config: _config(enabled: false),
      probes: [_FakeProbe(name: 'read-only')],
    );

    final report = await runner.run();

    expect(report.passedCount, 0);
    expect(report.skippedCount, 1);
    expect(report.failedCount, 0);
    expect(report.results.single.name, 'staging smoke disabled');
  });

  test(
    'headless smoke builds Agent context without platform plugins',
    () async {
      final context = await buildStagingSmokeRunCreateContextProvider(
        now: () => DateTime.utc(2026, 8, 27, 4, 15),
      ).load();

      expect(context.timezone, 'UTC');
      expect(context.messageSentAt, '2026-08-27T04:15:00+00:00');
    },
  );

  test(
    'runner gates mutating and agent probes behind explicit flags',
    () async {
      final readOnly = _FakeProbe(name: 'read-only');
      final mutating = _FakeProbe(name: 'mutating', requiresMutation: true);
      final agent = _FakeProbe(name: 'agent', requiresAgentStream: true);
      final runner = StagingSmokeRunner(
        config: _config(enabled: true),
        probes: [readOnly, mutating, agent],
      );

      final report = await runner.run();

      expect(readOnly.runCount, 1);
      expect(mutating.runCount, 0);
      expect(agent.runCount, 0);
      expect(report.passedCount, 1);
      expect(report.skippedCount, 2);
      expect(report.failedCount, 0);
    },
  );

  test('runner records failures without leaking bearer tokens', () async {
    final runner = StagingSmokeRunner(
      config: _config(enabled: true),
      probes: [
        _FakeProbe(
          name: 'failure',
          failure: StateError('Authorization Bearer secret-token failed'),
        ),
      ],
    );

    final report = await runner.run();

    expect(report.hasFailures, isTrue);
    expect(report.failedCount, 1);
    expect(report.results.single.message, isNot(contains('secret-token')));
  });

  test(
    'agent smoke accepts only completed runs with an assistant response',
    () async {
      await expectLater(
        validateSuccessfulAgentSmoke(
          Stream.fromIterable([
            AgentStreamEvent(const {
              'type': 'message.completed',
              'payload': {'role': 'assistant', 'text': 'staging is healthy'},
            }),
            AgentStreamEvent(const {'type': 'run.completed'}),
          ]),
        ),
        completes,
      );
    },
  );

  test('agent smoke rejects failed terminal events', () async {
    await expectLater(
      validateSuccessfulAgentSmoke(
        Stream.value(AgentStreamEvent(const {'type': 'run.failed'})),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'agent smoke rejects completed runs without a non-empty assistant response',
    () async {
      await expectLater(
        validateSuccessfulAgentSmoke(
          Stream.fromIterable([
            AgentStreamEvent(const {
              'type': 'message.completed',
              'payload': {'role': 'assistant', 'text': '   '},
            }),
            AgentStreamEvent(const {'type': 'run.completed'}),
          ]),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );
}

StagingSmokeConfig _config({
  required bool enabled,
  bool includeMutating = false,
  bool includeAgentStream = false,
}) {
  return StagingSmokeConfig(
    enabled: enabled,
    includeMutating: includeMutating,
    includeAgentStream: includeAgentStream,
    apiBaseUri: Uri.parse('https://api.example.test'),
    agentRunsUri: Uri.parse('https://api.example.test/v1/agent/runs'),
    session: const MomCozySession(
      status: MomCozySessionStatus.authenticated,
      userId: 'user-001',
      babyId: 'baby-001',
      locale: 'zh-CN',
      accessToken: 'secret-token',
    ),
  );
}

class _FakeProbe implements StagingSmokeProbe {
  _FakeProbe({
    required this.name,
    this.requiresMutation = false,
    this.requiresAgentStream = false,
    this.failure,
  });

  @override
  final String name;

  @override
  final bool requiresMutation;

  @override
  final bool requiresAgentStream;

  final Object? failure;
  int runCount = 0;

  @override
  Future<void> run() async {
    runCount += 1;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}
