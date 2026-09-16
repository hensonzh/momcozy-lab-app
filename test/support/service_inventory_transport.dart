import 'dart:convert';
import 'dart:io';
import 'mom_inventory_transport.dart';

/// In-memory HTTP contract for exercising the real service routes/repositories.
/// No card information is sent to a provider and no external order is created.
class ServiceInventoryTransport extends MomInventoryTransport {
  ServiceInventoryTransport() {
    responsesByPath['/v1/care/catalog']!['available_regions'] = ['CA'];
    responsesByPath['/v1/care/catalog']!['providers'] = [provider];
  }
  final provider = <String, Object?>{
    'user_id': 'inventory-ibclc',
    'display_name': 'Test IBCLC',
    'timezone': 'America/Los_Angeles',
    'regions': ['CA'],
    'languages': ['English'],
    'bio': '本地测试专家资料，用于验证预约流程。',
    'sandbox': true,
  };
  Map<String, Object?>? order, episode, appointment, bookingEligibility;
  Map<String, Object?>? intake;
  final consents = <Map<String, Object?>>[];
  final requests = <Map<String, Object?>>[];
  final failingWrites = <String>{};
  bool allowPurchase = true, emptySlots = false;
  String? paymentStatusOverride;
  String packageId = 'feeding-confidence';
  int orderNumber = 0;
  final pastOrders = <Map<String, Object?>>[];
  Map<String, Object?> get purchase => {'order': order!, 'episode': episode};

