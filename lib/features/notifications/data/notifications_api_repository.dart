import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';

const notificationsEndpoint = '/v1/notifications';

class NotificationsApiRepository implements NotificationsRepository {
  const NotificationsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<List<MomCozyNotification>> fetchNotifications({
    String? status,
    int limit = 100,
  }) async {
    final normalizedStatus = status?.trim();
    final response = await transport.getJson(
      notificationsEndpoint,
      query: {
        if (normalizedStatus?.isNotEmpty == true) 'status': normalizedStatus,
        'limit': limit,
      },
    );
    final items = response['items'];
    if (items is! List) return const <MomCozyNotification>[];
    return items
        .whereType<Map>()
        .map((item) => _notification(Map<String, Object?>.from(item)))
        .whereType<MomCozyNotification>()
        .toList(growable: false);
  }

  @override
  Future<MomCozyNotification> setReadState({
    required String notificationId,
    required bool read,
  }) async {
    final response = await _mutationTransport.patchJson(
      '$notificationsEndpoint/${Uri.encodeComponent(notificationId.trim())}/read',
      body: {'read': read},
    );
    final notification = _notification(response);
    if (notification == null) {
      throw const FormatException('Notification response is incomplete.');
    }
    return notification;
  }

  @override
  Future<void> archive({required String notificationId}) async {
    await _mutationTransport.deleteJson(
      '$notificationsEndpoint/${Uri.encodeComponent(notificationId.trim())}',
    );
  }

  ApiJsonMutationTransport get _mutationTransport {
    final candidate = transport;
    if (candidate is ApiJsonMutationTransport) {
      return candidate as ApiJsonMutationTransport;
    }
    throw StateError('Notification mutations require a mutation transport.');
  }
}

MomCozyNotification? _notification(Map<String, Object?> value) {
  final id = _text(value['id']);
  if (id.isEmpty) return null;
  final payload = value['payload'];
  return MomCozyNotification(
    id: id,
    type: _text(value['notification_type']),
    title: _text(value['title']),
    body: _text(value['body']),
    status: _text(value['status']),
    source: _text(value['source']),
    payload: payload is Map
        ? Map<String, Object?>.unmodifiable(Map<String, Object?>.from(payload))
        : const <String, Object?>{},
    createdAt: _dateTime(value['created_at']),
    deliveredAt: _dateTime(value['delivered_at']),
    readAt: _dateTime(value['read_at']),
  );
}

String _text(Object? value) => value is String ? value.trim() : '';

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}
