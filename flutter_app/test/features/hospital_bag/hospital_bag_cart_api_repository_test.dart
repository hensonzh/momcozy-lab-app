import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('HospitalBagCartApiRepository', () {
    test('posts packed item state and maps sync response', () async {
      final transport = FixtureApiJsonTransport({
        'status': 200,
        'data': {'message': '购物车已同步', 'synced_count': 3},
      });
      final repository = HospitalBagCartApiRepository(transport: transport);

      final result = await repository.syncCart(
        userId: 'demo-user-fixture',
        items: const [
          HospitalBagPackedItem(id: 'pump', title: '吸奶器和配件', packed: true),
          HospitalBagPackedItem(id: 'pads', title: '产后护理用品', packed: false),
          HospitalBagPackedItem(id: 'baby', title: '宝宝衣物', packed: false),
        ],
      );
      final cart = transport.lastBody!['hospital_bag_cart']! as Map;
      final items = cart['items']! as List;

      expect(transport.lastPath, hospitalBagCartUpdateEndpoint);
      expect(transport.lastBody, containsPair('user_id', 'demo-user-fixture'));
      expect(transport.lastBody, containsPair('source', 'flutter'));
      expect(items, hasLength(3));
      expect(items.first, containsPair('packed', true));
      expect(result.message, '购物车已同步');
      expect(result.syncedCount, 3);
    });

    test('keeps business and HTTP failures distinct', () async {
      await expectLater(
        HospitalBagCartApiRepository(
          transport: FixtureApiJsonTransport({
            'status': 40001,
            'message': 'cart update failed',
            'data': {'error': -1},
          }),
        ).syncCart(userId: 'demo-user-fixture', items: const []),
        throwsA(isA<ApiBusinessException>()),
      );

      await expectLater(
        HospitalBagCartApiRepository(
          transport: FixtureApiJsonTransport({
            'http_status': 502,
            'status_text': 'Bad Gateway',
            'body': {'message': 'upstream unavailable'},
          }),
        ).syncCart(userId: 'demo-user-fixture', items: const []),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}
