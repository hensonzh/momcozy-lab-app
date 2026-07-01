import 'package:momcozy_flutter_app/core/network/api_envelope.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/hospital_bag/domain/hospital_bag_cart.dart';

const hospitalBagCartUpdateEndpoint = '/api/hospital-bag/cart-update';

class HospitalBagCartApiRepository implements HospitalBagCartRepository {
  const HospitalBagCartApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<HospitalBagCartSyncResult> syncCart({
    required String userId,
    required List<HospitalBagPackedItem> items,
  }) async {
    final response = await transport.postJson(
      hospitalBagCartUpdateEndpoint,
      body: {
        'user_id': userId,
        'source': 'flutter',
        'hospital_bag_cart': {
          'items': items.map((item) => item.toMap()).toList(growable: false),
        },
      },
    );
    final data = _mapOrEmpty(unwrapApiEnvelope(response));
    return HospitalBagCartSyncResult(
      message: _string(data['message']) ?? '购物车已同步',
      syncedCount:
          _int(data['synced_count'] ?? data['syncedCount']) ?? items.length,
    );
  }
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : const {};
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;
