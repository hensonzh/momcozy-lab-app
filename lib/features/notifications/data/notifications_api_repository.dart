import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/notifications/domain/momcozy_notification.dart';

import '../domain/notification_delivery_repository.dart';
import '../domain/notification_permission.dart';

const notificationsEndpoint = '/v1/notifications';

class NotificationsApiRepository
    implements NotificationsRepository, NotificationDeliveryRepository {
  const NotificationsApiRepository({required this.transport});

  final ApiJsonTransport transport;

  @override
  Future<NotificationPageData> fetchPage({
    String? cursor,
    int limit = 30,
  }) async {
    final response = await transport.getJson(
      notificationsEndpoint,
      query: {'limit': limit, 'cursor': ?cursor},
    );
    final items = response['items'];
    final count = response['unread_count'];
    if (items is! List || count is! int || count < 0) {
      throw const FormatException('Incomplete notification page.');
    }
    return NotificationPageData(
      items: items
          .whereType<Map>()
          .map((item) => _notification(Map<String, Object?>.from(item)))
          .whereType<MomCozyNotification>()
          .toList(),
      unreadCount: count,
      nextCursor: response['next_cursor'] as String?,
    );
  }

  @override
  Future<void> markAllRead() async {
    await transport.postJson('$notificationsEndpoint/read-all');
  }

  @override
  Future<NotificationOpenTarget> openNotification(String notificationId) async {
    final response = await transport.postJson(
      '$notificationsEndpoint/${Uri.encodeComponent(notificationId)}/open',
    );
    final raw = response['notification'];
    final notification = raw is Map
        ? _notification(Map<String, Object?>.from(raw))
        : null;
    if (notification == null) {
      throw const FormatException('Incomplete notification target.');
    }
    return NotificationOpenTarget(
      notification: notification,
      route: response['resource_available'] == true
          ? response['route'] as String?
          : null,
    );
  }

  @override
  Future<PushRegistration> registerInstallation({
    required String id,
    required String secret,
    required int revision,
    required String platform,
    required NotificationPermission permission,
    required String locale,
    String? token,
  }) async {
    final value = await transport.postJson(
      '$notificationsEndpoint/installations',
      body: {
        'installation_id': id,
        'installation_secret': secret,
        'revision': revision,
        'platform': platform,
        'permission': permission.wire,
        'locale': locale,
        'token': ?token,
      },
    );
    return PushRegistration(
      bindingId: value['binding_id']! as String,
      tokenRegistered: value['token_registered'] == true,
      pushAvailable: value['push_available'] == true,
    );
  }

  @override
  Future<void> detachInstallation({
    required String id,
    required String secret,
  }) async {
    await transport.postJson(
      '$notificationsEndpoint/installations/$id/detach',
      body: {'installation_secret': secret},
    );
  }

  @override
  Future<Map<String, bool>> preferences() async => Map<String, bool>.from(
    await transport.getJson('$notificationsEndpoint/preferences'),
  );
  @override
  Future<Map<String, bool>> setPreference(
    String category, {
    required bool enabled,
    String? installationId,
  }) async => Map<String, bool>.from(
    await _mutationTransport.patchJson(
      '$notificationsEndpoint/preferences/${Uri.encodeComponent(category)}',
      body: {'enabled': enabled, 'installation_id': ?installationId},
    ),
  );
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
