import 'package:app/core/network/api_json_transport.dart';
import 'package:app/features/hospital_bag/domain/hospital_bag_cart.dart';

const hospitalBagCartUpdateEndpoint = '/v1/plans';

class HospitalBagCartApiRepository implements HospitalBagCartRepository {
  const HospitalBagCartApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<HospitalBagCartSyncResult> syncCart({
    required HospitalBagCartSnapshot cart,
  }) async {
    final items = cart.items
        .map(
          (item) => HospitalBagPackedItem(
            id: item.id,
            title: item.name,
            packed: true,
          ),
        )
        .toList(growable: false);
    final serializedItems = items
        .map((item) => item.toMap())
        .toList(growable: false);
    final response = await transport.postJson(
      hospitalBagCartUpdateEndpoint,
      headers: {'Idempotency-Key': _idempotencyKey(cart)},
      body: {
        'title': 'Hospital bag cart',
        'plan_type': 'hospital_bag_cart',
        'source': 'flutter',
        'summary': _summary(items),
        'payload': {'items': serializedItems, ...cart.toAgentContext()},
      },
    );
    final payload = _mapOrEmpty(response['payload']);
    final responseItems = payload['items'];
    return HospitalBagCartSyncResult(
      message: _string(response['summary']) ?? '购物车已同步',
      syncedCount: responseItems is List ? responseItems.length : items.length,
    );
  }
}

String _summary(List<HospitalBagPackedItem> items) {
  final packedCount = items.where((item) => item.packed).length;
  return '购物车已同步：$packedCount/${items.length} 已打包';
}

String _idempotencyKey(HospitalBagCartSnapshot cart) {
  final stableItems = [...cart.items]..sort((a, b) => a.id.compareTo(b.id));
  final encoded = stableItems
      .map(
        (item) =>
            '${_keyPart(item.id)}:${item.qty}:${item.price}:${_keyPart(item.currency)}',
      )
      .join('|');
  return 'hospital-bag-cart:$encoded';
}

String _keyPart(String value) {
  return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_');
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String? _string(Object? value) => value is String ? value : null;
