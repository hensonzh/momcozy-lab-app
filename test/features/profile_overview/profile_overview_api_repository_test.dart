import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/mom_life_stage.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('ProfileOverviewApiRepository', () {
    test('maps production profile and infant overview', () async {
      final transport = FixtureApiJsonTransportByPath({
        profileMeEndpoint: {
          'user_id': 'user-001',
          'display_name': 'Mom',
          'current_care_stage': 'postpartum',
          'actual_delivery_date': '2026-05-20',
          'delivery_type': 'vaginal',
        },
        profileInfantsEndpoint: {
          'items': [
            {
              'id': 'infant-001',
              'owner_user_id': 'user-001',
              'infant_name': 'Baby',
              'birth_date': '2026-05-20',
              'sex': 'female',
              'status': 'active',
            },
          ],
        },
        profilePregnancyFactEndpoint: {
          'items': [
            {
              'fact_key': pregnancyDueDateOrWeekFactKey,
              'fact_kind': 'verified',
              'status': 'active',
              'value': '孕 32 周',
            },
          ],
        },
      });
      final repository = ProfileOverviewApiRepository(
        transport: transport,
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(transport.postedBodies, isEmpty);
      expect(
        transport.getPaths,
        containsAll(<String>[
          profileMeEndpoint,
          profileInfantsEndpoint,
          profilePregnancyFactEndpoint,
        ]),
      );
      expect(transport.lastPath, profilePregnancyFactEndpoint);
      expect(transport.lastQuery, {
        'fact_kind': 'verified',
        'fact_key': pregnancyDueDateOrWeekFactKey,
        'limit': 1,
      });
      expect(overview.mom?.stage, MomLifeStage.postpartum);
      expect(overview.mom?.displayName, 'Mom');
      expect(overview.mom?.postpartumDay, 42);
      expect(overview.mom?.actualDeliveryDate, DateTime.parse('2026-05-20'));
      expect(overview.mom?.deliveryType, DeliveryType.vaginal);
      expect(overview.mom?.dueDateOrWeek, isNull);
      expect(overview.baby?.id, 'infant-001');
      expect(overview.baby?.nickname, 'Baby');
      expect(overview.baby?.ageDays, 42);
      expect(overview.baby?.birthDate, DateTime.parse('2026-05-20'));
      expect(overview.baby?.sex, 'female');
    });

    test('maps an explicit stage without date inference', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {
            'user_id': 'user-001',
            'current_care_stage': 'fertility',
          },
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom?.stage, MomLifeStage.fertility);
    });

    test('maps only the canonical date for the active stage', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {
            'user_id': 'user-001',
            'current_care_stage': 'postpartum',
            'expected_due_date': '2026-07-21',
            'actual_delivery_date': '2026-07-01',
          },
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 7, 21),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom?.postpartumDay, 20);
      expect(overview.mom?.expectedDueDate, isNull);
      expect(overview.mom?.actualDeliveryDate, DateTime.parse('2026-07-01'));
    });

    test('does not expose an old postpartum date in pregnancy', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {
            'user_id': 'user-001',
            'current_care_stage': 'pregnancy',
            'expected_due_date': '2026-10-31',
            'actual_delivery_date': '2026-07-01',
          },
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 8, 8),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom?.stage, MomLifeStage.pregnancy);
      expect(overview.mom?.expectedDueDate, DateTime.parse('2026-10-31'));
      expect(overview.mom?.actualDeliveryDate, isNull);
      expect(overview.mom?.postpartumDay, isNull);
    });

    test('does not infer profile state from removed delivery_date', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {
            'user_id': 'legacy-user',
            'delivery_date': '2026-06-30',
          },
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom, isNull);
    });

    test(
      'updates the current stage through the authenticated profile',
      () async {
        final transport = FixtureApiJsonTransportByPath(
          const {},
          writeResponsesByPath: const {
            profileMeEndpoint: {
              'user_id': 'user-001',
              'current_care_stage': 'pregnancy',
            },
          },
        );
        final repository = ProfileOverviewApiRepository(
          transport: transport,
          babyId: 'infant-001',
        );

        final stage = await repository.updateCareStage(MomLifeStage.pregnancy);

        expect(stage, MomLifeStage.pregnancy);
        expect(transport.lastMethod, 'PUT');
        expect(transport.lastPath, profileMeEndpoint);
        expect(transport.lastBody, {'current_care_stage': 'pregnancy'});
      },
    );

    test(
      'updates delivery type through the maternal profile contract',
      () async {
        final transport = FixtureApiJsonTransportByPath(
          const {},
          writeResponsesByPath: const {
            profileMeEndpoint: {
              'user_id': 'user-001',
              'current_care_stage': 'postpartum',
              'delivery_type': 'cesarean',
            },
          },
        );
        final repository = ProfileOverviewApiRepository(
          transport: transport,
          babyId: 'infant-001',
        );

        final deliveryType = await repository.updateDeliveryType(
          DeliveryType.cesarean,
        );

        expect(deliveryType, DeliveryType.cesarean);
        expect(transport.lastMethod, 'PUT');
        expect(transport.lastPath, profileMeEndpoint);
        expect(transport.lastBody, {'delivery_type': 'cesarean'});
      },
    );

    test('maps empty profile and infants list', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {'user_id': 'user-001'},
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
        now: () => DateTime.utc(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom, isNull);
      expect(overview.baby, isNull);
    });

    test('preserves production HTTP failures', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {
            'http_status': 500,
            'status_text': 'Server Error',
            'body': {
              'error': {
                'code': 'dependency_failed',
                'message': 'Profile unavailable',
                'request_id': 'req-profile-001',
              },
            },
          },
        }),
        babyId: 'infant-001',
      );

      await expectLater(
        repository.fetchOverview(),
        throwsA(
          isA<ApiHttpException>().having(
            (error) => error.errorCode,
            'errorCode',
            'dependency_failed',
          ),
        ),
      );
    });

    test(
      'uses the device calendar day instead of a UTC date boundary',
      () async {
        final repository = ProfileOverviewApiRepository(
          transport: FixtureApiJsonTransportByPath({
            profileMeEndpoint: const {
              'user_id': 'user-local-day',
              'current_care_stage': 'postpartum',
              'actual_delivery_date': '2026-06-30',
            },
            profileInfantsEndpoint: const {
              'items': [
                {'id': 'baby-local-day', 'birth_date': '2026-06-30'},
              ],
            },
          }),
          babyId: 'baby-local-day',
          now: () => DateTime(2026, 7, 1, 0, 15),
        );

        final overview = await repository.fetchOverview();

        expect(overview.mom?.postpartumDay, 1);
        expect(overview.baby?.ageDays, 1);
      },
    );

    test(
      'does not infer a stage from dates when current stage is absent',
      () async {
        final repository = ProfileOverviewApiRepository(
          transport: FixtureApiJsonTransportByPath({
            profileMeEndpoint: const {
              'user_id': 'invalid-profile',
              'actual_delivery_date': '2026-07-01',
            },
            profileInfantsEndpoint: const {'items': []},
          }),
          babyId: 'infant-001',
        );

        final overview = await repository.fetchOverview();

        expect(overview.mom, isNull);
      },
    );

    test('starts profile and infant reads in parallel', () async {
      final transport = _DeferredProfileOverviewTransport();
      final repository = ProfileOverviewApiRepository(
        transport: transport,
        babyId: 'infant-001',
      );

      final overview = repository.fetchOverview();
      await Future<void>.delayed(Duration.zero);

      expect(transport.startedPaths, {
        profileMeEndpoint,
        profileInfantsEndpoint,
        profilePregnancyFactEndpoint,
      });
      transport.complete(profileMeEndpoint, const {'user_id': 'user-001'});
      transport.complete(profileInfantsEndpoint, const {'items': []});
      transport.complete(profilePregnancyFactEndpoint, const {'items': []});
      await overview;
    });

    test('selects the session infant instead of the first infant', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {'user_id': 'user-001'},
          profileInfantsEndpoint: const {
            'items': [
              {'id': 'infant-other', 'infant_name': 'Other baby'},
              {'id': 'infant-current', 'infant_name': 'Current baby'},
            ],
          },
        }),
        babyId: 'infant-current',
      );

      final overview = await repository.fetchOverview();

      expect(overview.baby?.id, 'infant-current');
      expect(overview.baby?.nickname, 'Current baby');
      expect(overview.infants.map((infant) => infant.id), [
        'infant-other',
        'infant-current',
      ]);
      expect(overview.infants.map((infant) => infant.nickname), [
        'Other baby',
        'Current baby',
      ]);
    });

    test(
      'does not expose another infant when the session infant is absent',
      () async {
        final repository = ProfileOverviewApiRepository(
          transport: FixtureApiJsonTransportByPath({
            profileMeEndpoint: const {'user_id': 'user-001'},
            profileInfantsEndpoint: const {
              'items': [
                {'id': 'infant-other', 'infant_name': 'Other baby'},
                {'id': 'infant-another', 'infant_name': 'Another baby'},
              ],
            },
          }),
          babyId: 'infant-current',
        );

        final overview = await repository.fetchOverview();

        expect(overview.baby, isNull);
      },
    );

    test('uses the only owned infant when the session id is stale', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {'user_id': 'user-001'},
          profileInfantsEndpoint: const {
            'items': [
              {'id': 'infant-only', 'infant_name': 'Only baby'},
            ],
          },
        }),
        babyId: 'stale-session-id',
      );

      final overview = await repository.fetchOverview();

      expect(overview.baby?.id, 'infant-only');
    });
  });
}

class _DeferredProfileOverviewTransport implements ApiJsonTransport {
  final startedPaths = <String>{};
  final _responses = <String, Completer<Map<String, Object?>>>{};

  void complete(String path, Map<String, Object?> response) {
    _responses[path]!.complete(response);
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) {
    startedPaths.add(path);
    return (_responses[path] ??= Completer<Map<String, Object?>>()).future;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    throw UnimplementedError();
  }
}
