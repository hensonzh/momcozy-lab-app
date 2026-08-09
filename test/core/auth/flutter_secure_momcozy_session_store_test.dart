import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';

void main() {
  const session = MomCozySession(
    status: MomCozySessionStatus.authenticated,
    userId: 'user-001',
    babyId: 'baby-001',
    locale: 'zh-CN',
    accessToken: 'access-secret',
    refreshToken: 'refresh-secret',
  );

  test('writes one atomic payload and verifies the stored session', () async {
    final storage = _MemorySessionStorage();
    final store = FlutterSecureMomCozySessionStore(storage: storage);

    await store.writeSession(session);

    expect(storage.writeKeys, ['momcozy.session.v1.payload']);
    final payload =
        jsonDecode(storage.values['momcozy.session.v1.payload']!)
            as Map<String, Object?>;
    expect(payload, {
      'schema_version': 1,
      'status': 'authenticated',
      'user_id': 'user-001',
      'baby_id': 'baby-001',
      'locale': 'zh-CN',
      'access_token': 'access-secret',
      'refresh_token': 'refresh-secret',
    });
    final restored = await store.readSession();
    expect(restored?.status, MomCozySessionStatus.authenticated);
    expect(restored?.userId, 'user-001');
    expect(restored?.babyId, 'baby-001');
    expect(restored?.accessToken, 'access-secret');
    expect(restored?.refreshToken, 'refresh-secret');
  });

  test('fails closed when the atomic payload cannot be verified', () async {
    final storage = _MemorySessionStorage(
      readOverride: (key, value) {
        if (key != 'momcozy.session.v1.payload' || value == null) return value;
        final payload = jsonDecode(value) as Map<String, Object?>;
        payload['access_token'] = 'tampered-access';
        return jsonEncode(payload);
      },
    );
    final store = FlutterSecureMomCozySessionStore(storage: storage);

    await expectLater(
      store.writeSession(session),
      throwsA(
        isA<MomCozySessionPersistenceException>().having(
          (error) => error.operation,
          'operation',
          'write_and_verify',
        ),
      ),
    );

    expect(storage.values, isNot(contains('momcozy.session.v1.payload')));
  });

  test('drops a malformed atomic payload instead of restoring it', () async {
    final storage = _MemorySessionStorage(
      initialValues: {'momcozy.session.v1.payload': '{not-json'},
    );
    final store = FlutterSecureMomCozySessionStore(storage: storage);

    expect(await store.readSession(), isNull);
    expect(storage.values, isNot(contains('momcozy.session.v1.payload')));
  });
}

class _MemorySessionStorage implements MomCozySessionStorage {
  _MemorySessionStorage({Map<String, String>? initialValues, this.readOverride})
    : values = Map<String, String>.from(initialValues ?? const {});

  final Map<String, String> values;
  final String? Function(String key, String? value)? readOverride;
  final List<String> writeKeys = <String>[];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async {
    final value = values[key];
    return readOverride?.call(key, value) ?? value;
  }

  @override
  Future<void> write(String key, String value) async {
    writeKeys.add(key);
    values[key] = value;
  }
}
