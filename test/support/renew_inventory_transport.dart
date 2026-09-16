import 'mom_inventory_transport.dart';
import 'service_inventory_transport.dart';

/// Completed original service and independently purchased next service. Only
/// HTTP contracts are isolated; the real timeline and renewal routes are used.
class RenewInventoryTransport extends ServiceInventoryTransport {
  RenewInventoryTransport() {
    ownPlan();
    completedOrder = {
      ...order!,
      'id': 'completed-order',
      'created_at': inventoryMomNow
          .subtract(const Duration(days: 14))
          .toIso8601String(),
      'updated_at': inventoryMomNow
          .subtract(const Duration(days: 7))
          .toIso8601String(),
    };
    completedEpisode = {
      ...episode!,
      'id': 'completed-episode',
      'order_id': 'completed-order',
      'status': 'completed',
      'stage': 'conclusion',
      'remaining_sessions': 0,
      'starts_at': inventoryMomNow
          .subtract(const Duration(days: 14))
          .toIso8601String(),
      'ends_at': inventoryMomNow
          .subtract(const Duration(days: 7))
          .toIso8601String(),
    };
    order = null;
    episode = null;
    orderNumber = 0;
  }
  late final Map<String, Object?> completedOrder, completedEpisode;
  void pendingOrder() => order = newOrder();

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/care/episodes/completed-episode/booking') {
      await readGates[path]?.future;
      check(failingReads.contains(path));
      getPaths.add(path);
      return {
        'episode': completedEpisode,
        'providers': [provider],
        'appointments': [],
        'server_time': inventoryMomNow.toIso8601String(),
      };
    }
    final result = await super.getJson(path, query: query);
    if (path == '/v1/care/overview') {
      return {
        ...result,
        'orders': [completedOrder, ...result['orders'] as List],
        'episodes': [completedEpisode, ...result['episodes'] as List],
      };
    }
    return result;
  }
}
