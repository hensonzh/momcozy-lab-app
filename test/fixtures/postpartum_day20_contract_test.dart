import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/body_profile/data/body_profile_api_repository.dart';
import 'package:momcozy_flutter_app/features/notifications/data/notifications_api_repository.dart';
import 'package:momcozy_flutter_app/features/plan/data/plan_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/maternal_care_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';
import 'package:momcozy_flutter_app/features/records/data/records_api_repository.dart';
import 'package:momcozy_flutter_app/features/records/domain/records.dart';

import '../support/fixture_api_transport.dart';

void main() {
  late Map<String, Object?> fixture;
  late Map<String, Object?> records;
  late Map<String, Object?> productSchemas;
  late String infantId;

  setUpAll(() {
    fixture = _map(
      jsonDecode(
        File('test/fixtures/postpartum_day20.json').readAsStringSync(),
      ),
    );
    records = _map(fixture['records']);
    productSchemas = _map(
      _map(
        _map(
          jsonDecode(
            File(
              'docs/backend-contract/product.openapi.generated.json',
            ).readAsStringSync(),
          ),
        )['components'],
      )['schemas'],
    );
    infantId = _map(_items(_map(fixture['infants'])).single)['id']! as String;
  });

  test('uses frozen Product response fields in the canonical fixture', () {
    expect(
      _map(fixture['meta'])['schema_version'],
      'momcozy.postpartum_day20.v5',
    );
    final profile = _map(fixture['profile']);
    final infant = _map(_items(_map(fixture['infants'])).single);
    final body = _map(fixture['body_profile']);
    final care = _map(fixture['care_overview']);

    for (final field in [
      'delivery_date',
      'expected_due_date',
      'lactation_advice',
      'feeding_advice',
      'profile_onboarding_complete',
    ]) {
      expect(profile, isNot(contains(field)));
    }
    for (final field in ['owner_user_id', 'status']) {
      expect(infant, isNot(contains(field)));
    }
    expect(infant['sex'], 'female');
    for (final field in ['owner_user_id', 'recovery_score', 'delivery_type']) {
      expect(body, isNot(contains(field)));
    }
    expect(care, isNot(contains('capabilities')));
    expect(care, isNot(contains('generated_at')));

    _expectItemsMatchSchema(
      response: _map(records['feeding']),
      schema: _map(productSchemas['FeedingRecordRead']),
    );
    _expectItemsMatchSchema(
      response: _map(records['pumping']),
      schema: _map(productSchemas['PumpingRecordRead']),
    );
    _expectItemsMatchSchema(
      response: _map(records['milk_trends']),
      schema: _map(productSchemas['MilkTrendDayRead']),
    );
  });

  test('maps the Day 20 profile, care overview, and body profile', () async {
    final profile = await ProfileOverviewApiRepository(
      transport: FixtureApiJsonTransportByPath({
        profileMeEndpoint: _map(fixture['profile']),
        profileInfantsEndpoint: _map(fixture['infants']),
        profilePregnancyFactEndpoint: const {'items': <Object?>[]},
      }),
      babyId: infantId,
      now: () => DateTime(2026, 8, 8, 12),
    ).fetchOverview();
    final care = await MaternalCareOverviewApiRepository(
      transport: FixtureApiJsonTransport(_map(fixture['care_overview'])),
    ).fetchOverview(onDate: DateTime(2026, 8, 8));
    final body = await BodyProfileApiRepository(
      transport: FixtureApiJsonTransport(_map(fixture['body_profile'])),
    ).fetchProfile();

    expect(profile.mom?.stage, MomLifeStage.postpartum);
    expect(profile.mom?.postpartumDay, 20);
    expect(profile.mom?.deliveryType, DeliveryType.vaginal);
    expect(profile.baby?.ageDays, 20);
    expect(profile.baby?.nickname, '小满');
    expect(profile.baby?.sex, 'female');
    expect(profile.baby?.birthDate, profile.mom?.actualDeliveryDate);
    expect(care.program?.completedSessions, 8);
    expect(care.program?.totalSessions, 14);
    expect(body.hasConfirmedData, isTrue);
    expect(body.painAreas, hasLength(2));
  });

  test(
    'maps the complete feeding, pumping, sleep, diaper, and growth journey',
    () async {
      final feedingFixture = _map(records['feeding']);
      final pumpingFixture = _map(records['pumping']);
      final sleepFixture = _map(records['sleep']);
      final diaperFixture = _map(records['diaper']);

      final feedings =
          await RecordsApiRepository(
            transport: FixtureApiJsonTransport(feedingFixture),
          ).fetchFeedingRecordsRange(
            start: DateTime(2026, 8, 2),
            end: DateTime(2026, 8, 9),
            babyId: infantId,
          );
      final pumpings =
          await RecordsApiRepository(
            transport: FixtureApiJsonTransport(pumpingFixture),
          ).fetchPumpMilkRecordsRange(
            start: DateTime(2026, 8, 2),
            end: DateTime(2026, 8, 9),
          );
      final sleeps =
          await RecordsApiRepository(
            transport: FixtureApiJsonTransport(sleepFixture),
          ).fetchSleepRecords(
            babyId: infantId,
            start: DateTime(2026, 8, 2),
            end: DateTime(2026, 8, 9),
          );
      final diapers =
          await RecordsApiRepository(
            transport: FixtureApiJsonTransport(diaperFixture),
          ).fetchDiaperRecords(
            babyId: infantId,
            start: DateTime(2026, 8, 2),
            end: DateTime(2026, 8, 9),
          );
      final growth = await RecordsApiRepository(
        transport: FixtureApiJsonTransport(_map(records['growth'])),
      ).fetchGrowthRecords(babyId: infantId);

      final todayFeedingIds = _todayIds(feedingFixture, 'feed_time');
      final todayPumpingIds = _todayIds(pumpingFixture, 'pump_start_time');
      final todaySleepIds = _todayIds(sleepFixture, 'started_at');
      final todayDiaperIds = _todayIds(diaperFixture, 'changed_at');
      final todayFeedings = feedings
          .where((record) => todayFeedingIds.contains(record.id))
          .toList();
      final todayPumpings = pumpings
          .where((record) => todayPumpingIds.contains(record.id))
          .toList();
      final todaySleeps = sleeps
          .where((record) => todaySleepIds.contains(record.id))
          .toList();
      final todayDiapers = diapers
          .where((record) => todayDiaperIds.contains(record.id))
          .toList();

      expect(todayFeedings, hasLength(8));
      expect(
        todayFeedings.where(
          (record) => record.feedingMethod == FeedingMethod.directBreastfeeding,
        ),
        hasLength(2),
      );
      expect(
        todayFeedings.fold<double>(
          0,
          (total, record) => total + (record.measuredVolumeMl ?? 0),
        ),
        450,
      );
      expect(todayPumpings, hasLength(6));
      expect(
        todayPumpings.fold<double>(
          0,
          (total, record) => total + (record.measuredVolumeMl ?? 0),
        ),
        610,
      );
      expect(
        todaySleeps.fold<int>(
          0,
          (total, record) => total + (record.duration?.inMinutes ?? 0),
        ),
        900,
      );
      expect(todayDiapers, hasLength(8));
      expect(todayDiapers.where((record) => record.includesWet), hasLength(7));
      expect(
        todayDiapers.where((record) => record.includesDirty),
        hasLength(3),
      );
      expect(growth, hasLength(4));
      expect(growth.last.weightKg, 3.5);
    },
  );

  test(
    'maps plans, trends, and notification state used by the product UI',
    () async {
      final todayTasks = _items(_map(fixture['plan_tasks']))
          .map(_map)
          .where((item) => item['task_date'] == '2026-08-08')
          .toList(growable: false);
      final dashboard = await PlanApiRepository(
        transport: FixtureApiJsonTransportByPath({
          planListEndpoint: _map(fixture['plans']),
          planSessionListEndpoint: {'items': todayTasks},
        }),
      ).fetchDashboard(weekOf: DateTime(2026, 8, 8));
      final milkTrends =
          await RecordsApiRepository(
            transport: FixtureApiJsonTransport(_map(records['milk_trends'])),
          ).fetchMilkTrends(
            startDate: DateTime(2026, 8, 2),
            days: 7,
            utcOffsetMinutes: 480,
          );
      final notifications = await NotificationsApiRepository(
        transport: FixtureApiJsonTransport(_map(fixture['notifications'])),
      ).fetchNotifications();

      expect(dashboard.plans, hasLength(1));
      expect(dashboard.sessions, hasLength(2));
      expect(milkTrends.map((item) => item.measuredVolumeMl), [
        590,
        605,
        620,
        635,
        650,
        665,
        610,
      ]);
      expect(notifications, hasLength(3));
      expect(notifications.where((item) => item.isUnread), hasLength(2));
    },
  );
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

List<Object?> _items(Map<String, Object?> value) =>
    List<Object?>.from(value['items']! as List);

Set<String> _todayIds(Map<String, Object?> response, String timestampKey) =>
    _items(response)
        .map(_map)
        .where(
          (item) => (item[timestampKey]! as String).startsWith('2026-08-08T'),
        )
        .map((item) => item['id']! as String)
        .toSet();

void _expectItemsMatchSchema({
  required Map<String, Object?> response,
  required Map<String, Object?> schema,
}) {
  final allowedFields = _map(schema['properties']).keys.toSet();
  final requiredFields = Set<String>.from(
    (schema['required'] as List<Object?>? ?? const <Object?>[])
        .whereType<String>(),
  );

  for (final rawItem in _items(response)) {
    final itemFields = _map(rawItem).keys.toSet();
    expect(itemFields.difference(allowedFields), isEmpty);
    expect(itemFields, containsAll(requiredFields));
  }
}
