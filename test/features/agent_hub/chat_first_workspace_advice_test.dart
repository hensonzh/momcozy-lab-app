import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/agent_hub/domain/chat_first_daily_advice.dart';
import 'package:momcozy_flutter_app/features/agent_hub/presentation/chat_first_workspace.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';

import '../../support/fixture_api_transport.dart';

Map<String, Object?> _baby(String id, String date) => {
  'id': id,
  'name': id,
  'birth_date': date,
  'sex': 'unspecified',
  'feeding_mode': 'unknown',
  'version': 1,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

Map<String, Object?> _feedingRecord(String id, String babyId, String at) => {
  'id': id,
  'baby_id': babyId,
  'version': 1,
  'observation': {
    'kind': 'feeding',
    'occurred_at': at,
    'note': '',
    'method': 'breastfeeding',
    'side': 'left',
    'volume_ml': null,
    'duration_minutes': 12,
  },
  'deleted_at': null,
  'created_at': at,
  'updated_at': at,
};

class _DelayedBabyProfilesTransport extends FixtureApiJsonTransportByPath {
  _DelayedBabyProfilesTransport(super.responsesByPath);

  final firstRead = Completer<void>();
  bool _delayed = false;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/babies' && !_delayed) {
      _delayed = true;
      await firstRead.future;
    }
    return super.getJson(path, query: query);
  }
}

