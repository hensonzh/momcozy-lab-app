import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class MomCozyLastInviteCodeStore {
  Future<String?> readLastInviteCode();

  Future<void> writeLastInviteCode(String inviteCode);
}

class FlutterSecureMomCozyLastInviteCodeStore
    implements MomCozyLastInviteCodeStore {
  const FlutterSecureMomCozyLastInviteCodeStore({
    this.storage = const FlutterSecureStorage(),
    this.key = 'momcozy.auth.last_invite_code.v1',
  });

  final FlutterSecureStorage storage;
  final String key;

  @override
  Future<String?> readLastInviteCode() async {
    final value = (await storage.read(key: key))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> writeLastInviteCode(String inviteCode) async {
    final value = inviteCode.trim();
    if (value.isEmpty) return;
    await storage.write(key: key, value: value);
  }
}
