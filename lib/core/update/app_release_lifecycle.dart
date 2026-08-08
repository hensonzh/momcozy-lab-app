import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppReleaseLifecycleStorage {
  Future<Map<String, String>> readAll();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureAppReleaseLifecycleStorage
    implements AppReleaseLifecycleStorage {
  const FlutterSecureAppReleaseLifecycleStorage({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<Map<String, String>> readAll() => storage.readAll();

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

abstract interface class OnboardingReleasePolicy {
  String get releaseId;

  Future<bool> requiresResetFor(String userId);

  Future<void> markCompletedFor(String userId);
}

class NoopOnboardingReleasePolicy implements OnboardingReleasePolicy {
  const NoopOnboardingReleasePolicy();

  @override
  String get releaseId => '';

  @override
  Future<bool> requiresResetFor(String userId) async => false;

  @override
  Future<void> markCompletedFor(String userId) async {}
}

class AppReleaseLifecycle implements OnboardingReleasePolicy {
  AppReleaseLifecycle({
    required String releaseId,
    this.storage = const FlutterSecureAppReleaseLifecycleStorage(),
    Future<void> Function()? clearFileCache,
  }) : releaseId = releaseId.trim(),
       _clearFileCache = clearFileCache ?? _noop,
       assert(releaseId.trim().isNotEmpty, 'releaseId must not be empty.');

  static const _namespace = 'momcozy.releaseLifecycle.v1';
  static const _installedReleaseKey = '$_namespace.installedRelease';
  static const _pendingCloudResetKey = '$_namespace.pendingCloudReset';
  static const _onboardingCompletePrefix = '$_namespace.onboardingComplete.';
  static const _sessionPrefix = 'momcozy.session.v1.';

  @override
  final String releaseId;
  final AppReleaseLifecycleStorage storage;
  final Future<void> Function() _clearFileCache;

  Future<void> prepareForLaunch() async {
    final installedRelease = await storage.read(_installedReleaseKey);
    if (installedRelease == releaseId) return;

    final storedValues = await storage.readAll();
    final accountKeys = storedValues.keys.where(_isAccountDataKey).toList();
    await Future.wait(accountKeys.map(storage.delete));
    await _clearFileCache();

    // Write pending first. If the process stops before installedRelease is
    // written, the next launch safely repeats the local purge.
    await storage.write(_pendingCloudResetKey, releaseId);
    await storage.write(_installedReleaseKey, releaseId);
  }

  @override
  Future<bool> requiresResetFor(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return false;
    final values = await Future.wait([
      storage.read(_pendingCloudResetKey),
      storage.read(_completionKey(normalizedUserId)),
    ]);
    return values[0] == releaseId && values[1] != releaseId;
  }

  @override
  Future<void> markCompletedFor(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'must not be empty');
    }
    await storage.write(_completionKey(normalizedUserId), releaseId);
  }

  bool _isAccountDataKey(String key) {
    return key.startsWith(_sessionPrefix) ||
        key.contains('.user.') ||
        key.startsWith(_onboardingCompletePrefix);
  }

  String _completionKey(String userId) {
    final digest = sha256.convert(utf8.encode(userId));
    return '$_onboardingCompletePrefix$digest';
  }
}

Future<void> _noop() async {}
