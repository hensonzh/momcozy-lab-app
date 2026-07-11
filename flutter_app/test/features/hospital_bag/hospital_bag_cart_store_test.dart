import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

void main() {
  group('Hospital bag cart domain', () {
    test(
      'parses the complete artifact shape and calculates legacy Web totals',
      () {
        final snapshot = HospitalBagCartSnapshot.tryFromCartUpdate({
          'groups': [
            {
              'title': '母乳喂养',
              'tone': 'sky',
              'items': [
                {
                  'id': 'pump-air-1',
                  'name': 'Momcozy Air 1',
                  'desc': '轻薄款',
                  'quantity': 2,
                  'price': 199.99,
                  'currency': 'USD',
                  'priceLabel': r'$199.99',
                  'salePriceLabel': r'$179.99',
                  'officialPriceUsd': 199.99,
                  'salePriceUsd': 179.99,
                  'exchangeRateUsdCny': 7.2,
                  'productUrl': 'https://example.com/air-1',
                  'imageUrl': 'https://example.com/air-1.png',
                  'imageAlt': 'Air 1 商品图',
                  'skuId': 'pump-air-1',
                  'model': 'Air 1',
                  'keywords': ['吸奶器', '轻薄'],
                },
              ],
            },
          ],
          'totals': {'item_count': 999, 'total': 1},
        });

        expect(snapshot, isNotNull);
        final item = snapshot!.groups.single.items.single;
        expect(item.qty, 2);
        expect(item.currency, 'USD');
        expect(item.salePriceLabel, r'$179.99');
        expect(item.officialPriceUsd, 199.99);
        expect(item.imageUrl, 'https://example.com/air-1.png');
        expect(item.keywords, ['吸奶器', '轻薄']);
        expect(item.unitPriceCny, 1359.93);
        expect(snapshot.totals.itemCount, 2);
        expect(snapshot.totals.subtotal, 2719.86);
        expect(snapshot.totals.discount, 217.59);
        expect(snapshot.totals.total, 2502.27);
        expect(snapshot.toAgentContext()['groups'], hasLength(1));
      },
    );

    test('rejects malformed updates instead of replacing a valid cart', () {
      expect(HospitalBagCartSnapshot.tryFromCartUpdate(null), isNull);
      expect(
        HospitalBagCartSnapshot.tryFromCartUpdate({'groups': 'not-a-list'}),
        isNull,
      );
      expect(
        HospitalBagCartSnapshot.tryFromCartUpdate({
          'groups': [
            {'title': '坏数据', 'items': 'not-a-list'},
          ],
        }),
        isNull,
      );
    });

    test('bounds artifact cart payloads before rendering or forwarding', () {
      final snapshot = HospitalBagCartSnapshot.tryFromCartUpdate({
        'groups': [
          {
            'title': '超长清单',
            'tone': 'rose',
            'items': List.generate(
              140,
              (index) => {
                'id': 'item-$index',
                'name': '用品 $index',
                'qty': 1,
                'price': 1,
              },
            ),
          },
        ],
      });

      expect(snapshot, isNotNull);
      expect(snapshot!.groups.single.items, hasLength(120));
      expect(snapshot.totals.itemCount, 120);
    });
  });

  group('HospitalBagCartStore', () {
    test('owns artifact updates, mutations, reset, and Agent context', () {
      final store = HospitalBagCartStore();
      final seed = HospitalBagCartArtifactSeed.tryFromCartUpdate(
        artifactId: 'artifact-personalized',
        cartUpdate: {
          'groups': [
            {
              'title': '我的清单',
              'tone': 'mint',
              'items': [
                {
                  'id': 'custom-one',
                  'name': '个性化用品 A',
                  'desc': '只属于当前清单',
                  'qty': 1,
                  'price': 88.0,
                },
                {
                  'id': 'custom-two',
                  'name': '个性化用品 B',
                  'desc': '继续保留',
                  'qty': 2,
                  'price': 66.0,
                },
              ],
            },
          ],
        },
      );

      expect(seed, isNotNull);
      expect(store.agentClientContext, isNull);

      final cartId = store.ingestArtifact(seed!);
      expect(cartId, 'artifact:artifact-personalized');
      expect(store.activeCartId, cartId);
      expect(store.snapshot(cartId).groups.single.items, hasLength(2));
      expect(
        store.agentClientContext!['hospital_bag_cart'],
        store.snapshot(cartId).toAgentContext(),
      );

      expect(store.removeItem(cartId: cartId, itemId: 'custom-one'), isTrue);
      expect(
        store.snapshot(cartId).groups.single.items.single.id,
        'custom-two',
      );
      expect(store.canReset(cartId), isTrue);

      store.reset(cartId);
      expect(store.snapshot(cartId).totals.itemCount, 18);
      expect(store.canReset(cartId), isFalse);
      expect(
        store.snapshot(HospitalBagCartStore.defaultCartId).totals.itemCount,
        18,
      );

      store.clearForNewSession();
      expect(store.activeCartId, isNull);
      expect(store.agentClientContext, isNull);
      expect(store.snapshot(cartId).totals.itemCount, 18);
    });

    test('falls back to defaults for a cart id from another runtime', () {
      final store = HospitalBagCartStore();

      final cartId = store.activate('artifact:another-user');

      expect(cartId, HospitalBagCartStore.defaultCartId);
      expect(store.activeCartId, HospitalBagCartStore.defaultCartId);
      expect(store.snapshot(cartId).totals.itemCount, 18);
    });
  });
}
