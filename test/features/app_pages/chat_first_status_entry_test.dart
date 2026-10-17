import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/app_pages/chat_first_mother_page.dart';
import 'package:momcozy_flutter_app/features/app_pages/data/chat_first_mother_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/chat_first_onboarding.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  final now = DateTime(2026, 10, 16, 12);
  const profile = <String, Object?>{
    'profile': {
      'age': 30,
      'delivery_count': 2,
      'actual_delivery_date': '2026-10-15',
      'gestation_weeks': 39,
      'gestation_days': 0,
      'baby_count': 1,
    },
    'concerns': <Object>[],
  };

  Widget host(
    _StatusTransport transport, {
    FamilyRole role = FamilyRole.mother,
    String ownerUserId = 'owner-1',
  }) => MaterialApp(
    home: Scaffold(
      body: ChatFirstMotherPage(
        runtime: MomCozyApiRuntime(
          jsonTransport: transport,
          session: MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: ownerUserId,
            babyId: '',
            locale: 'zh-CN',
            accessToken: 'owner-token',
          ),
          now: () => now,
          timezoneProvider: () async => 'Asia/Shanghai',
        ),
        role: role,
      ),
    ),
  );

  test(
    'only approved self-reported choices can be saved by ID-scoped PUT',
    () async {
      final transport = _StatusTransport(profile);
      final repo = ChatFirstMotherRepository(transport);
      final id = '7bd65014-b810-4325-b284-16f642488649';
      final saved = await repo.saveWellbeing(
        id: id,
        kind: MeMetric.mood,
        value: '一般',
        occurredAt: now,
      );
      expect(saved.id, id);
      expect(saved.kind, MeMetric.mood);
      expect(saved.value, '一般');
      expect(transport.putPaths, ['/v1/profile/me-experience/records/$id']);
      expect(
        transport.putBodies.single['occurred_at'],
        now.toUtc().toIso8601String(),
      );
      expect(transport.putBodies.single['fields'], isEmpty);
      expect(transport.putBodies.single.containsKey('owner_user_id'), isFalse);
      await expectLater(
        repo.saveWellbeing(
          id: id,
          kind: MeMetric.pain,
          value: '5 / 10',
          occurredAt: now,
        ),
        throwsFormatException,
      );
      await expectLater(
        repo.saveWellbeing(
          id: id,
          kind: MeMetric.mood,
          value: '医学诊断',
          occurredAt: now,
        ),
        throwsFormatException,
      );
      await expectLater(
        repo.saveWellbeing(
          id: '../other-owner',
          kind: MeMetric.mood,
          value: '一般',
          occurredAt: now,
        ),
        throwsFormatException,
      );
      expect(transport.putPaths, hasLength(1));
    },
  );

  test('a mismatched server echo never confirms a status write', () async {
    final transport = _StatusTransport(profile)..wrongEcho = true;
    final repository = ChatFirstMotherRepository(transport);
    await expectLater(
      repository.saveWellbeing(
        id: '7bd65014-b810-4325-b284-16f642488649',
        kind: MeMetric.mood,
        value: '一般',
        occurredAt: now,
      ),
      throwsFormatException,
    );
    expect(transport.putPaths, hasLength(1));
  });

  testWidgets(
    'mother saves her own status and sees an authoritative readback',
    (tester) async {
      final transport = _StatusTransport(profile);
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      expect(find.text('最近 2 天没有已保存状态记录'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mother-status-add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('保存到当前账号后才会出现在最近状态中'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mother-status-kind-mood')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-value-一般')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mother-status-sheet')), findsNothing);
      expect(find.text('最近 2 天有 1 条已保存状态记录'), findsOneWidget);
      expect(transport.putBodies.single['value'], '一般');
      await tester.tap(find.byKey(const ValueKey('mother-wellbeing')));
      await tester.pumpAndSettle();
      expect(find.text('心情'), findsOneWidget);
      expect(find.text('一般'), findsOneWidget);
      expect(find.textContaining('诊断'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed save preserves the exact record ID and choice for retry',
    (tester) async {
      final transport = _StatusTransport(profile)..failFirstPut = true;
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-kind-energy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-value-有力气')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mother-status-sheet')), findsOneWidget);
      expect(find.textContaining('尚未确认保存'), findsOneWidget);
      expect(find.text('最近 2 天有 1 条已保存状态记录'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('mother-status-value-有力气')),
            )
            .onSelected,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('mother-status-save')));
      await tester.pumpAndSettle();
      expect(transport.putPaths, hasLength(2));
      expect(transport.putPaths[1], transport.putPaths[0]);
      expect(transport.putBodies[1], transport.putBodies[0]);
      expect(find.text('最近 2 天有 1 条已保存状态记录'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'non-mother never sees status entry or makes a maternal request',
    (tester) async {
      final transport = _StatusTransport(profile);
      await tester.pumpWidget(host(transport, role: FamilyRole.father));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mother-status-add')), findsNothing);
      expect(transport.getPaths, isEmpty);
      expect(transport.putPaths, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'switching account while the editor is open cannot save as the new owner',
    (tester) async {
      final transport = _StatusTransport(profile);
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-kind-mood')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-value-一般')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(transport, ownerUserId: 'owner-2'));
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('mother-status-sheet'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('mother-status-save')));
        await tester.pumpAndSettle();
      }
      expect(transport.putPaths, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'small phone at 2x keeps status close and save targets reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final transport = _StatusTransport(profile);
      await tester.pumpWidget(host(transport));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('mother-status-add')),
      );
      await tester.tap(find.byKey(const ValueKey('mother-status-add')));
      await tester.pumpAndSettle();
      final close = find.byKey(const ValueKey('mother-status-close'));
      final save = find.byKey(const ValueKey('mother-status-save'));
      expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).last, const Offset(0, -130));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-kind-mood')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mother-status-value-一般')),
        90,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -70));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mother-status-value-一般')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mother-status-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

class _StatusTransport extends FixtureApiJsonTransportByPath {
  _StatusTransport(this.profile)
    : super({
        '/v1/profile/me-experience': profile,
        '/v1/records/pumping': const {'items': <Object>[]},
      });

  final Map<String, Object?> profile;
  final putPaths = <String>[];
  final putBodies = <Map<String, Object?>>[];
  bool failFirstPut = false;
  bool wrongEcho = false;
  Map<String, Object?>? saved;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/profile/me-experience') {
      getPaths.add(path);
      return {
        ...profile,
        'records': [?saved],
      };
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    putPaths.add(path);
    putBodies.add(Map<String, Object?>.from(body));
    if (failFirstPut) {
      failFirstPut = false;
      throw StateError('transport interrupted');
    }
    saved = Map<String, Object?>.from(body);
    return wrongEcho ? {...saved!, 'id': 'different-record'} : saved!;
  }
}
