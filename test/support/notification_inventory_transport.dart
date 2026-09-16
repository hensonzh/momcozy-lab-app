import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'consultation_inventory_transport.dart';
import 'mom_inventory_transport.dart';

const inventoryNotificationAppointment = '11111111-1111-4111-8111-111111111111';
const inventoryReminderPath =
    '/v1/notifications/appointments/$inventoryNotificationAppointment/reminder';

/// HTTP boundary for production notification repository/controller/router.
class NotificationInventoryTransport extends ConsultationInventoryTransport {
  NotificationInventoryTransport() {
    appointment!['id'] = inventoryNotificationAppointment;
    appointment!['starts_at'] = inventoryMomNow
        .add(const Duration(minutes: 45))
        .toIso8601String();
    appointment!['ends_at'] = inventoryMomNow
        .add(const Duration(minutes: 105))
        .toIso8601String();
    intake!['appointment_id'] = inventoryNotificationAppointment;
  }
  final preferencesData = <String, bool>{
    'appointments': true,
    'consultations': true,
    'expert_feedback': true,
    'service_updates': true,
  };
  Map<String, Object?> reminderData = {'enabled': false, 'status': 'disabled'};
  final notifications = <Map<String, Object?>>[];
  final unavailableTargets = <String>{};
  bool pushAvailable = true;
  int pageSize = 3;
  String? reminderFailureCode;

  void seedInbox(int count) {
    notifications.clear();
    for (var i = 0; i < count; i++) {
      notifications.add({
        'id': 'notice-${i + 1}',
        'notification_type': i.isEven
            ? 'appointment_created'
            : 'expert_feedback',
        'title': 'Service update ${i + 1}',
        'body':
            'Your care service has an update. Open to review the appointment.',
        'status': 'unread',
        'source': 'care',
        'payload': <String, Object?>{},
        'created_at': inventoryMomNow
            .subtract(Duration(hours: i * 12))
            .toIso8601String(),
        'read_at': null,
      });
    }
  }

  Future<void> readNotification(String path) async {
    getPaths.add(path);
    await readGates[path]?.future;
    check(failingReads.contains(path));
  }

  Future<void> writeNotification(String path, Map<String, Object?> body) async {
    mutationPaths.add(path);
    requests.add({'path': path, 'body': Map<String, Object?>.from(body)});
    await writeGate?.future;
    check(failWrite || failingWrites.contains(path));
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path == '/v1/care/appointments/$inventoryNotificationAppointment') {
      await readNotification(path);
      return appointment!;
    }
    if (!path.startsWith('/v1/notifications')) {
      return super.getJson(path, query: query);
    }
    await readNotification(path);
    if (path.endsWith('/preferences')) {
      return Map<String, Object?>.from(preferencesData);
    }
    if (path.endsWith('/reminder')) {
      return Map<String, Object?>.from(reminderData);
    }
    final start = int.tryParse(query['cursor']?.toString() ?? '') ?? 0;
    final limit = (query['limit'] as int? ?? pageSize).clamp(1, pageSize);
    final items = notifications.skip(start).take(limit).toList();
    return {
      'items': items.map((e) => Map<String, Object?>.from(e)).toList(),
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
      for (final n in notifications) {
        n['status'] = 'read';
        n['read_at'] = inventoryMomNow.toIso8601String();
      }
    }
    if (path.endsWith('/open')) {
      final id = path.split('/')[3];
      final n = notifications.singleWhere((e) => e['id'] == id);
      n['status'] = 'read';
      n['read_at'] = inventoryMomNow.toIso8601String();
      return {
        'notification': Map<String, Object?>.from(n),
        'resource_available': !unavailableTargets.contains(id),
        'route': '/services/appointments/$inventoryNotificationAppointment',
      };
    }
    return {};
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path != inventoryReminderPath) {
      return super.putJson(path, body: body, headers: headers);
    }
    await writeNotification(path, body);
    if (reminderFailureCode case final code?) {
      throw ApiHttpException(
        statusCode: 409,
        statusText: 'Conflict',
        body: {
          'error': {'code': code, 'message': 'Isolated reminder rejection'},
        },
      );
    }
    reminderData = {
      'enabled': body['enabled'],
      'status': body['enabled'] == true ? 'scheduled' : 'disabled',
    };
    return reminderData;
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
    return Map<String, Object?>.from(preferencesData);
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
    notifications.removeWhere((n) => n['id'] == path.split('/').last);
    return {};
  }
}
