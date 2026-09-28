import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/primary_tab_activity.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_home_page.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/more_page.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_page.dart';
import 'package:momcozy_flutter_app/modules/schedule/presentation/schedule_calendar.dart';

import '../support/fixture_api_transport.dart';

class _HomeTransport extends FixtureApiJsonTransport {
  _HomeTransport({this.email = 'mia@example.test', this.name = 'Mia'})
    : super(const {});

  final String email;
  final String name;

  Completer<Map<String, Object?>>? pendingScheduleRefresh;
  Completer<Map<String, Object?>>? pendingIdentityRefresh;
  Completer<Map<String, Object?>>? pendingMeRefresh;
  Completer<Map<String, Object?>>? pendingBabyRefresh;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getPaths.add(path);
    if (path == '/v1/schedule' &&
        pendingScheduleRefresh != null &&
        getPaths.where((value) => value == path).length > 1) {
      return pendingScheduleRefresh!.future;
    }
    if (path == '/v1/auth/me' &&
        pendingIdentityRefresh != null &&
        getPaths.where((value) => value == path).length > 1) {
      return pendingIdentityRefresh!.future;
    }
    if (path == '/v1/profile/me-experience' &&
        pendingMeRefresh != null &&
        getPaths.where((value) => value == path).length > 1) {
      return pendingMeRefresh!.future;
    }
    if (path == '/v1/babies' &&
        pendingBabyRefresh != null &&
        getPaths.where((value) => value == path).length > 1) {
      return pendingBabyRefresh!.future;
    }
    return switch (path) {
      '/v1/profile/me' => {'preferred_name': name},
      '/v1/profile/me-experience' => {
        'profile': {
          'preferred_name': name,
          'actual_delivery_date': '2026-09-01',
        },
      },
      '/v1/profile/lactation' => {'actual_delivery_date': '2026-09-01'},
      '/v1/auth/me' => {'email': email},
      '/v1/babies' => _babyResponse,
      '/v1/schedule' => {
        'personal': <Object?>[],
        'server_time': '2026-09-28T08:00:00Z',
        'has_more': false,
      },
      _ => {'items': <Object?>[], 'total': 0, 'offset': 0, 'limit': 100},
    };
  }
}

const _babyResponse = {
  'items': [
    {
      'id': 'baby',
      'name': 'Luna',
      'version': 1,
      'birth_date': '2026-09-01',
      'sex': 'female',
      'feeding_mode': 'unknown',
      'created_at': '2026-09-01T00:00:00Z',
      'updated_at': '2026-09-01T00:00:00Z',
    },
  ],
};

class _AgentTab extends StatefulWidget {
  const _AgentTab();

  @override
  State<_AgentTab> createState() => _AgentTabState();
}

class _AgentTabState extends State<_AgentTab> {
  @override
  Widget build(BuildContext context) => const Text('Agent tab');
}

