import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_mother_page.dart';
import 'package:momcozy_flutter_app/features/app_pages/data/chat_first_mother_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  final today = DateTime(2026, 10, 16, 12);
  const profile = <String, Object?>{
    'profile': {
      'age': 30,
      'delivery_count': 2,
      'actual_delivery_date': '2026-10-12',
      'gestation_weeks': 39,
      'gestation_days': 0,
      'baby_count': 1,
    },
    'concerns': [
      {'note': '奶量够不够', 'ended': false},
      {'note': '已结束的关注点', 'ended': true},
    ],
    'records': <Object>[],
  };

  Widget host(
    FixtureApiJsonTransportByPath transport, {
    FamilyRole role = FamilyRole.mother,
    String ownerUserId = 'owner-1',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatFirstMotherPage(
          runtime: MomCozyApiRuntime(
            jsonTransport: transport,
            session: MomCozySession(
              status: MomCozySessionStatus.authenticated,
              userId: ownerUserId,
              babyId: '',
              locale: 'zh-CN',
              accessToken: 'test-access',
            ),
            now: () => today,
            timezoneProvider: () async => 'Asia/Shanghai',
          ),
          role: role,
        ),
      ),
    );
  }

  test('partial saved maternal facts remain visible field by field', () {
    final summary = ChatFirstMotherSummary.fromMap({
      'profile': {'age': 31, 'actual_delivery_date': null},
      'concerns': const <Object>[],
    });
    expect(summary.age, 31);
    expect(summary.deliveryDate, isNull);
    expect(summary.deliveryCount, isNull);
  });

  test(
    'today pumping aggregation never reports an incomplete measured total',
    () {
      final complete = ChatFirstPumpingToday([
        const PumpMilkRecord(
          id: 'a',
          outputs: [
            PumpingOutput(breastSide: PumpingSide.unassigned, volumeMl: 45),
          ],
        ),
        const PumpMilkRecord(
          id: 'b',
          outputs: [
            PumpingOutput(breastSide: PumpingSide.unassigned, volumeMl: 30),
          ],
        ),
      ]);
      expect(complete.count, 2);
      expect(complete.measuredVolumeMl, 75);
      expect(complete.mayBeTruncated, isFalse);
      final partial = ChatFirstPumpingToday([
        ...complete.records,
        const PumpMilkRecord(id: 'no-volume'),
      ]);
      expect(partial.count, 3);
      expect(partial.measuredVolumeMl, isNull);
      final capped = ChatFirstPumpingToday(
        List.filled(100, complete.records.first),
      );
      expect(capped.mayBeTruncated, isTrue);
      expect(capped.measuredVolumeMl, isNull);
    },
  );

  test(
    'pumping read uses the local calendar day against the record API',
    () async {
      final transport = FixtureApiJsonTransportByPath(const {
        '/v1/records/pumping': {'items': <Object>[]},
      });
      final result = await ChatFirstMotherRepository(
        transport,
      ).getPumpingToday(today);
      expect(result.count, 0);
      expect(transport.lastPath, '/v1/records/pumping');
      final start = DateTime(today.year, today.month, today.day);
      expect(transport.lastQuery?['start_at'], start.toUtc().toIso8601String());
      expect(
        transport.lastQuery?['end_at'],
        DateTime(
          today.year,
          today.month,
          today.day + 1,
        ).toUtc().toIso8601String(),
      );
    },
  );

  test(
    'seven-day trend never treats missing days or incomplete windows as an exact average',
    () {
      List<MilkTrendDay> days({
        bool incomplete = false,
        bool unmeasured = false,
      }) => [
        for (var index = 0; index < 7; index++)
          MilkTrendDay(
            date: DateTime(2026, 10, 10 + index),
            measuredVolumeMl: index == 6 && !unmeasured && !incomplete
                ? 70
                : index == 6
                ? null
                : 0,
            pumpingCount: index == 6 ? 1 : 0,
            measuredPumpingCount: index == 6 && !unmeasured ? 1 : 0,
            complete: !incomplete,
          ),
      ];
      expect(ChatFirstMilkTrend(days()).averageDailyMl, 10);
      expect(ChatFirstMilkTrend(days(unmeasured: true)).averageDailyMl, isNull);
      expect(ChatFirstMilkTrend(days(incomplete: true)).averageDailyMl, isNull);
      expect(
        ChatFirstMilkTrend(days().take(6).toList()).averageDailyMl,
        isNull,
      );
      expect(ChatFirstMilkTrend(days()).hasSavedPumping, isTrue);
      final empty = ChatFirstMilkTrend([
        for (var index = 0; index < 7; index++)
          MilkTrendDay(
            date: DateTime(2026, 10, 10 + index),
            measuredVolumeMl: 0,
            pumpingCount: 0,
            measuredPumpingCount: 0,
            complete: true,
          ),
      ]);
      expect(empty.hasSavedPumping, isFalse);
      expect(empty.averageDailyMl, isNull);
    },
  );

  test(
    'week trend uses the device timezone without inventing unrecorded values',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/records/milk-trends': {
          'items': [
            for (var index = 0; index < 7; index++)
              {
                'date': '2026-10-${10 + index}',
                'pumped_milk_volume_ml': index == 6 ? 45 : 0,
                'pumping_count': index == 6 ? 1 : 0,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      final trend = await ChatFirstMotherRepository(
        transport,
      ).getMilkTrend(today, timezone: 'Asia/Shanghai');
      expect(transport.lastPath, '/v1/records/milk-trends');
      expect(transport.lastQuery, {
        'start_date': '2026-10-10',
        'days': 7,
        'include_today': true,
        'timezone': 'Asia/Shanghai',
      });
      expect(trend.averageDailyMl, closeTo(45 / 7, 0.001));
      expect(trend.days.first.pumpingCount, 0);
    },
  );

  test(
    'trend range follows account-local midnight rather than device day',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/records/milk-trends': {
          'items': [
            for (var day = 10; day <= 16; day++)
              {
                'date': '2026-10-$day',
                'pumped_milk_volume_ml': 0,
                'pumping_count': 0,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      await ChatFirstMotherRepository(transport).getMilkTrend(
        DateTime.utc(2026, 10, 16, 18),
        timezone: 'Pacific/Honolulu',
      );
      expect(transport.lastQuery?['start_date'], '2026-10-10');
    },
  );

  test(
    'a stale or shifted trend window cannot be shown as the current week',
    () async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/records/milk-trends': {
          'items': [
            for (var index = 0; index < 7; index++)
              {
                'date': '2026-10-${(9 + index).toString().padLeft(2, '0')}',
                'pumped_milk_volume_ml': 45,
                'pumping_count': 1,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      await expectLater(
        ChatFirstMotherRepository(
          transport,
        ).getMilkTrend(today, timezone: 'Asia/Shanghai'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'maternal status dates use account midnight across UTC boundary',
    () async {
      final transport = _TrackingWellbeingTransport({
        '/v1/profile/me-experience': {
          'records': [
            {
              'id': 'mood',
              'kind': 'mood',
              'occurred_at': '2026-10-22T16:30:00Z',
              'value': 'Good',
            },
          ],
        },
      });
      final result = await ChatFirstMotherRepository(
        transport,
      ).getWellbeing(DateTime.utc(2026, 10, 22, 17), timezone: 'Asia/Shanghai');
      expect(result.days.last.date.day, 23);
      expect(result.days.last.records.single.kind, MeMetric.mood);
      expect(transport.queries.last['start'], '2026-10-22T16:00:00.000Z');
    },
  );

  testWidgets('trend and status cards use the full phone content width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transport = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': profile,
      '/v1/records/pumping': const {'items': <Object>[]},
      '/v1/records/milk-trends': {
        'items': [
          for (var index = 0; index < 7; index++)
            {
              'date': '2026-10-${10 + index}',
              'pumped_milk_volume_ml': 0,
              'pumping_count': 0,
              'measured_only': true,
              'complete': true,
            },
        ],
      },
    });
    await tester.pumpWidget(host(transport));
    await tester.pumpAndSettle();
    for (final title in const ['奶量趋势', '身体与状态']) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(Card),
      );
      expect(tester.getSize(card).width, greaterThan(320));
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'weekly trend previews actual records and exposes all seven days',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': {'items': <Object>[]},
        '/v1/records/milk-trends': {
          'items': [
            for (var index = 0; index < 7; index++)
              {
                'date': '2026-10-${10 + index}',
                'pumped_milk_volume_ml': index == 6 ? 45 : 0,
                'pumping_count': index == 6 ? 1 : 0,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('奶量趋势'), findsOneWidget);
      expect(find.text('近 7 天有 1 天保存吸奶记录'), findsOneWidget);
      expect(find.textContaining('328'), findsNothing);
      final row = find.byKey(const ValueKey('mother-milk-row-10-16'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('45 ml · 1 次')),
        findsOneWidget,
      );
      final open = find.byKey(const ValueKey('mother-milk-trend'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('近 7 天记录奶量'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('10月16日')).dy,
        lessThan(tester.getTopLeft(find.text('10月15日')).dy),
        reason: 'The newest saved day should be visible before older days.',
      );
      expect(
        tester
            .getRect(find.byType(BottomSheet))
            .contains(
              tester.getCenter(
                find.descendant(
                  of: find.byType(BottomSheet),
                  matching: find.text('45 ml · 1 次'),
                ),
              ),
            ),
        isTrue,
      );
      expect(find.text('按 7 天均摊已记录奶量 6.4 ml/天；未记录不代表没有吸奶。'), findsOneWidget);
      expect(find.text('未记录'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('10月16日'),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('10月16日'), findsOneWidget);
      expect(find.text('45 ml · 1 次'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('mother-milk-trend-close')));
      await tester.pumpAndSettle();
      expect(find.text('近 7 天记录奶量'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('incomplete trends never present an exact seven-day average', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': profile,
      '/v1/records/pumping': {'items': <Object>[]},
      '/v1/records/milk-trends': {
        'items': [
          for (var index = 0; index < 7; index++)
            {
              'date': '2026-10-${10 + index}',
              'pumped_milk_volume_ml': index == 6 ? 45 : 0,
              'pumping_count': index == 6 ? 1 : 0,
              'measured_only': index != 6,
              'complete': true,
            },
        ],
      },
    });
    await tester.pumpWidget(host(transport));
    await tester.pumpAndSettle();
    expect(find.text('奶量趋势'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('mother-milk-trend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mother-milk-trend')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('10月16日'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('有记录 · 奶量未完整填写'), findsOneWidget);
    expect(find.textContaining('均摊已记录奶量'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'weekly trend failure offers its own retry without removing profile',
    (tester) async {
      final transport = _FailingMilkTrendTransport({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': const {'items': <Object>[]},
        '/v1/records/milk-trends': {
          'items': [
            for (var index = 0; index < 7; index++)
              {
                'date': '2026-10-${10 + index}',
                'pumped_milk_volume_ml': 0,
                'pumping_count': 0,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法加载奶量趋势'), findsOneWidget);
      expect(find.text('产后第 4 天'), findsOneWidget);
      expect(find.text('30 岁'), findsOneWidget);
      transport.fail = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-milk-trend-retry')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-milk-trend-retry')));
      await tester.pumpAndSettle();
      expect(find.text('近 7 天没有保存吸奶记录'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'body and mood history uses two bounded local days and only saved owner data',
    () async {
      final transport = _TrackingWellbeingTransport({
        '/v1/profile/me-experience': {
          'records': [
            {
              'id': 'energy-1',
              'kind': 'energy',
              'occurred_at': '2026-10-16T02:00:00Z',
              'value': 'Energized',
            },
            {
              'id': 'mood-1',
              'kind': 'mood',
              'occurred_at': '2026-10-15T03:00:00Z',
              'value': '不太好',
            },
            {
              'id': 'pump-legacy',
              'kind': 'pump',
              'occurred_at': '2026-10-16T02:00:00Z',
              'value': '999 ml',
            },
          ],
        },
      });
      final status = await ChatFirstMotherRepository(
        transport,
      ).getWellbeing(today);
      expect(status.recordCount, 2);
      expect(status.days[0].records.single.kind, MeMetric.mood);
      expect(status.days[1].records.single.kind, MeMetric.energy);
      final yesterday = DateTime(2026, 10, 15);
      final todayStart = DateTime(2026, 10, 16);
      final tomorrow = DateTime(2026, 10, 17);
      expect(
        transport.queries,
        containsAll([
          {
            'start': yesterday.toUtc().toIso8601String(),
            'end': todayStart.toUtc().toIso8601String(),
          },
          {
            'start': todayStart.toUtc().toIso8601String(),
            'end': tomorrow.toUtc().toIso8601String(),
          },
        ]),
      );
      expect(
        transport.queries.every((query) => !query.containsKey('user_id')),
        isTrue,
      );
    },
  );

  testWidgets(
    'real body and mood observations appear without invented analysis',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': {
          ...profile,
          'records': [
            {
              'id': 'energy-1',
              'kind': 'energy',
              'occurred_at': '2026-10-16T02:00:00Z',
              'value': 'Energized',
            },
            {
              'id': 'mood-1',
              'kind': 'mood',
              'occurred_at': '2026-10-15T03:00:00Z',
              'value': '不太好',
            },
            {
              'id': 'pump-legacy',
              'kind': 'pump',
              'occurred_at': '2026-10-16T02:00:00Z',
              'value': '999 ml',
            },
          ],
        },
        '/v1/records/pumping': const {'items': <Object>[]},
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('身体与状态'), findsOneWidget);
      expect(find.text('最近 2 天有 2 条已保存状态记录'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-wellbeing')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing')));
      await tester.pumpAndSettle();
      expect(find.text('精力'), findsWidgets);
      expect(find.text('有力气'), findsWidgets);
      expect(find.text('心情'), findsWidgets);
      expect(find.text('不太好'), findsWidgets);
      expect(find.textContaining('999 ml'), findsNothing);
      expect(find.textContaining('诊断'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing-close')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed body history shows retry and keeps the maternal profile',
    (tester) async {
      final transport = _FailingWellbeingTransport({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': const {'items': <Object>[]},
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法加载状态记录'), findsOneWidget);
      expect(find.text('30 岁'), findsOneWidget);
      transport.fail = false;
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-wellbeing-retry')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing-retry')));
      await tester.pumpAndSettle();
      expect(find.text('最近 2 天没有已保存状态记录'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unreviewed state text is not echoed as a health conclusion', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath({
      '/v1/profile/me-experience': {
        ...profile,
        'records': [
          {
            'id': 'legacy-energy',
            'kind': 'energy',
            'occurred_at': '2026-10-16T02:00:00Z',
            'value': 'unreviewed private note',
          },
        ],
      },
      '/v1/records/pumping': const {'items': <Object>[]},
    });
    await tester.pumpWidget(host(transport));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('mother-wellbeing')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mother-wellbeing')));
    await tester.pumpAndSettle();
    expect(find.text('记录内容需核对'), findsWidgets);
    expect(find.textContaining('unreviewed private note'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'narrow 2x mother trend and body details keep close actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final transport = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': {
          ...profile,
          'records': [
            {
              'id': 'energy-1',
              'kind': 'energy',
              'occurred_at': '2026-10-16T02:00:00Z',
              'value': 'Energized',
            },
          ],
        },
        '/v1/records/pumping': const {'items': <Object>[]},
        '/v1/records/milk-trends': {
          'items': [
            for (var index = 0; index < 7; index++)
              {
                'date': '2026-10-${10 + index}',
                'pumped_milk_volume_ml': index == 6 ? 45 : 0,
                'pumping_count': index == 6 ? 1 : 0,
                'measured_only': true,
                'complete': true,
              },
          ],
        },
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-milk-trend')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-milk-trend')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('10月16日'),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('mother-milk-trend-close')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-wellbeing')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-wellbeing')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing-close')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'mother overview reads the same real pumping records saved from chat',
    (tester) async {
      final transport = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': {
          'items': [
            {
              'id': 'pump-1',
              'pump_start_time': today
                  .subtract(const Duration(hours: 2))
                  .toUtc()
                  .toIso8601String(),
              'milk_volume_ml': 45,
            },
            {
              'id': 'pump-2',
              'pump_start_time': today
                  .subtract(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'milk_volume_ml': 30,
            },
          ],
        },
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('30 岁'), findsOneWidget);
      expect(find.text('奶量够不够'), findsOneWidget);
      expect(find.text('已结束的关注点'), findsNothing);
      expect(find.text('75 ml · 2 次'), findsOneWidget);
      expect(transport.getPaths, contains('/v1/records/pumping'));
      expect(transport.getPaths, isNot(contains('/v1/lactation/records')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-pumping-details')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-pumping-details')));
      await tester.pumpAndSettle();
      expect(find.text('45 ml'), findsOneWidget);
      expect(find.text('30 ml'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mother-pumping-close')));
      await tester.pumpAndSettle();
      expect(find.text('今天的吸奶记录'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pumping read failure never turns saved maternal facts into demo data',
    (tester) async {
      final transport = _FailingPumpingTransport({
        '/v1/profile/me-experience': profile,
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('30 岁'), findsOneWidget);
      expect(find.text('暂时无法读取吸奶记录'), findsOneWidget);
      expect(find.text('75 ml · 2 次'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'switching account never exposes a previous owner pumping action',
    (tester) async {
      final first = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': {
          'items': [
            {
              'id': 'old-pump',
              'pump_start_time': today.toUtc().toIso8601String(),
              'milk_volume_ml': 45,
            },
          ],
        },
      });
      await tester.pumpWidget(host(first));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mother-pumping-details')),
        findsOneWidget,
      );

      final pending = Completer<Map<String, Object?>>();
      final next = _PendingPumpingTransport({
        '/v1/profile/me-experience': profile,
      }, pending);
      await tester.pumpWidget(host(next, ownerUserId: 'owner-2'));
      await tester.pump();
      expect(find.text('正在读取今天的吸奶记录…'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mother-pumping-details')),
        findsNothing,
      );
      expect(find.text('45 ml · 1 次'), findsNothing);
      pending.complete({'items': <Object>[]});
      await tester.pumpAndSettle();
      expect(find.text('今天还没有吸奶记录'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'narrow large-text mother overview and record sheet remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final transport = FixtureApiJsonTransportByPath({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': {
          'items': [
            {
              'id': 'pump-1',
              'pump_start_time': today.toUtc().toIso8601String(),
              'milk_volume_ml': 45,
            },
          ],
        },
      });
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('查看旧版泌乳管理'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mother-pumping-details')),
        -160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-pumping-details')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-pumping-details')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('45 ml'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('mother can refresh the overview after saving a pumping record', (
    tester,
  ) async {
    final responses = <String, Map<String, Object?>>{
      '/v1/profile/me-experience': profile,
      '/v1/records/pumping': {'items': <Object>[]},
    };
    final transport = FixtureApiJsonTransportByPath(responses);
    await tester.pumpWidget(host(transport));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有吸奶记录'), findsOneWidget);
    responses['/v1/records/pumping'] = {
      'items': [
        {
          'id': 'saved-pump',
          'pump_start_time': today.toUtc().toIso8601String(),
          'milk_volume_ml': 45,
        },
      ],
    };
    await tester.ensureVisible(
      find.byKey(const ValueKey('mother-pumping-refresh')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mother-pumping-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('45 ml · 1 次'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('non-mother never requests maternal or pumping data', (
    tester,
  ) async {
    final transport = FixtureApiJsonTransportByPath(const {});
    await tester.pumpWidget(host(transport, role: FamilyRole.father));
    await tester.pumpAndSettle();
    expect(find.text('未填写妈妈资料'), findsOneWidget);
    expect(transport.getPaths, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
}

class _FailingPumpingTransport extends FixtureApiJsonTransportByPath {
  _FailingPumpingTransport(super.responsesByPath);

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (path == '/v1/records/pumping') throw StateError('network offline');
    return super.getJson(path, query: query);
  }
}

class _FailingMilkTrendTransport extends FixtureApiJsonTransportByPath {
  _FailingMilkTrendTransport(super.responsesByPath);
  bool fail = true;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (fail && path == '/v1/records/milk-trends') throw StateError('offline');
    return super.getJson(path, query: query);
  }
}

class _PendingPumpingTransport extends FixtureApiJsonTransportByPath {
  _PendingPumpingTransport(super.responsesByPath, this.pending);

  final Completer<Map<String, Object?>> pending;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (path == '/v1/records/pumping') return pending.future;
    return super.getJson(path, query: query);
  }
}

class _TrackingWellbeingTransport extends FixtureApiJsonTransportByPath {
  _TrackingWellbeingTransport(super.responsesByPath);
  final queries = <Map<String, Object?>>[];

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (path == '/v1/profile/me-experience') {
      queries.add(Map<String, Object?>.from(query));
    }
    return super.getJson(path, query: query);
  }
}

class _FailingWellbeingTransport extends FixtureApiJsonTransportByPath {
  _FailingWellbeingTransport(super.responsesByPath);
  bool fail = true;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    if (fail &&
        path == '/v1/profile/me-experience' &&
        query['start'] == DateTime(2026, 10, 15).toUtc().toIso8601String()) {
      throw StateError('offline');
    }
    return super.getJson(path, query: query);
  }
}
