import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/push_messaging.dart';

class NotificationInstallationIdentity {
  const NotificationInstallationIdentity(this.id, this.secret);
  final String id, secret;
}

abstract interface class NotificationInstallationStore {
  Future<NotificationInstallationIdentity> identity();
  Future<int> nextRevision();
  Future<NotificationPushIntent?> readPending();
  Future<void> writePending(NotificationPushIntent? intent);
}

class SecureNotificationInstallationStore
    implements NotificationInstallationStore {
  SecureNotificationInstallationStore({
    this.storage = const FlutterSecureStorage(),
  });
  final FlutterSecureStorage storage;
  static const _key = 'momcozy.notifications.installation.v1';
  Future<void> _writes = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, Object?>> _read() async {
    final encoded = await storage.read(key: _key);
    if (encoded != null) {
      final value = Map<String, Object?>.from(jsonDecode(encoded) as Map);
      if (value['id'] is String && value['secret'] is String) return value;
    }
    final random = Random.secure();
    String hex(int bytes) => List.generate(
      bytes,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final value = <String, Object?>{
      'id': '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}',
      'secret': hex(32),
      'revision': 0,
    };
    await storage.write(key: _key, value: jsonEncode(value));
    return value;
  }

  @override
  Future<NotificationInstallationIdentity> identity() => _serialize(() async {
    final value = await _read();
    return NotificationInstallationIdentity(
      value['id']! as String,
      value['secret']! as String,
    );
  });
  @override
  Future<int> nextRevision() => _serialize(() async {
    final value = await _read();
    final revision = (value['revision'] as int? ?? 0) + 1;
    value['revision'] = revision;
    await storage.write(key: _key, value: jsonEncode(value));
    return revision;
  });
  @override
  Future<NotificationPushIntent?> readPending() => _serialize(() async {
    final pending = (await _read())['pending'];
    return pending is Map
        ? NotificationPushIntent.fromData(Map<String, Object?>.from(pending))
        : null;
  });
  @override
  Future<void> writePending(NotificationPushIntent? intent) =>
      _serialize(() async {
        final value = await _read();
        value['pending'] = intent?.toJson();
        await storage.write(key: _key, value: jsonEncode(value));
      });
}
