import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/profile_overview/data/profile_overview_api_repository.dart';
import 'package:momcozy_flutter_app/features/profile_overview/domain/delivery_type.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('ProfileOverviewApiRepository', () {
    test('maps the postpartum profile and selected infant', () async {
      final transport = FixtureApiJsonTransportByPath({
        profileMeEndpoint: const {
          'display_name': 'Mom',
          'actual_delivery_date': '2026-05-20',
          'delivery_type': 'vaginal',
          'selected_avatar_file_id': 'avatar-001',
          // Legacy fields may still arrive, but are intentionally ignored.
          'current_care_stage': 'pregnancy',
          'estimated_due_date': '2026-10-31',
        },
        profileInfantsEndpoint: const {
          'items': [
            {
              'id': 'infant-other',
              'infant_name': 'Other baby',
              'birth_date': '2026-05-18',
            },
            {
              'id': 'infant-001',
              'infant_name': 'Baby',
              'birth_date': '2026-05-20',
              'sex': 'female',
            },
          ],
        },
      });
      final repository = ProfileOverviewApiRepository(
        transport: transport,
        babyId: 'infant-001',
        now: () => DateTime(2026, 7, 1),
      );

      final overview = await repository.fetchOverview();

      expect(transport.getPaths, [profileMeEndpoint, profileInfantsEndpoint]);
      expect(overview.mom?.displayName, 'Mom');
      expect(overview.mom?.postpartumDay, 42);
      expect(overview.mom?.actualDeliveryDate, DateTime(2026, 5, 20));
      expect(overview.mom?.deliveryType, DeliveryType.vaginal);
      expect(overview.mom?.avatarFileId, 'avatar-001');
      expect(overview.baby?.id, 'infant-001');
      expect(overview.baby?.nickname, 'Baby');
      expect(overview.baby?.ageDays, 42);
      expect(overview.baby?.sex, 'female');
      expect(overview.infants, hasLength(2));
    });

    test('uses infant birth history when delivery date is missing', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {'preferred_name': 'Avery'},
          profileInfantsEndpoint: const {
            'items': [
              {
                'id': 'infant-001',
                'name': 'Mia',
                'birth_date': '2026-06-30',
                'sex_at_birth': 'female',
              },
            ],
          },
        }),
        babyId: 'stale-session-id',
        now: () => DateTime(2026, 7, 1, 0, 15),
      );

      final overview = await repository.fetchOverview();

      expect(overview.mom?.actualDeliveryDate, DateTime(2026, 6, 30));
      expect(overview.mom?.postpartumDay, 1);
      expect(overview.baby?.id, 'infant-001');
      expect(overview.baby?.nickname, 'Mia');
      expect(overview.baby?.ageDays, 1);
    });

    test('returns an empty overview for empty profile data', () async {
      final repository = ProfileOverviewApiRepository(
        transport: FixtureApiJsonTransportByPath({
          profileMeEndpoint: const {'user_id': 'user-001'},
          profileInfantsEndpoint: const {'items': []},
        }),
        babyId: 'infant-001',
      );

      final overview = await repository.fetchOverview();

      expect(overview.isEmpty, isTrue);
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
      });
      transport.complete(profileMeEndpoint, const {'user_id': 'user-001'});
      transport.complete(profileInfantsEndpoint, const {'items': []});
      await overview;
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
