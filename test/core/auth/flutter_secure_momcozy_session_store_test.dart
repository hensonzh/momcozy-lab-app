import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
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

  test(
    'an account without a baby is stored and restored without a placeholder',
    () async {
      final storage = _MemorySessionStorage();
      final store = FlutterSecureMomCozySessionStore(storage: storage);
      const noBaby = MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'new-owner',
        babyId: '',
        locale: 'en-US',
        accessToken: 'issued-token',
      );
      await store.writeSession(noBaby);
      final payload =
          jsonDecode(storage.values['momcozy.session.v1.payload']!) as Map;
      expect(payload['baby_id'], '');
      expect((await store.readSession())?.babyId, isEmpty);
    },
  );

  test(
    'legacy session with no baby does not create a demo association',
    () async {
      final storage = _MemorySessionStorage(
        initialValues: {
          'momcozy.session.v1.status': 'authenticated',
          'momcozy.session.v1.userId': 'legacy-owner',
          'momcozy.session.v1.accessToken': 'issued-token',
        },
      );
      final restored = await FlutterSecureMomCozySessionStore(
        storage: storage,
      ).readSession();
      expect(restored?.userId, 'legacy-owner');
      expect(restored?.babyId, isEmpty);
    },
  );

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

  test(
    'secure storage failures retain only a non-secret platform code',
    () async {
      final storage = _MemorySessionStorage(
        readOverride: (_, _) => throw PlatformException(
          code: 'keychain-unavailable',
          message: 'may include sensitive device details',
          details: -34018,
        ),
      );
      final store = FlutterSecureMomCozySessionStore(storage: storage);
      await expectLater(
        store.readSession(),
        throwsA(
          isA<MomCozySessionPersistenceException>()
              .having(
                (error) => error.causeCode,
                'causeCode',
                'keychain-unavailable',
              )
              .having((error) => error.causeStatus, 'causeStatus', -34018)
              .having(
                (error) => error.toString(),
                'safe diagnostic',
                isNot(contains('sensitive device details')),
              ),
        ),
      );
    },
  );
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