void main() {
  testWidgets('a changed runtime isolates every retained tab', (tester) async {
    MomCozyApiRuntime runtimeFor(_HomeTransport transport, String user) =>
        MomCozyApiRuntime(
          jsonTransport: transport,
          userId: user,
          babyId: 'baby',
          timezoneProvider: () async => 'UTC',
          now: () => DateTime.utc(2026, 9, 28, 8),
        );
    final first = _HomeTransport();
    final second = _HomeTransport(email: 'leo@example.test', name: 'Leo');
    var runtime = runtimeFor(first, 'mia');
    late StateSetter update;
    final router = createMomCozyRouter(
      initialLocation: '/schedule',
      agentHubBuilder: (context, uri, extra) => const _AgentTab(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          update = setState;
          return MomCozyRuntimeScope(
            apiRuntime: runtime,
            child: MaterialApp.router(routerConfig: router),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final schedule = tester.state(find.byType(SchedulePage));
    for (final tab in ['me', 'baby', 'momcozy ai', 'more']) {
      await tester.tap(find.byKey(ValueKey('bottom-nav-$tab')));
      await tester.pumpAndSettle();
    }
    final more = tester.state(find.byType(MorePage));
    expect(find.text('mia@example.test'), findsOneWidget);

    update(() => runtime = runtimeFor(second, 'leo'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MorePage)), isNot(same(more)));
    expect(find.text('leo@example.test'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(SchedulePage)), isNot(same(schedule)));
    expect(second.getPaths.where((path) => path == '/v1/schedule').length, 1);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-me')));
    await tester.pumpAndSettle();
    expect(find.text('Leo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale tabs refresh without replacing loaded content', (
    tester,
  ) async {
    final transport = _HomeTransport();
    var now = DateTime.utc(2026, 9, 28, 8);
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'mia',
      babyId: 'baby',
      timezoneProvider: () async => 'UTC',
      now: () => now,
    );
    final router = createMomCozyRouter(initialLocation: '/schedule');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final schedule = tester.state(find.byType(SchedulePage));
    expect(find.byType(ScheduleCalendar), findsOneWidget);
    expect(transport.getPaths.where((p) => p == '/v1/schedule').length, 1);

    await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
    await tester.pumpAndSettle();
    final more = tester.state(find.byType(MorePage));
    expect(find.text('mia@example.test'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    transport.pendingScheduleRefresh = Completer<Map<String, Object?>>();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-schedule')));
    await tester.pump();
    expect(tester.state(find.byType(SchedulePage)), same(schedule));
    expect(find.byType(ScheduleCalendar), findsOneWidget);
    expect(transport.getPaths.where((p) => p == '/v1/schedule').length, 2);
    transport.pendingScheduleRefresh!.complete({
      'personal': <Object?>[],
      'server_time': '2026-09-28T08:01:00Z',
      'has_more': false,
    });
    await tester.pumpAndSettle();

    transport.pendingIdentityRefresh = Completer<Map<String, Object?>>();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-more')));
    await tester.pump();
    expect(tester.state(find.byType(MorePage)), same(more));
    expect(find.text('mia@example.test'), findsOneWidget);
    expect(transport.getPaths.where((p) => p == '/v1/auth/me').length, 2);
    transport.pendingIdentityRefresh!.complete({'email': 'mia@example.test'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Me and Baby also refresh stale data behind their existing UI', (
    tester,
  ) async {
    final transport = _HomeTransport();
    var now = DateTime.utc(2026, 9, 28, 8);
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'mia',
      babyId: 'baby',
      timezoneProvider: () async => 'UTC',
      now: () => now,
    );
    final router = createMomCozyRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final me = tester.state(find.byType(MeHomePage));
    expect(find.text('Mia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
    await tester.pumpAndSettle();
    final baby = tester.state(find.byType(BabyHomePage));
    expect(find.text('Luna'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    transport.pendingMeRefresh = Completer<Map<String, Object?>>();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-me')));
    await tester.pump();
    expect(tester.state(find.byType(MeHomePage)), same(me));
    expect(find.text('Mia'), findsOneWidget);
    expect(
      transport.getPaths.where((p) => p == '/v1/profile/me-experience').length,
      2,
    );
    transport.pendingMeRefresh!.complete({
      'profile': {
        'preferred_name': 'Mia',
        'actual_delivery_date': '2026-09-01',
      },
    });
    await tester.pumpAndSettle();

    final initialBabyRequests = transport.getPaths
        .where((p) => p == '/v1/babies')
        .length;
    transport.pendingBabyRefresh = Completer<Map<String, Object?>>();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-baby')));
    await tester.pump();
    expect(tester.state(find.byType(BabyHomePage)), same(baby));
    expect(find.text('Luna'), findsOneWidget);
    expect(
      transport.getPaths.where((p) => p == '/v1/babies').length,
      initialBabyRequests + 1,
    );
    transport.pendingBabyRefresh!.complete(_babyResponse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Agent tab receives visible and hidden transitions', (
    tester,
  ) async {
    final runtime = MomCozyApiRuntime(
      jsonTransport: _HomeTransport(),
      userId: 'mia',
      babyId: 'baby',
      timezoneProvider: () async => 'UTC',
    );
    final router = createMomCozyRouter(
      agentHubBuilder: (context, uri, extra) => Text(
        'agent-visible-${PrimaryTabActivity.maybeOf(context)?.selectedIndex == 2}',
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-momcozy ai')));
    await tester.pumpAndSettle();
    expect(find.text('agent-visible-true'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-me')));
    await tester.pumpAndSettle();
    expect(
      find.text('agent-visible-false', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to primary tabs retains page state and loaded data', (
    tester,
  ) async {
    final transport = _HomeTransport();
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      userId: 'mia',
      babyId: 'baby',
      timezoneProvider: () async => 'UTC',
      now: () => DateTime.utc(2026, 9, 28, 8),
    );
    final agentExtras = <Object?>[];
    final router = createMomCozyRouter(
      agentHubBuilder: (context, uri, extra) {
        agentExtras.add(extra);
        return const _AgentTab();
      },
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MomCozyRuntimeScope(
        apiRuntime: runtime,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final me = tester.state(find.byType(MeHomePage));
    final meRequests = transport.getPaths.length;

    Future<void> switchTo(String tab) async {
      await tester.tap(find.byKey(ValueKey('bottom-nav-$tab')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await switchTo('baby');
    final baby = tester.state(find.byType(BabyHomePage));
    await switchTo('momcozy ai');
    final agent = tester.state(find.byType(_AgentTab));
    await switchTo('schedule');
    final schedule = tester.state(find.byType(SchedulePage));
    await switchTo('more');
    final more = tester.state(find.byType(MorePage));
    final loadedRequests = transport.getPaths.length;

    await switchTo('me');
    expect(tester.state(find.byType(MeHomePage)), same(me));
    expect(transport.getPaths.length, loadedRequests);
    expect(meRequests, greaterThan(0));
    await switchTo('baby');
    expect(tester.state(find.byType(BabyHomePage)), same(baby));
    await switchTo('momcozy ai');
    expect(tester.state(find.byType(_AgentTab)), same(agent));
    await switchTo('schedule');
    expect(tester.state(find.byType(SchedulePage)), same(schedule));
    await switchTo('more');
    expect(tester.state(find.byType(MorePage)), same(more));
    expect(transport.getPaths.length, loadedRequests);

    router.go('/notifications?from=/me');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);
    final afterNotifications = transport.getPaths.length;
    router.go('/me');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MeHomePage)), same(me));
    expect(transport.getPaths.length, afterNotifications);

    router.go('/', extra: {'agentPrefill': 'from Me'});
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(_AgentTab)), same(agent));
    expect(agentExtras.last, {'agentPrefill': 'from Me'});
    expect(tester.takeException(), isNull);
  });
}
