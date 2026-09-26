import 'mom_inventory_transport.dart';

/// Isolated HTTP boundary for generic inbox and conversation notifications.
class NotificationInventoryTransport extends MomInventoryTransport {
  final notifications = <Map<String, Object?>>[];
  final preferencesData = <String, bool>{'agent_updates': true};
  final unavailableTargets = <String>{};
  bool pushAvailable = true;
  int pageSize = 3;

  void seedInbox(int count) {
    notifications
      ..clear()
      ..addAll([
        for (var i = 0; i < count; i++)
          {
            'id': 'notice-${i + 1}',
            'notification_type': 'agent_conversation',
            'title': 'Momcozy AI update ${i + 1}',
            'body': 'Open your conversation to see the latest update.',
            'status': 'unread',
            'source': 'agent',
            'payload': <String, Object?>{},
            'created_at': inventoryMomNow
                .subtract(Duration(hours: i))
                .toIso8601String(),
          },
      ]);
  }

  Future<void> readNotification(String path) async {
    getPaths.add(path);
    await readGates[path]?.future;
    check(failingReads.contains(path));
  }

  Future<void> writeNotification(String path, Map<String, Object?> body) async {
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite);
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (!path.startsWith('/v1/notifications')) {
      return super.getJson(path, query: query);
    }
    await readNotification(path);
    if (path.endsWith('/preferences')) return Map.of(preferencesData);
    final start = int.tryParse(query['cursor']?.toString() ?? '') ?? 0;
    final limit = (query['limit'] as int? ?? pageSize).clamp(1, pageSize);
    final items = notifications.skip(start).take(limit).toList();
    return {
      'items': items,
      'unread_count': notifications
          .where((n) => n['status'] == 'unread')
          .length,
      'next_cursor': start + items.length < notifications.length
          ? '${start + items.length}'
          : null,
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/notifications')) {
      return super.postJson(path, body: body, headers: headers);
    }
    await writeNotification(path, body);
    if (path.endsWith('/installations')) {
      return {
        'binding_id': 'inventory-binding',
        'token_registered': body['token'] != null,
        'push_available': pushAvailable,
      };
    }
    if (path.endsWith('/read-all')) {
      for (final item in notifications) {
        item['status'] = 'read';
        item['read_at'] = inventoryMomNow.toIso8601String();
      }
    }
    if (path.endsWith('/open')) {
      final item = notifications.singleWhere(
        (n) => n['id'] == path.split('/')[3],
      );
      item['status'] = 'read';
      return {
        'notification': Map.of(item),
        'resource_available': !unavailableTargets.contains(item['id']),
        'route': null,
      };
    }
    return {};
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/notifications/preferences/')) {
      return super.patchJson(path, body: body, headers: headers);
    }
    await writeNotification(path, body);
    preferencesData[path.split('/').last] = body['enabled'] as bool;
    return Map.of(preferencesData);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/notifications/')) {
      return super.deleteJson(path, headers: headers);
    }
    await writeNotification(path, const {});
    notifications.removeWhere((item) => item['id'] == path.split('/').last);
    return {};
  }
}
