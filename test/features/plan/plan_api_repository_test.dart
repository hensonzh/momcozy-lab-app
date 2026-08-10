import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/domain/plan_dashboard.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'maps active plans and selected-day sessions into the new Plan domain',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {
          'items': [
            {
              'id': 'lactation-plan',
              'plan_type': 'lactation',
              'title': 'Lactation Plan',
              'summary': 'Five sessions every day',
              'status': 'active',
              'payload': {
                'week_number': 4,
                'total_weeks': 8,
                'sessions_per_day': 5,
                'daily_target_volume_ml': 600,
                'today_volume_ml': 473,
                'weekly_target_volume_ml': 4200,
                'weekly_volume_ml': 2850,
                'weekly_completed_sessions': 3,
                'weekly_total_sessions': 5,
              },
            },
            {
              'id': 'yoga-plan',
              'plan_type': 'yoga',
              'title': 'Yoga',
              'summary': 'Recovery yoga',
              'status': 'active',
              'payload': <String, Object?>{},
            },
          ],
        },
        planSessionListEndpoint: const {
          'items': [
            {
              'id': 'session-1',
              'plan_id': 'lactation-plan',
              'task_date': '2026-10-22',
              'task_time': '08:00',
              'title': 'Session 1',
              'status': 'completed',
              'payload': {'value_label': '120 ml'},
            },
            {
              'id': 'session-2',
              'plan_id': 'lactation-plan',
              'task_date': '2026-10-22',
              'task_time': '11:00',
              'title': 'Session 2',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
            {
              'id': 'legacy-standalone-task',
              'plan_id': null,
              'task_date': '2026-10-22',
              'task_time': '12:00',
              'title': 'Legacy standalone task',
              'status': 'pending',
              'payload': <String, Object?>{},
            },
          ],
        },
      });

      final dashboard = await PlanApiRepository(
        transport: transport,
      ).fetchDashboard(weekOf: DateTime(2026, 10, 22, 9, 41));

      expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);
      expect(transport.lastQuery, {'task_date': '2026-10-22', 'limit': 100});
      expect(dashboard.plans, hasLength(2));
      expect(dashboard.plans.first.category, PlanCategory.lactation);
      expect(dashboard.plans.first.weekNumber, 4);
      expect(dashboard.plans.first.weeklyCompletedSessions, 3);
      expect(dashboard.plans.first.weeklyTotalSessions, 5);
      expect(dashboard.plans.last.category, PlanCategory.yoga);
      expect(dashboard.sessions, hasLength(2));
      expect(dashboard.sessions.first.status, PlanSessionStatus.completed);
      expect(dashboard.sessions.first.valueLabel, '120 ml');
      expect(dashboard.sessions.last.status, PlanSessionStatus.next);
    },
  );

  test('marks the first pending session as next within each plan', () async {
    final transport = FixtureApiJsonTransportByPath({
      planListEndpoint: const {
        'items': [
          {
            'id': 'plan-a',
            'plan_type': 'lactation',
            'title': 'Plan A',
            'payload': <String, Object?>{},
          },
          {
            'id': 'plan-b',
            'plan_type': 'yoga',
            'title': 'Plan B',
            'payload': <String, Object?>{},
          },
        ],
      },
      planSessionListEndpoint: const {
        'items': [
          {
            'id': 'a-1',
            'plan_id': 'plan-a',
            'task_date': '2026-10-22',
            'task_time': '08:00',
            'title': 'A first',
            'status': 'pending',
          },
          {
            'id': 'b-1',
            'plan_id': 'plan-b',
            'task_date': '2026-10-22',
            'task_time': '09:00',
            'title': 'B first',
            'status': 'pending',
          },
          {
            'id': 'a-2',
            'plan_id': 'plan-a',
            'task_date': '2026-10-22',
            'task_time': '10:00',
            'title': 'A second',
            'status': 'pending',
          },
        ],
      },
    });

    final dashboard = await PlanApiRepository(
      transport: transport,
    ).fetchDashboard(weekOf: DateTime(2026, 10, 22));

    expect(dashboard.sessions.map((session) => session.status), [
      PlanSessionStatus.next,
      PlanSessionStatus.next,
      PlanSessionStatus.upcoming,
    ]);
  });

  test(
    'starts plan and session requests together for the active-plan path',
    () async {
      final transport = _DeferredPlanApiTransport();
      final repository = PlanApiRepository(transport: transport);

      final dashboardFuture = repository.fetchDashboard(
        weekOf: DateTime(2026, 10, 22),
      );
      await Future<void>.delayed(Duration.zero);

      expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);

      transport.completePlans(const {
        'items': [
          {
            'id': 'lactation-plan',
            'plan_type': 'lactation',
            'title': 'Lactation Plan',
            'payload': <String, Object?>{},
          },
        ],
      });
      transport.completeSessions(const {'items': <Object?>[]});

      final dashboard = await dashboardFuture;
      expect(dashboard.plans, hasLength(1));
    },
  );

  test(
    'maps lactation-plan v1 without inventing week or volume metrics',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {
          'items': [
            {
              'id': 'plan-v1',
              'plan_type': 'lactation',
              'title': '15 天追奶计划',
              'summary': 'Gradual schedule',
              'status': 'active',
              'payload': {
                'schema_version': 'lactation-plan.v1',
                'goal': 'increase_supply',
                'start_date': '2026-08-11',
                'end_date': '2026-08-25',
                'duration_days': 15,
                'basis': {'mode': 'history_analysis'},
                'preferences': {
                  'target_daily_pattern': {
                    'pumping_sessions': 6,
                    'breastfeeding_anchors': 1,
                  },
                },
              },
            },
          ],
        },
        planSessionListEndpoint: const {'items': <Object?>[]},
      });

      final dashboard = await PlanApiRepository(
        transport: transport,
      ).fetchDashboard(weekOf: DateTime(2026, 8, 11));
      final plan = dashboard.plans.single;

      expect(plan.startDate, DateTime(2026, 8, 11));
      expect(plan.endDate, DateTime(2026, 8, 25));
      expect(plan.durationDays, 15);
      expect(plan.goal, 'increase_supply');
      expect(plan.basisMode, 'history_analysis');
      expect(plan.pumpingSessionsPerDay, 6);
      expect(plan.breastfeedingAnchorsPerDay, 1);
      expect(plan.sessionsPerDay, 7);
      expect(plan.weekNumber, isNull);
      expect(plan.totalWeeks, isNull);
      expect(plan.dailyTargetVolumeMl, isNull);
      expect(plan.todayVolumeMl, isNull);
      expect(plan.weeklyTargetVolumeMl, isNull);
      expect(plan.weeklyVolumeMl, isNull);
      expect(plan.dayNumberOn(DateTime(2026, 8, 10)), isNull);
      expect(plan.dayNumberOn(DateTime(2026, 8, 11)), 1);
      expect(plan.dayNumberOn(DateTime(2026, 8, 25)), 15);
      expect(plan.dayNumberOn(DateTime(2026, 8, 26)), isNull);
    },
  );

  test('coalesces duplicate dashboard loads for the same day', () async {
    final transport = _DeferredPlanApiTransport();
    final repository = PlanApiRepository(transport: transport);
    final selectedDay = DateTime(2026, 10, 22);

    final first = repository.fetchDashboard(weekOf: selectedDay);
    final second = repository.fetchDashboard(weekOf: selectedDay);
    await Future<void>.delayed(Duration.zero);

    expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);

    transport.completePlans(const {'items': <Object?>[]});
    transport.completeSessions(const {'items': <Object?>[]});
    final dashboards = await Future.wait([first, second]);

    expect(dashboards.last, same(dashboards.first));
    expect(repository.snapshotFor(weekOf: selectedDay), same(dashboards.first));
    expect(
      repository.snapshotFor(weekOf: selectedDay.add(const Duration(days: 1))),
      isNull,
    );
  });

  test(
    'empty dashboard does not wait for the parallel session request',
    () async {
      final transport = _DeferredPlanApiTransport();
      final repository = PlanApiRepository(transport: transport);

      final dashboardFuture = repository.fetchDashboard(
        weekOf: DateTime(2026, 10, 22),
      );
      transport.completePlans(const {'items': <Object?>[]});

      final dashboard = await dashboardFuture.timeout(
        const Duration(seconds: 1),
      );
      expect(dashboard.isEmpty, isTrue);

      transport.completeSessions(const {'items': <Object?>[]});
    },
  );

  test(
    'returns the supplied empty state when there are no active plans',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': <Object?>[]},
        planSessionListEndpoint: const {'items': <Object?>[]},
      });

      final dashboard = await PlanApiRepository(
        transport: transport,
      ).fetchDashboard(weekOf: DateTime(2026, 10, 22));

      expect(dashboard.isEmpty, isTrue);
      expect(transport.getPaths, [planListEndpoint, planSessionListEndpoint]);
    },
  );

  test(
    'rejects malformed plan collections instead of showing false empty',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': 'invalid'},
      });

      await expectLater(
        PlanApiRepository(
          transport: transport,
        ).fetchDashboard(weekOf: DateTime(2026, 10, 22)),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('updates a plan session through the task PATCH contract', () async {
    final transport = FixtureApiJsonTransportByPath(
      const {},
      writeResponsesByPath: const {
        '/v1/plans/tasks/session-2': {'id': 'session-2'},
      },
    );
    final repository = PlanApiRepository(transport: transport);

    expect(repository, isA<PlanSessionMutationRepository>());
    await (repository as PlanSessionMutationRepository).updateSession(
      sessionId: 'session-2',
      title: ' Evening recovery stretch ',
      scheduledAt: DateTime(2026, 10, 23, 18, 5),
    );

    expect(transport.lastMethod, 'PATCH');
    expect(transport.lastPath, '/v1/plans/tasks/session-2');
    expect(transport.lastBody, {
      'title': 'Evening recovery stretch',
      'task_date': '2026-10-23',
      'task_time': '18:05',
    });
  });

  test('session updates invalidate the cached dashboard snapshot', () async {
    final selectedDay = DateTime(2026, 10, 22);
    final transport = FixtureApiJsonTransportByPath(
      {
        planListEndpoint: const {
          'items': [
            {
              'id': 'lactation-plan',
              'plan_type': 'lactation',
              'title': 'Lactation Plan',
              'payload': <String, Object?>{},
            },
          ],
        },
        planSessionListEndpoint: const {'items': <Object?>[]},
      },
      writeResponsesByPath: const {
        '/v1/plans/tasks/session-1': {'id': 'session-1'},
      },
    );
    final repository = PlanApiRepository(transport: transport);

    await repository.fetchDashboard(weekOf: selectedDay);
    expect(repository.snapshotFor(weekOf: selectedDay), isNotNull);

    await repository.updateSession(
      sessionId: 'session-1',
      title: 'Updated session',
      scheduledAt: DateTime(2026, 10, 22, 10),
    );

    expect(repository.snapshotFor(weekOf: selectedDay), isNull);
  });

  test('explicit invalidation clears the dashboard snapshot', () async {
    final selectedDay = DateTime(2026, 10, 22);
    final repository = PlanApiRepository(
      transport: FixtureApiJsonTransportByPath({
        planListEndpoint: const {'items': <Object?>[]},
        planSessionListEndpoint: const {'items': <Object?>[]},
      }),
    );

    await repository.fetchDashboard(weekOf: selectedDay);
    expect(repository.snapshotFor(weekOf: selectedDay), isNotNull);

    repository.invalidate();

    expect(repository.snapshotFor(weekOf: selectedDay), isNull);
  });

  test('reports when the injected transport cannot PATCH sessions', () async {
    final repository = PlanApiRepository(
      transport: _DeferredPlanApiTransport(),
    );

    await expectLater(
      repository.updateSession(
        sessionId: 'session-1',
        title: 'Updated session',
        scheduledAt: DateTime(2026, 10, 22, 10),
      ),
      throwsA(isA<UnsupportedError>()),
    );
  });
}

class _DeferredPlanApiTransport implements ApiJsonTransport {
  final Completer<Map<String, Object?>> _plans =
      Completer<Map<String, Object?>>();
  final Completer<Map<String, Object?>> _sessions =
      Completer<Map<String, Object?>>();
  final List<String> getPaths = <String>[];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    getPaths.add(path);
    return switch (path) {
      planListEndpoint => _plans.future,
      planSessionListEndpoint => _sessions.future,
      _ => throw StateError('Unexpected path: $path'),
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) => throw UnsupportedError('POST is not used by Plan dashboard loading.');

  void completePlans(Map<String, Object?> response) =>
      _plans.complete(response);

  void completeSessions(Map<String, Object?> response) =>
      _sessions.complete(response);
}