  Map<String, Object?> newOrder([String status = 'pending']) => {
    'id': ++orderNumber == 1 ? 'service-order' : 'service-order-$orderNumber',
    'package_id': packageId,
    'status': status,
    'price_minor': 21900,
    'currency': 'USD',
    'duration_days': 7,
    'total_sessions': 2,
    'payment_mode': 'sandbox',
    'region': 'CA',
    'version': 1,
    'created_at': inventoryMomNow.toIso8601String(),
    'updated_at': inventoryMomNow.toIso8601String(),
  };
  Map<String, Object?> newEpisode() => {
    'id': 'service-episode',
    'order_id': order!['id'],
    'package_id': packageId,
    'assigned_ibclc_id': provider['user_id'],
    'status': 'active',
    'stage': 'preparation',
    'total_sessions': 2,
    'remaining_sessions': 2,
    'version': 1,
    'starts_at': inventoryMomNow.toIso8601String(),
    'ends_at': inventoryMomNow.add(const Duration(days: 7)).toIso8601String(),
  };
  void ownPlan() {
    order = newOrder('paid');
    episode = newEpisode();
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    await readGates[path]?.future;
    check(failingReads.contains(path));
    getPaths.add(path);
    if (path == '/v1/care/overview') {
      return {
        'orders': [...pastOrders, ?order],
        'episodes': [?episode],
      };
    }
    if (path == '/v1/care/orders/${order?['id']}') return purchase;
    if (path.endsWith('/booking')) {
      return {
        'episode': episode!,
        'providers': [provider],
        'appointments': [?appointment],
        'eligibility': bookingEligibility,
        'server_time': inventoryMomNow.toIso8601String(),
      };
    }
    if (path.endsWith('/availability')) {
      final day = DateTime.parse('${query['date']}T17:00:00Z');
      return {
        'provider_id': provider['user_id'],
        'date': query['date'],
        'timezone': provider['timezone'],
        'server_time': inventoryMomNow.toIso8601String(),
        'slots': emptySlots
            ? []
            : [
                {
                  'starts_at': day.toIso8601String(),
                  'ends_at': day
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                  'available': true,
                },
                {
                  'starts_at': day
                      .add(const Duration(hours: 1))
                      .toIso8601String(),
                  'ends_at': day
                      .add(const Duration(hours: 2))
                      .toIso8601String(),
                  'available': false,
                },
              ],
      };
    }
    if (path == '/v1/care/appointments/service-appointment') {
      return appointment!;
    }
    if (path.endsWith('/intake')) {
      final data = Map<String, Object?>.from(
        jsonDecode(
              File(
                'test/fixtures/product_baseline/intake_context.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      data['appointment'] = appointment!;
      data['intake'] = intake;
      data['consents'] = consents;
      return data;
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    requests.add({
      'path': path,
      'body': Map<String, Object?>.from(body),
      'headers': Map<String, String>.from(headers),
    });
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite || failingWrites.contains(path));
    if (path == '/v1/care/eligibility') {
      packageId = body['package_id'] as String;
      return {
        'id': 'service-eligibility',
        'package_id': packageId,
        'region': body['region'],
        'eligible': allowPurchase,
        'reason': allowPurchase ? '' : 'region_not_supported',
        'expires_at': '2035-01-01T00:00:00Z',
      };
    }
    if (path == '/v1/care/orders') {
      if (order?['status'] == 'cancelled') {
        pastOrders.add(order!);
        order = null;
      }
      order ??= newOrder();
      return purchase;
    }
    if (path.endsWith('/sandbox-payment')) {
      order!['version'] = (order!['version'] as int) + 1;
      order!['status'] =
          paymentStatusOverride ??
          switch (body['outcome']) {
            'succeeded' => 'paid',
            'declined' => 'failed',
            'requires_action' => 'requires_action',
            'cancelled' => 'cancelled',
            _ => 'reconciling',
          };
      if (order!['status'] == 'paid') episode ??= newEpisode();
      return purchase;
    }
    if (path.endsWith('/booking-eligibility')) {
      return bookingEligibility = {
        'id': 'booking-eligibility',
        'episode_id': 'service-episode',
        'region': body['region'],
        'service_suitable': body['service_suitable'],
        'emergency_status': body['emergency_status'],
        'eligible': true,
        'reason': '',
        'expires_at': inventoryMomNow
            .add(const Duration(hours: 1))
            .toIso8601String(),
      };
    }
    if (path.endsWith('/holds')) {
      final start = DateTime.parse(body['starts_at'] as String);
      return appointment = {
        'id': 'service-appointment',
        'episode_id': 'service-episode',
        'provider_id': body['provider_id'],
        'provider_name': provider['display_name'],
        'starts_at': start.toIso8601String(),
        'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
        'timezone': provider['timezone'],
        'region': 'CA',
        'status': 'held',
        'hold_expires_at': inventoryMomNow
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'version': 1,
        'intake_version': 0,
      };
    }
    if (path.endsWith('/confirm') || path.endsWith('/cancel')) {
      final confirmed = path.endsWith('/confirm');
      appointment!['status'] = confirmed ? 'confirmed' : 'cancelled';
      appointment!['version'] = (appointment!['version'] as int) + 1;
      appointment![confirmed ? 'confirmed_at' : 'cancelled_at'] =
          inventoryMomNow.toIso8601String();
      return appointment!;
    }
    return super.postJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.endsWith('/intake')) {
      return super.putJson(path, body: body, headers: headers);
    }
    requests.add({
      'path': path,
      'body': Map<String, Object?>.from(body),
      'headers': headers,
    });
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite || failingWrites.contains(path));
    intake = {
      'id': 'service-intake',
      'appointment_id': appointment!['id'],
      'episode_id': episode!['id'],
      'version': (intake?['version'] as int? ?? 0) + 1,
      'submitted_at': inventoryMomNow.toIso8601String(),
      'symptoms': body['symptoms'],
      'feeding_goal': body['feeding_goal'],
      'support_needed': body['support_needed'],
      'profile': body['profile'],
    };
    appointment!['intake_version'] = intake!['version'];
    consents
      ..clear()
      ..add({
        'id': 'service-consent',
        'episode_id': episode!['id'],
        'scope': 'ibclc_case',
        'active': true,
        'version': intake!['version'],
        'policy_version': body['consent_policy_version'],
        'recorded_at': inventoryMomNow.toIso8601String(),
      });
    return intake!;
  }
}