void main() {
  late DailyAdviceCatalog catalog;
  setUpAll(() {
    catalog = DailyAdviceCatalog.fromJson(
      jsonDecode(
            File(
              'assets/content/baby_daily_advice_0_364.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>,
    );
  });
  testWidgets('selected baby daily copy changes at account-local midnight', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 22, 15, 59, 59, 500);
    final transport = FixtureApiJsonTransportByPath({
      '/v1/babies': {
        'items': [_baby('b1', '2026-10-12')],
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner',
        babyId: 'b1',
        locale: 'zh-CN',
        accessToken: 'token',
      ),
      now: () => now,
      timezoneProvider: () async => 'Asia/Shanghai',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatFirstWorkspace(
            runtime: runtime,
            role: FamilyRole.mother,
            onOpenDrawer: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 10 天'), findsOneWidget);
    expect(find.text(catalog.entryFor(10)!.text), findsOneWidget);

    // Account-local midnight is 16:00 UTC, not device/UTC midnight.
    now = DateTime.utc(2026, 10, 22, 16, 0, 0, 100);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 11 天'), findsOneWidget);
    expect(find.text(catalog.entryFor(11)!.text), findsOneWidget);
    expect(find.text(catalog.entryFor(10)!.text), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a pre-midnight read completing after midnight cannot freeze yesterday',
    (tester) async {
      var now = DateTime.utc(2026, 10, 22, 15, 59, 59);
      final transport = _DelayedBabyProfilesTransport({
        '/v1/babies': {
          'items': [_baby('b1', '2026-10-12')],
        },
      });
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'owner',
          babyId: 'b1',
          locale: 'zh-CN',
          accessToken: 'token',
        ),
        now: () => now,
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWorkspace(
              runtime: runtime,
              role: FamilyRole.mother,
              onOpenDrawer: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      now = DateTime.utc(2026, 10, 22, 16, 0, 1);
      transport.firstRead.complete();
      await tester.pumpAndSettle();
      expect(find.text('宝宝出生 11 天'), findsOneWidget);
      expect(find.text(catalog.entryFor(11)!.text), findsOneWidget);
      expect(find.text(catalog.entryFor(10)!.text), findsNothing);
      expect(transport.getPaths.where((p) => p == '/v1/babies'), hasLength(2));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('resuming after midnight selects the new day without a timer', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 22, 15, 59);
    final transport = FixtureApiJsonTransportByPath({
      '/v1/babies': {
        'items': [_baby('b1', '2026-10-12')],
      },
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner',
        babyId: 'b1',
        locale: 'zh-CN',
        accessToken: 'token',
      ),
      now: () => now,
      timezoneProvider: () async => 'Asia/Shanghai',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatFirstWorkspace(
            runtime: runtime,
            role: FamilyRole.mother,
            onOpenDrawer: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(catalog.entryFor(10)!.text), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime.utc(2026, 10, 22, 16, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('宝宝出生 11 天'), findsOneWidget);
    expect(find.text(catalog.entryFor(11)!.text), findsOneWidget);
    expect(find.text(catalog.entryFor(10)!.text), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'complete two-day baby records personalize day 42; missing or partial data fall back',
    (tester) async {
      final path = '/v1/babies/b1/records';
      final transport = FixtureApiJsonTransportByPath({
        '/v1/babies': {
          'items': [_baby('b1', '2026-09-10')],
        },
        path: {
          'items': [_feedingRecord('f1', 'b1', '2026-10-21T08:00:00Z')],
          'total': 1,
          'offset': 0,
          'limit': 100,
          'server_time': '2026-10-22T08:00:00Z',
        },
      });
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'owner',
          babyId: 'b1',
          locale: 'zh-CN',
          accessToken: 'token',
        ),
        now: () => DateTime.utc(2026, 10, 22, 8),
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWorkspace(
              runtime: runtime,
              role: FamilyRole.mother,
              onOpenDrawer: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('宝宝出生 42 天'), findsOneWidget);
      expect(find.textContaining('记录1次喂养'), findsOneWidget);
      expect(transport.lastQuery?['start_date'], '2026-10-21');
      expect(transport.lastQuery?['end_date'], '2026-10-23');
      expect(transport.lastQuery?['kind'], 'feeding');
      transport.responsesByPath[path] = {
        'items': [_feedingRecord('f1', 'b1', '2026-10-21T08:00:00Z')],
        'total': 2,
        'offset': 0,
        'limit': 100,
        'server_time': '2026-10-22T08:00:00Z',
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWorkspace(
              runtime: runtime,
              role: FamilyRole.mother,
              onOpenDrawer: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(catalog.entryFor(42)!.text), findsOneWidget);
      transport.responsesByPath.remove(path);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatFirstWorkspace(
              runtime: runtime,
              role: FamilyRole.mother,
              onOpenDrawer: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(catalog.entryFor(42)!.text), findsOneWidget);
    },
  );

  testWidgets(
    'selected baby age and known concern drive content, not mother date',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/babies': {
          'items': [_baby('b1', '2026-10-12'), _baby('b2', '2026-10-02')],
        },
        '/v1/profile/lactation': {'actual_delivery_date': '2026-10-01'},
        '/v1/profile/me-experience': {
          'concerns': [
            {'note': '宝宝为什么哭', 'ended': false},
          ],
        },
      });
      final runtime = MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'owner-1',
          babyId: 'b2',
          locale: 'zh-CN',
          accessToken: 'token',
        ),
        now: () => DateTime.utc(2026, 10, 22, 4),
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: ChatFirstWorkspace(
                runtime: runtime,
                role: FamilyRole.mother,
                onOpenDrawer: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('宝宝出生 20 天'), findsOneWidget);
      expect(find.text('宝宝出生 21 天'), findsNothing);
      expect(find.text(catalog.entryFor(20)!.text), findsOneWidget);
      expect(transport.getPaths, isNot(contains('/v1/profile/lactation')));
      expect(tester.takeException(), isNull);
      final existingWorkspace = tester.state(find.byType(ChatFirstWorkspace));

      final otherBaby = MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'owner-1',
          babyId: 'b1',
          locale: 'zh-CN',
          accessToken: 'token',
        ),
        now: () => DateTime.utc(2026, 10, 22, 4),
        timezoneProvider: () async => 'Asia/Shanghai',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: ChatFirstWorkspace(
                runtime: otherBaby,
                role: FamilyRole.mother,
                onOpenDrawer: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(ChatFirstWorkspace)),
        same(existingWorkspace),
      );
      expect(find.text('宝宝出生 10 天'), findsOneWidget);
      expect(find.text(catalog.entryFor(10)!.text), findsOneWidget);
      expect(find.text('宝宝出生 20 天'), findsNothing);
    },
  );

  testWidgets('long recommendation remains readable at 320 px and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FixtureApiJsonTransportByPath({
      '/v1/babies': {
        'items': [_baby('b1', '2026-10-12')],
      },
      '/v1/profile/me-experience': const {'concerns': <Object>[]},
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: 'b1',
        locale: 'zh-CN',
        accessToken: 'token',
      ),
      now: () => DateTime.utc(2026, 10, 22, 4),
      timezoneProvider: () async => 'Asia/Shanghai',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatFirstWorkspace(
            runtime: runtime,
            role: FamilyRole.mother,
            onOpenDrawer: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.byKey(const ValueKey('chat-first-daily-advice')),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final scroller = find.ancestor(
      of: find.byKey(const ValueKey('chat-first-daily-advice')),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(
      of: scroller,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(scroller, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown selection never borrows another baby or maternal date', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/babies': {
        'items': [_baby('b1', '2026-10-12')],
      },
      '/v1/profile/me-experience': const {'concerns': <Object>[]},
    });
    final runtime = MomCozyApiRuntime(
      jsonTransport: transport,
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'owner-1',
        babyId: 'unknown',
        locale: 'zh-CN',
        accessToken: 'token',
      ),
      now: () => DateTime.utc(2026, 10, 22, 4),
      timezoneProvider: () async => 'Asia/Shanghai',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: ChatFirstWorkspace(
              runtime: runtime,
              role: FamilyRole.mother,
              onOpenDrawer: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('宝宝出生'), findsNothing);
    expect(find.byKey(const ValueKey('chat-first-daily-advice')), findsNothing);
  });
}
