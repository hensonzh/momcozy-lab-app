import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/core/auth/momcozy_session.dart';

class FlutterSecureMomCozySessionStore implements MomCozySessionStore {
  const FlutterSecureMomCozySessionStore({
    this.storage = const FlutterSecureStorage(),
    this.namespace = 'momcozy.session.v1',
  });

  final FlutterSecureStorage storage;
  final String namespace;

  @override
  Future<MomCozySession?> readSession() async {
    final values = await Future.wait([
      storage.read(key: _key('status')),
      storage.read(key: _key('userId')),
      storage.read(key: _key('babyId')),
      storage.read(key: _key('locale')),
      storage.read(key: _key('accessToken')),
      storage.read(key: _key('refreshToken')),
    ]);

    final userId = trimmedSessionValue(values[1]);
    final babyId = trimmedSessionValue(values[2]);
    final locale = trimmedSessionValue(values[3]);
    final accessToken = trimmedSessionValue(values[4]);
    final refreshToken = trimmedSessionValue(values[5]);
    if (userId == null &&
        babyId == null &&
        locale == null &&
        accessToken == null &&
        refreshToken == null) {
      return null;
    }

    return MomCozySession(
      status:
          parseMomCozySessionStatus(values[0]) ??
          statusForSessionSecrets(accessToken, refreshToken),
      userId: userId ?? 'demo-user',
      babyId: babyId ?? 'demo-baby',
      locale: locale ?? 'zh-CN',
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  Future<void> writeSession(MomCozySession session) async {
    await Future.wait([
      _write('status', session.status.name),
      _write('userId', session.userId),
      _write('babyId', session.babyId),
      _write('locale', session.locale),
      _write('accessToken', session.accessToken),
      _write('refreshToken', session.refreshToken),
    ]);
  }

  @override
  Future<void> clearSession() async {
    await Future.wait([
      storage.delete(key: _key('status')),
      storage.delete(key: _key('userId')),
      storage.delete(key: _key('babyId')),
      storage.delete(key: _key('locale')),
      storage.delete(key: _key('accessToken')),
      storage.delete(key: _key('refreshToken')),
    ]);
  }

  Future<void> _write(String key, String? value) {
    return storage.write(key: _key(key), value: trimmedSessionValue(value));
  }

  String _key(String key) => '$namespace.$key';
}
