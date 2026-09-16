import 'notification_inventory_transport.dart';

const inventoryHistoryThread = '22222222-2222-4222-8222-222222222222';

/// Isolate notification HTTP only; keep the default Agent page builder intact.
class AgentHistoryInventoryTransport extends NotificationInventoryTransport {
  AgentHistoryInventoryTransport() {
    seedInbox(1);
    notifications.single['title'] = 'Conversation ready';
    notifications.single['body'] =
        'Your saved conversation is ready to review.';
  }
  String targetRoute = '/?conversationId=$inventoryHistoryThread';

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final result = await super.postJson(path, body: body, headers: headers);
    if (path == '/v1/notifications/notice-1/open') {
      return {...result, 'route': targetRoute};
    }
    return result;
  }
}
