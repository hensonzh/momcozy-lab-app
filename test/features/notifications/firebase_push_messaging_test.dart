import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/features/notifications/data/firebase_push_messaging.dart';

void main() {
  test(
    'fresh iOS install starts remote registration before reading APNs',
    () async {
      final sdk = _Messaging();
      final gateway = FirebasePushMessaging.withMessaging(sdk, isIOS: true);
      addTearDown(gateway.dispose);

      expect(await gateway.token(), 'fcm-token');
      expect(sdk.events, ['enable', 'apns', 'fcm']);
    },
  );

  test(
    'iOS waits for asynchronous APNs registration before requesting FCM',
    () async {
      final sdk = _Messaging()..readyAfter = 3;
      final gateway = FirebasePushMessaging.withMessaging(sdk, isIOS: true);
      addTearDown(gateway.dispose);

      expect(await gateway.token(), 'fcm-token');
      expect(sdk.apnsReads, 3);
      expect(sdk.events.last, 'fcm');
    },
  );

  test(
    'missing APNs stays pending and a later retry can acquire the token',
    () async {
      final sdk = _Messaging()..readyAfter = null;
      final gateway = FirebasePushMessaging.withMessaging(sdk, isIOS: true);
      addTearDown(gateway.dispose);

      expect(await gateway.token(), isNull);
      expect(sdk.enabled, isTrue);
      expect(sdk.events, isNot(contains('fcm')));
      sdk.readyAfter = 1;
      expect(await gateway.token(), 'fcm-token');
    },
  );

  test('Android does not wait for APNs and logout pauses auto-init', () async {
    final sdk = _Messaging()..readyAfter = null;
    final gateway = FirebasePushMessaging.withMessaging(sdk, isIOS: false);
    addTearDown(gateway.dispose);

    expect(await gateway.token(), 'fcm-token');
    await gateway.pauseTokenRefresh();
    expect(sdk.events, ['enable', 'fcm', 'disable']);
    expect(sdk.enabled, isFalse);
  });
}

class _Messaging extends Fake implements FirebaseMessaging {
  bool enabled = false;
  int? readyAfter = 1;
  int apnsReads = 0;
  final events = <String>[];

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    this.enabled = enabled;
    events.add(enabled ? 'enable' : 'disable');
  }

  @override
  Future<String?> getAPNSToken() async {
    events.add('apns');
    apnsReads++;
    return enabled && readyAfter != null && apnsReads >= readyAfter!
        ? 'apns-token'
        : null;
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    events.add('fcm');
    return 'fcm-token';
  }
}
