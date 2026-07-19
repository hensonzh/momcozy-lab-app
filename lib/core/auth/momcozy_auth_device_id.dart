import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class MomCozyAuthDeviceIdStore {
  Future<String> readOrCreateDeviceId();
}

class FlutterSecureMomCozyAuthDeviceIdStore
    implements MomCozyAuthDeviceIdStore {
  const FlutterSecureMomCozyAuthDeviceIdStore({
    this.storage = const FlutterSecureStorage(),
    this.key = 'momcozy.auth.device_id.v1',
  });

  final FlutterSecureStorage storage;
  final String key;

  @override
  Future<String> readOrCreateDeviceId() async {
    final existing = (await storage.read(key: key))?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    await storage.write(key: key, value: generated);
    return generated;
  }
}

String _generateDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'flutter-$hex';
}
