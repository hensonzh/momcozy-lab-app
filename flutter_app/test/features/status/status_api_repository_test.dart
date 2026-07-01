import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/status/data/status_api_repository.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/fixture_reader.dart';

void main() {
  group('StatusApiRepository', () {
    test('maps mom/baby success response and request contract', () async {
      final transport = _transport('success');
      final repository = StatusApiRepository(transport: transport);

      final overview = await repository.fetchOverview(
        userId: 'demo-user-fixture',
      );

      expect(transport.lastPath, statusOverviewEndpoint);
      expect(transport.lastQuery, containsPair('user_id', 'demo-user-fixture'));
      expect(overview.mom?.stage, 'postpartum');
      expect(overview.mom?.postpartumDay, 42);
      expect(overview.baby?.nickname, 'Baby');
      expect(overview.baby?.ageDays, 42);
    });

    test('accepts legacy aliases and partial empty data', () async {
      final legacy = await StatusApiRepository(
        transport: _transport('legacy_alias'),
      ).fetchOverview(userId: 'demo-user-fixture');
      final empty = await StatusApiRepository(
        transport: _transport('empty'),
      ).fetchOverview(userId: 'demo-user-fixture');
      final partial = await StatusApiRepository(
        transport: _transport('partial'),
      ).fetchOverview(userId: 'demo-user-fixture');

      expect(legacy.mom?.stage, 'postpartum');
      expect(legacy.baby?.nickname, 'Baby');
      expect(empty.isEmpty, isTrue);
      expect(partial.mom?.stage, 'postpartum');
      expect(partial.baby, isNull);
    });

    test('keeps business and HTTP failures distinct', () async {
      await expectLater(
        StatusApiRepository(
          transport: _transport('business_error'),
        ).fetchOverview(userId: 'demo-user-fixture'),
        throwsA(isA<ApiBusinessException>()),
      );
      await expectLater(
        StatusApiRepository(
          transport: _transport('http_error'),
        ).fetchOverview(userId: 'demo-user-fixture'),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}

FixtureApiJsonTransport _transport(String variant) {
  final fixture = readFixtureMap('api/mom_baby/$variant.json');
  return FixtureApiJsonTransport(
    Map<String, Object?>.from(fixture['response']! as Map),
  );
}
