import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/data/hospital_bag_cart_store.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

void main() {
  group('Hospital bag cart domain', () {
    test(
      'parses the complete artifact shape and calculates product totals',
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

    test('rejects non-finite numbers and bounds text-heavy payloads', () {
      final finite = HospitalBagCartSnapshot.tryFromCartUpdate({
        'groups': [
          {
            'title': '安全解析',
            'items': [
              {
                'id': 'bounded',
                'name': '用品',
                'qty': 'Infinity',
                'price': 'NaN',
                'desc': 'a' * 700,
                'keywords': List.generate(30, (index) => 'k$index'),
              },
            ],
          },
        ],
      });

      expect(finite, isNotNull);
      final item = finite!.items.single;
      expect(item.qty, 1);
      expect(item.price, 0);
      expect(item.desc, hasLength(512));
      expect(item.keywords, hasLength(16));

      final oversized = HospitalBagCartSnapshot.tryFromCartUpdate({
        'groups': [
          {
            'title': '超大清单',
            'items': List.generate(
              120,
              (index) => {
                'id': 'item-$index',
                'name': 'n' * 700,
                'desc': 'd' * 700,
                'product_url': 'u' * 700,
                'image_url': 'i' * 700,
                'qty': 1,
                'price': 1,
              },
            ),
          },
        ],
      });
      expect(oversized, isNull);
    });
  });

  group('HospitalBagCartStore', () {
    test(
      'owns artifact updates, mutations, reset, and Agent context',
      () async {
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

        await store.clearForNewSession();
        expect(store.activeCartId, isNull);
        expect(store.agentClientContext, isNull);
        expect(store.snapshot(cartId).totals.itemCount, 18);
      },
    );

    test('falls back to defaults for a cart id from another runtime', () {
      final store = HospitalBagCartStore();

      final cartId = store.activate('artifact:another-user');

      expect(cartId, HospitalBagCartStore.defaultCartId);
      expect(store.activeCartId, HospitalBagCartStore.defaultCartId);
      expect(store.snapshot(cartId).totals.itemCount, 18);
    });

    test('restores an Agent-updated cart after a process restart', () async {
      final persistence = _MemoryHospitalBagCartPersistence();
      final first = HospitalBagCartStore(persistence: persistence);
      final seed = HospitalBagCartArtifactSeed.tryFromCartUpdate(
        artifactId: 'action:cart-update',
        cartUpdate: {
          'groups': [
            {
              'title': '更新后的清单',
              'items': [
                {
                  'id': 'persisted-item',
                  'name': '跨重启保留的用品',
                  'qty': 1,
                  'price': 32,
                },
              ],
            },
          ],
        },
      )!;

      final cartId = first.ingestArtifact(seed);
      await first.flushPendingPersistence();

      final restarted = HospitalBagCartStore(persistence: persistence);
      await restarted.restore();

      expect(restarted.activeCartId, cartId);
      expect(
        restarted.snapshot(cartId).groups.single.items.single.id,
        'persisted-item',
      );
      expect(restarted.agentClientContext, isNotNull);
    });

    test('secure persistence keys are account isolated', () {
      const first = FlutterSecureHospitalBagCartPersistence(userId: 'user/a');
      const second = FlutterSecureHospitalBagCartPersistence(userId: 'user/b');

      expect(first.storageKey, contains('user.user%2Fa.cart'));
      expect(second.storageKey, contains('user.user%2Fb.cart'));
      expect(first.storageKey, isNot(second.storageKey));
    });

    test(
      'retries a transient restore failure before persisting changes',
      () async {
        final persistedSeed = _cartSeed('persisted-before-retry');
        final persistence = _MemoryHospitalBagCartPersistence(
          state: HospitalBagCartPersistedState(
            snapshots: {
              'artifact:persisted-before-retry': persistedSeed.snapshot,
            },
            customizedCartIds: const {'artifact:persisted-before-retry'},
            activeCartId: 'artifact:persisted-before-retry',
          ),
          readFailures: 1,
        );
        final store = HospitalBagCartStore(persistence: persistence);

        await store.restore();
        store.ingestArtifact(_cartSeed('new-after-retry'));
        await store.flushPendingPersistence();

        expect(persistence.readCount, 2);
        expect(
          persistence.state!.snapshots.keys,
          containsAll({
            'artifact:persisted-before-retry',
            'artifact:new-after-retry',
          }),
        );
      },
    );

    test(
      'always persists the latest active cart inside the bounded set',
      () async {
        final persistence = _MemoryHospitalBagCartPersistence();
        final store = HospitalBagCartStore(persistence: persistence);
        for (var index = 0; index < 25; index += 1) {
          store.ingestArtifact(_cartSeed('cart-$index'));
        }
        await store.flushPendingPersistence();

        final restarted = HospitalBagCartStore(persistence: persistence);
        await restarted.restore();

        expect(restarted.activeCartId, 'artifact:cart-24');
        expect(
          restarted.snapshot('artifact:cart-24').items.single.id,
          'cart-24',
        );
      },
    );

    test(
      'new-session clear completes only after the tombstone is durable',
      () async {
        final persistence = _MemoryHospitalBagCartPersistence();
        final store = HospitalBagCartStore(persistence: persistence);
        store.ingestArtifact(_cartSeed('before-clear'));
        await store.flushPendingPersistence();
        final blocker = Completer<void>();
        persistence.writeBarrier = blocker.future;
        var completed = false;

        final clear = store.clearForNewSession().then((_) => completed = true);
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);

        blocker.complete();
        await clear;
        expect(persistence.state!.activeCartId, isNull);
        expect(persistence.state!.snapshots, isEmpty);
      },
    );

    test(
      'failed durable clear restores the active cart and reports failure',
      () async {
        final persistence = _MemoryHospitalBagCartPersistence();
        final store = HospitalBagCartStore(persistence: persistence);
        store.ingestArtifact(_cartSeed('before-failed-clear'));
        await store.flushPendingPersistence();
        persistence.writeFailures = 1;

        await expectLater(store.clearForNewSession(), throwsStateError);

        expect(store.activeCartId, 'artifact:before-failed-clear');
        expect(store.agentClientContext, isNotNull);
        expect(persistence.state!.activeCartId, 'artifact:before-failed-clear');
      },
    );
  });
}

class _MemoryHospitalBagCartPersistence implements HospitalBagCartPersistence {
  _MemoryHospitalBagCartPersistence({this.state, this.readFailures = 0});

  HospitalBagCartPersistedState? state;
  int readFailures;
  int readCount = 0;
  int writeFailures = 0;
  Future<void>? writeBarrier;

  @override
  Future<HospitalBagCartPersistedState?> read() async {
    readCount += 1;
    if (readFailures > 0) {
      readFailures -= 1;
      throw StateError('transient secure storage failure');
    }
    return state;
  }

  @override
  Future<void> write(HospitalBagCartPersistedState state) async {
    await writeBarrier;
    if (writeFailures > 0) {
      writeFailures -= 1;
      throw StateError('secure storage write failed');
    }
    this.state = state;
  }
}

HospitalBagCartArtifactSeed _cartSeed(String id) {
  return HospitalBagCartArtifactSeed.tryFromCartUpdate(
    artifactId: id,
    cartUpdate: {
      'groups': [
        {
          'title': '测试清单',
          'items': [
            {'id': id, 'name': '用品 $id', 'qty': 1, 'price': 10},
          ],
        },
      ],
    },
  )!;
}
