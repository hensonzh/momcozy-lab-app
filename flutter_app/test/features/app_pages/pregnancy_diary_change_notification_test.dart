import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_client.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_event.dart';
import 'package:momcozy_flutter_app/core/agent_stream/agent_stream_runner.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/preferences/volume_unit_preference.dart';
import 'package:momcozy_flutter_app/features/agent_hub/agent_hub_page.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/data/pregnancy_diary_api_repository.dart';
import 'package:momcozy_flutter_app/features/pregnancy_diary/domain/pregnancy_diary_change_store.dart';
import 'package:momcozy_flutter_app/features/pregnancy_plan/data/pregnancy_plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';
import 'package:momcozy_flutter_app/features/status/data/status_preference_store.dart';
import 'package:momcozy_flutter_app/features/status/domain/status_selection.dart';
import 'package:momcozy_flutter_app/native/p0_platform_interfaces.dart';

void main() {
  testWidgets('bottom navigation reacts to runtime diary unread state', (
    tester,
  ) async {
    final runtime = _runtime(_SequencedDiaryTransport());

    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MomCozyBottomNavigation(location: '/schedule'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
      findsNothing,
    );

    runtime.pregnancyDiaryChangeStore.record(
      PregnancyDiaryChange.tryFromEvent(_changedEvent())!,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
      findsOneWidget,
    );
  });

  testWidgets(
    'opening Status transfers the badge to a bounded card highlight',
    (tester) async {
      await _setCompactViewport(tester);
      final runtime = _runtime(_SequencedDiaryTransport());
      runtime.pregnancyDiaryChangeStore.record(
        PregnancyDiaryChange.tryFromEvent(_changedEvent())!,
      );
      final router = createMomCozyRouter(initialLocation: '/schedule');
      final routeIntentPlatform = FakeRouteIntentPlatform();
      addTearDown(router.dispose);
      addTearDown(routeIntentPlatform.dispose);

      await tester.pumpWidget(
        MomCozyFlutterApp(
          router: router,
          routeIntentPlatform: routeIntentPlatform,
          apiRuntime: runtime,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
      await tester.pumpAndSettle();

      expect(runtime.pregnancyDiaryChangeStore.hasUnread, isFalse);
      expect(runtime.pregnancyDiaryChangeStore.highlightCard, isFalse);
      expect(
        find.byKey(const ValueKey('status-pregnancy-diary-notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
        findsNothing,
      );
    },
  );

  testWidgets('failed navigation GET restores the bottom navigation badge', (
    tester,
  ) async {
    await _setCompactViewport(tester);
    final transport = _SequencedDiaryTransport(failingDiaryRequests: {1});
    final runtime = _runtime(transport);
    runtime.pregnancyDiaryChangeStore.record(
      PregnancyDiaryChange.tryFromEvent(_changedEvent())!,
    );
    final router = createMomCozyRouter(initialLocation: '/schedule');
    final routeIntentPlatform = FakeRouteIntentPlatform();
    addTearDown(router.dispose);
    addTearDown(routeIntentPlatform.dispose);

    await tester.pumpWidget(
      MomCozyFlutterApp(
        router: router,
        routeIntentPlatform: routeIntentPlatform,
        apiRuntime: runtime,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bottom-nav-status')));
    await tester.pumpAndSettle();

    expect(transport.diaryGetCount, 1);
    expect(runtime.pregnancyDiaryChangeStore.hasUnread, isTrue);
    expect(runtime.pregnancyDiaryChangeStore.highlightCard, isFalse);
    expect(
      find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Agent diary event refetches Status once and deduplicates replay',
    (tester) async {
      final harness = await _pumpRunningPregnancyStatus(tester);

      expect(harness.transport.diaryGetCount, 1);
      expect(find.text('事件前的日记'), findsOneWidget);
      final countsBeforeChange = {
        for (final path in _statusGetEndpoints)
          path: harness.transport.getCount(path),
      };

      final changed = _changedEvent();
      harness.client.emit(changed);
      harness.client.emit(changed);
      await tester.pumpAndSettle();

      expect(harness.transport.diaryGetCount, 2);
      for (final path in _statusGetEndpoints) {
        expect(
          harness.transport.getCount(path),
          countsBeforeChange[path]! +
              (path == pregnancyDiaryEntriesEndpoint ? 1 : 0),
          reason: 'a pregnancy_diary.changed event must only refetch diaries',
        );
      }
      expect(find.text('Agent 写入后的日记'), findsOneWidget);
      expect(harness.runtime.pregnancyDiaryChangeStore.revision, 1);
    },
  );

  testWidgets('read conflict and failed tool outcomes do not refetch Status', (
    tester,
  ) async {
    final harness = await _pumpRunningPregnancyStatus(tester);

    harness.client.emit(
      _toolEvent(
        eventId: 'evt-diary-read',
        type: 'tool.completed',
        toolName: 'pregnancy_diary.entry.read',
        status: 'entries_read',
        sequence: 2,
      ),
    );
    harness.client.emit(
      _toolEvent(
        eventId: 'evt-diary-conflict',
        type: 'tool.completed',
        toolName: 'pregnancy_diary.entry.create',
        status: 'entry_already_exists',
        sequence: 3,
      ),
    );
    harness.client.emit(
      _toolEvent(
        eventId: 'evt-diary-write-failed',
        type: 'tool.failed',
        toolName: 'pregnancy_diary.entry.update',
        status: 'write_failed',
        sequence: 4,
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.transport.diaryGetCount, 1);
    expect(harness.runtime.pregnancyDiaryChangeStore.revision, 0);
    expect(harness.runtime.pregnancyDiaryChangeStore.hasUnread, isFalse);
  });

  testWidgets('failed event-triggered GET retains the unread badge', (
    tester,
  ) async {
    final transport = _SequencedDiaryTransport(failingDiaryRequests: {2});
    final harness = await _pumpRunningPregnancyStatus(
      tester,
      transport: transport,
    );

    harness.client.emit(_changedEvent());
    await tester.pumpAndSettle();

    expect(transport.diaryGetCount, 2);
    expect(harness.runtime.pregnancyDiaryChangeStore.hasUnread, isTrue);
    expect(
      find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
      findsOneWidget,
    );
  });

  testWidgets('stale failed GET cannot undo a newer successful diary notice', (
    tester,
  ) async {
    final secondRequest = Completer<Map<String, Object?>>();
    final thirdRequest = Completer<Map<String, Object?>>();
    final transport = _SequencedDiaryTransport(
      deferredDiaryRequests: {2: secondRequest, 3: thirdRequest},
    );
    final harness = await _pumpRunningPregnancyStatus(
      tester,
      transport: transport,
    );

    harness.client.emit(_changedEvent());
    await tester.pump();
    harness.client.emit(
      _changedEvent(eventId: 'evt-diary-changed-newer', sequence: 3),
    );
    await tester.pump();

    thirdRequest.complete(_diaryResponse('最新的 Agent 日记'));
    await tester.pump();
    secondRequest.completeError(StateError('stale diary GET failed'));
    await tester.pumpAndSettle();

    expect(transport.diaryGetCount, 3);
    expect(harness.runtime.pregnancyDiaryChangeStore.revision, 2);
    expect(harness.runtime.pregnancyDiaryChangeStore.hasUnread, isFalse);
    expect(harness.runtime.pregnancyDiaryChangeStore.highlightCard, isFalse);
    expect(find.text('最新的 Agent 日记'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bottom-nav-status-diary-badge')),
      findsNothing,
    );
  });
}

Future<_DiaryHarness> _pumpRunningPregnancyStatus(
  WidgetTester tester, {
  _SequencedDiaryTransport? transport,
}) async {
  await _setCompactViewport(tester);

  final resolvedTransport = transport ?? _SequencedDiaryTransport();
  final runtime = _runtime(resolvedTransport);
  final client = _ControllableAgentStreamClient();
  final router = createMomCozyRouter(
    initialLocation: '/',
    agentHubBuilder: (context, uri, extra, voicePlaybackCoordinator) {
      return AgentHubPage(
        runner: AgentStreamRunner(client),
        voicePlaybackCoordinator: voicePlaybackCoordinator,
        onPregnancyDiaryChange: (change) {
          runtime.pregnancyDiaryChangeStore.record(change);
        },
      );
    },
  );
  final routeIntentPlatform = FakeRouteIntentPlatform();
  addTearDown(client.dispose);
  addTearDown(router.dispose);
  addTearDown(routeIntentPlatform.dispose);

  await tester.pumpWidget(
    MomCozyFlutterApp(
      router: router,
      routeIntentPlatform: routeIntentPlatform,
      apiRuntime: runtime,
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey('agent-composer-input')),
    '记录今天的胎动',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('agent-send-button')));
  await tester.pump();
  expect(client.requests, hasLength(1));

  client.emit(_runStartedEvent());
  await tester.pump();

  router.go('/status');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('status-care-stage-pregnancy')));
  await tester.pumpAndSettle();

  expect(resolvedTransport.diaryGetCount, 1);
  return _DiaryHarness(
    runtime: runtime,
    transport: resolvedTransport,
    client: client,
  );
}

Future<void> _setCompactViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

MomCozyApiRuntime _runtime(_SequencedDiaryTransport transport) {
  return MomCozyApiRuntime(
    jsonTransport: transport,
    pregnancyDiaryChangeStore: PregnancyDiaryChangeStore(),
    statusPreferenceStore: const _MemoryStatusPreferenceStore(),
    volumeUnitPreferenceStore: const _MemoryVolumeUnitPreferenceStore(),
    userId: 'diary-widget-user',
    babyId: 'diary-widget-baby',
    locale: 'zh-CN',
    now: () => DateTime.utc(2026, 7, 12),
  );
}

class _MemoryStatusPreferenceStore implements StatusPreferenceStore {
  const _MemoryStatusPreferenceStore();

  @override
  Future<StatusCareStage?> readCareStage() async => null;

  @override
  Future<void> writeCareStage(StatusCareStage stage) async {}
}

class _MemoryVolumeUnitPreferenceStore implements VolumeUnitPreferenceStore {
  const _MemoryVolumeUnitPreferenceStore();

  @override
  Future<MomCozyVolumeUnit?> read() async => null;

  @override
  Future<void> write(MomCozyVolumeUnit unit) async {}
}

AgentStreamEvent _runStartedEvent() {
  return AgentStreamEvent(const {
    'event_id': 'evt-run-started',
    'sequence': 1,
    'type': 'run.started',
    'thread_id': 'thread-diary',
    'run_id': 'run-diary',
    'payload': <String, Object?>{},
  });
}

AgentStreamEvent _changedEvent({
  String eventId = 'evt-diary-changed',
  int sequence = 2,
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': sequence,
    'type': 'pregnancy_diary.changed',
    'thread_id': 'thread-diary',
    'run_id': 'run-diary',
    'payload': const {
      'operation': 'updated',
      'entry_id': 'diary-2026-07-12',
      'entry_date': '2026-07-12',
      'updated_at': '2026-07-12T08:30:00Z',
      'source': 'agent',
    },
  });
}

AgentStreamEvent _toolEvent({
  required String eventId,
  required String type,
  required String toolName,
  required String status,
  required int sequence,
}) {
  return AgentStreamEvent({
    'event_id': eventId,
    'sequence': sequence,
    'type': type,
    'thread_id': 'thread-diary',
    'run_id': 'run-diary',
    'tool_call_id': 'call-$sequence',
    'payload': {
      'tool_name': toolName,
      'safe_output': {'status': status},
    },
  });
}

class _DiaryHarness {
  const _DiaryHarness({
    required this.runtime,
    required this.transport,
    required this.client,
  });

  final MomCozyApiRuntime runtime;
  final _SequencedDiaryTransport transport;
  final _ControllableAgentStreamClient client;
}

class _ControllableAgentStreamClient implements AgentStreamClient {
  final requests = <AgentStreamRequest>[];
  final _controllers = <StreamController<AgentStreamEvent>>[];

  @override
  Stream<AgentStreamEvent> stream(AgentStreamRequest request) {
    requests.add(request);
    final controller = StreamController<AgentStreamEvent>();
    _controllers.add(controller);
    return controller.stream;
  }

  void emit(AgentStreamEvent event) {
    _controllers.single.add(event);
  }

  Future<void> dispose() async {
    for (final controller in _controllers) {
      await controller.close();
    }
  }
}

class _SequencedDiaryTransport implements ApiJsonTransport {
  _SequencedDiaryTransport({
    this.failingDiaryRequests = const <int>{},
    this.deferredDiaryRequests = const <int, Completer<Map<String, Object?>>>{},
  });

  final Set<int> failingDiaryRequests;
  final Map<int, Completer<Map<String, Object?>>> deferredDiaryRequests;
  int diaryGetCount = 0;
  final Map<String, int> getCounts = {};

  int getCount(String path) => getCounts[path] ?? 0;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getCounts.update(path, (count) => count + 1, ifAbsent: () => 1);
    if (path == statusProfileEndpoint) {
      return const {
        'user_id': 'diary-widget-user',
        'delivery_date': '2026-09-01',
      };
    }
    if (path == statusInfantsEndpoint) {
      return const {'items': <Object?>[]};
    }
    if (path == pregnancyDiaryEntriesEndpoint) {
      diaryGetCount += 1;
      if (failingDiaryRequests.contains(diaryGetCount)) {
        throw StateError('pregnancy diary GET failed');
      }
      final deferred = deferredDiaryRequests[diaryGetCount];
      if (deferred != null) return deferred.future;
      final content = diaryGetCount == 1 ? '事件前的日记' : 'Agent 写入后的日记';
      return _diaryResponse(content);
    }
    return const {};
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError('POST is not used by this test.');
  }
}

const _statusGetEndpoints = [
  statusProfileEndpoint,
  statusInfantsEndpoint,
  feedingRecordsEndpoint,
  milkTrendsEndpoint,
  growthRecordsEndpoint,
  pregnancyDiaryEntriesEndpoint,
  pregnancyPlansEndpoint,
];

Map<String, Object?> _diaryResponse(String content) {
  return {
    'items': [
      {
        'id': 'diary-2026-07-12',
        'entry_date': '2026-07-12',
        'content': content,
        'symptom_tags': <Object?>[],
        'attachments': <Object?>[],
      },
    ],
  };
}
