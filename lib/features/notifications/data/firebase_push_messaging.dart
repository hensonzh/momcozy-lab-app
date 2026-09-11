import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../domain/push_messaging.dart';

@pragma('vm:entry-point')
Future<void> notificationBackgroundMessage(RemoteMessage message) async {
  // FCM displays the generic envelope. Never fetch private content in a
  // background isolate or persist message bodies outside the authenticated inbox.
}

class FirebasePushMessaging implements PushMessagingGateway {
  FirebasePushMessaging() : _isIOS = Platform.isIOS;

  @visibleForTesting
  FirebasePushMessaging.withMessaging(this._messaging, {required this._isIOS});

  final bool _isIOS;
  FirebaseMessaging? _messaging;
  final _tokens = StreamController<String>.broadcast();
  final _foreground = StreamController<NotificationPushIntent>.broadcast();
  final _opened = StreamController<NotificationPushIntent>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _disposed = false;
  Future<bool>? _initializing;

  @override
  Future<bool> initialize() => _initializing ??= _initialize();

  Future<bool> _initialize() async {
    const apiKey = String.fromEnvironment('MOMCOZY_FIREBASE_API_KEY');
    const appId = String.fromEnvironment('MOMCOZY_FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('MOMCOZY_FIREBASE_SENDER_ID');
    const projectId = String.fromEnvironment('MOMCOZY_FIREBASE_PROJECT_ID');
    if (!(Platform.isAndroid || Platform.isIOS) ||
        [apiKey, appId, senderId, projectId].any((value) => value.isEmpty)) {
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      if (_disposed) return false;
      _messaging = FirebaseMessaging.instance;
      await _messaging!.setAutoInitEnabled(false);
      await _messaging!.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      FirebaseMessaging.onBackgroundMessage(notificationBackgroundMessage);
      _subscriptions.add(
        _messaging!.onTokenRefresh.listen(_tokens.add, onError: (Object _) {}),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen(
          (message) => _emit(_foreground, message),
        ),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (message) => _emit(_opened, message),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _emit(
    StreamController<NotificationPushIntent> stream,
    RemoteMessage message,
  ) {
    final intent = NotificationPushIntent.fromData(message.data);
    if (intent != null && !_disposed) stream.add(intent);
  }

  // The permission controller must read OS authorization before calling this.
  @override
  Future<String?> token() async {
    if (_messaging == null || _disposed) return null;
    // On iOS this also starts registerForRemoteNotifications. Waiting for APNs
    // first would deadlock a fresh install while native auto-init is disabled.
    await _messaging!.setAutoInitEnabled(true);
    if (_isIOS) {
      for (var attempt = 0; ; attempt++) {
        if (_disposed) return null;
        if (await _messaging!.getAPNSToken() != null) break;
        // Give first registration a bounded readiness window. If APNs remains
        // unavailable, keep pending; onTokenRefresh or a later sync retries.
        if (attempt == 10) return null;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    if (_disposed) return null;
    return _messaging!.getToken();
  }

  @override
  Future<NotificationPushIntent?> initialMessage() async {
    final message = await _messaging?.getInitialMessage();
    return message == null
        ? null
        : NotificationPushIntent.fromData(message.data);
  }

  @override
  Future<void> pauseTokenRefresh() async =>
      _messaging?.setAutoInitEnabled(false);
  @override
  Stream<String> get tokenChanges => _tokens.stream;
  @override
  Stream<NotificationPushIntent> get foregroundMessages => _foreground.stream;
  @override
  Stream<NotificationPushIntent> get openedMessages => _opened.stream;
  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _tokens.close();
    await _foreground.close();
    await _opened.close();
  }
}
