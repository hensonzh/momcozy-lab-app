import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_api_repository.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  group('HospitalBagCartApiRepository', () {
    test('posts production plan projection and maps sync response', () async {
      final transport = FixtureApiJsonTransport(const {
        'id': 'plan-001',
        'owner_user_id': 'user-001',
        'plan_type': 'hospital_bag_cart',
        'title': 'Hospital bag cart',
        'summary': '购物车已同步：1/3 已打包',
        'status': 'active',
        'source': 'flutter',
        'payload': {
          'items': <Object?>[
            {'id': 'pump', 'title': '吸奶器和配件', 'packed': true},
            {'id': 'pads', 'title': '产后护理用品', 'packed': false},
            {'id': 'baby', 'title': '宝宝衣物', 'packed': false},
          ],
        },
      });
      final repository = HospitalBagCartApiRepository(transport: transport);

      final result = await repository.syncCart(
        cart: HospitalBagCartSnapshot.fromGroups(const [
          HospitalBagCartGroup(
            title: '我的清单',
            tone: HospitalBagCartTone.sky,
            items: [
              HospitalBagCartItem(
                id: 'pump',
                name: '吸奶器和配件',
                desc: '个性化型号',
                qty: 1,
                price: 999,
                skuId: 'pump-custom',
              ),
              HospitalBagCartItem(
                id: 'pads',
                name: '产后护理用品',
                desc: '',
                qty: 2,
                price: 39.9,
              ),
            ],
          ),
        ]),
      );
      final payload = transport.lastBody!['payload']! as Map;
      final items = payload['items']! as List;
      final groups = payload['groups']! as List;

      expect(transport.lastPath, hospitalBagCartUpdateEndpoint);
      expect(transport.lastBody, isNot(containsPair('user_id', anything)));
      expect(transport.lastHeaders?['Idempotency-Key'], isNotEmpty);
      expect(transport.lastBody, containsPair('title', 'Hospital bag cart'));
      expect(
        transport.lastBody,
        containsPair('plan_type', 'hospital_bag_cart'),
      );
      expect(transport.lastBody, containsPair('source', 'flutter'));
      expect(items, hasLength(2));
      expect(items.first, containsPair('packed', true));
      expect(
        ((groups.single as Map)['items'] as List).first,
        containsPair('sku_id', 'pump-custom'),
      );
      expect((payload['totals'] as Map)['itemCount'], 3);
      expect(result.message, '购物车已同步：1/3 已打包');
      expect(result.syncedCount, 3);
    });

    test('keeps HTTP failures typed', () async {
      await expectLater(
        HospitalBagCartApiRepository(
          transport: FixtureApiJsonTransport(const {
            'http_status': 502,
            'status_text': 'Bad Gateway',
            'body': {'message': 'upstream unavailable'},
          }),
        ).syncCart(cart: HospitalBagCartSnapshot.fromGroups(const [])),
        throwsA(isA<ApiHttpException>()),
      );
    });
  });
}
