import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';

abstract interface class MomCozySessionStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureMomCozySessionStorage implements MomCozySessionStorage {
  const FlutterSecureMomCozySessionStorage({
    this.storage = const FlutterSecureStorage(),
  });

  final FlutterSecureStorage storage;

  @override
  Future<void> delete(String key) => storage.delete(key: key);

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return storage.write(key: key, value: value);
  }
}

class MomCozySessionPersistenceException implements Exception {
  const MomCozySessionPersistenceException({
    required this.operation,
    required this.causeType,
  });

  final String operation;
  final String causeType;

  @override
  String toString() {
    return 'MomCozySessionPersistenceException('
        'operation: $operation, causeType: $causeType)';
  }
}

class FlutterSecureMomCozySessionStore implements MomCozySessionStore {
  const FlutterSecureMomCozySessionStore({
    this.storage = const FlutterSecureMomCozySessionStorage(),
    this.namespace = 'momcozy.session.v1',
  });

  static const _schemaVersion = 1;
  static const _legacyFields = <String>[
    'status',
    'userId',
    'babyId',
    'locale',
    'accessToken',
    'refreshToken',
  ];

  final MomCozySessionStorage storage;
  final String namespace;

  @override
  Future<MomCozySession?> readSession() async {
    try {
      final payload = await storage.read(_payloadKey);
      if (payload != null && payload.trim().isNotEmpty) {
        try {
          return _decodePayload(payload);
        } on FormatException {
          await _deletePayloadBestEffort();
          return null;
        }
      }
      return _readLegacySession();
    } catch (error, stackTrace) {
      _throwPersistenceFailure('read', error, stackTrace);
    }
  }

  @override
  Future<void> writeSession(MomCozySession session) async {
    try {
      final encoded = _encodePayload(session);
      final expected = _decodePayload(encoded);
      await storage.write(_payloadKey, encoded);
      final persisted = _decodePayload(await storage.read(_payloadKey));
      if (!_sameSession(expected, persisted)) {
        throw StateError('Persisted session did not match the issued session.');
      }
    } catch (error, stackTrace) {
      await _deletePayloadBestEffort();
      _throwPersistenceFailure('write_and_verify', error, stackTrace);
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      // The atomic payload is authoritative, so remove it before cleaning up
      // fields written by older builds.
      await storage.delete(_payloadKey);
      await Future.wait(
        _legacyFields.map((field) => storage.delete(_legacyKey(field))),
      );
    } catch (error, stackTrace) {
      _throwPersistenceFailure('clear', error, stackTrace);
    }
  }

  Future<MomCozySession?> _readLegacySession() async {
    final values = await Future.wait(
      _legacyFields.map((field) => storage.read(_legacyKey(field))),
    );
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

  String _encodePayload(MomCozySession session) {
    return jsonEncode({
      'schema_version': _schemaVersion,
      'status': session.status.name,
      'user_id': trimmedSessionValue(session.userId),
      'baby_id': trimmedSessionValue(session.babyId),
      'locale': trimmedSessionValue(session.locale),
      'access_token': trimmedSessionValue(session.accessToken),
      'refresh_token': trimmedSessionValue(session.refreshToken),
    });
  }

  MomCozySession _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      throw const FormatException('Session payload is missing.');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Session payload is not an object.');
    }
    final payload = Map<String, Object?>.from(decoded);
    if (payload['schema_version'] != _schemaVersion) {
      throw const FormatException('Session payload version is unsupported.');
    }
    final status = parseMomCozySessionStatus(
      _requiredString(payload, 'status'),
    );
    if (status == null) {
      throw const FormatException('Session status is invalid.');
    }
    return MomCozySession(
      status: status,
      userId: _requiredString(payload, 'user_id'),
      babyId: _requiredString(payload, 'baby_id'),
      locale: _requiredString(payload, 'locale'),
      accessToken: _optionalString(payload['access_token']),
      refreshToken: _optionalString(payload['refresh_token']),
    );
  }

  String _requiredString(Map<String, Object?> payload, String key) {
    final value = _optionalString(payload[key]);
    if (value == null) {
      throw FormatException('Session field $key is missing.');
    }
    return value;
  }

  String? _optionalString(Object? value) {
    return value is String ? trimmedSessionValue(value) : null;
  }

  bool _sameSession(MomCozySession left, MomCozySession right) {
    return left.status == right.status &&
        left.userId == right.userId &&
        left.babyId == right.babyId &&
        left.locale == right.locale &&
        left.accessToken == right.accessToken &&
        left.refreshToken == right.refreshToken;
  }

  Future<void> _deletePayloadBestEffort() async {
    try {
      await storage.delete(_payloadKey);
    } catch (_) {
      // The original persistence failure remains the useful diagnostic.
    }
  }

  Never _throwPersistenceFailure(
    String operation,
    Object cause,
    StackTrace stackTrace,
  ) {
    Error.throwWithStackTrace(
      MomCozySessionPersistenceException(
        operation: operation,
        causeType: cause.runtimeType.toString(),
      ),
      stackTrace,
    );
  }

  String get _payloadKey => '$namespace.payload';

  String _legacyKey(String field) => '$namespace.$field';
}
