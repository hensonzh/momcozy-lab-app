import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';

/// Deliberately contains no HTTP client, persistence, or production credentials.
/// Only the endpoints needed by the public, fictional demo are implemented.
class DemoMemoryTransport
    implements ApiJsonTransport, ApiJsonMutationTransport {
  DemoMemoryTransport({DateTime Function()? now}) : _now = now ?? DateTime.now {
    reset();
  }

  final DateTime Function() _now;
  late Map<String, Object?> _profile;
  late Map<String, Object?> _lactation;
  late Map<String, Object?> _experience;
  late List<Map<String, Object?>> _babies;
  late List<Map<String, Object?>> _records;
  late Map<String, Map<String, Object?>> _deletedRecords;
  late List<Map<String, Object?>> _schedule;
  int _nextId = 0;

  void reset() {
    final today = _now().toUtc();
    final birth = LocalDate.fromDateTime(
      today.subtract(const Duration(days: 60)),
    );
    final created = today.subtract(const Duration(days: 60)).toIso8601String();
    final now = today.toIso8601String();
    _nextId = 0;
    _profile = {'preferred_name': 'Mia', 'display_name': 'Mia', 'age': 30};
    _lactation = {'actual_delivery_date': birth.toString()};
    _experience = {
      'profile': {
        'preferred_name': 'Mia',
        'actual_delivery_date': birth.toString(),
      },
      'concerns': <Object?>[],
      'order': <Object?>[],
      'records': [
        {
          'id': 'demo-mood',
          'kind': 'energy',
          'occurred_at': now,
          'value': 'Managing',
          'fields': <String, Object?>{},
        },
      ],
    };
    _babies = [
      {
        'id': 'demo-baby',
        'name': 'Luna',
        'version': 1,
        'birth_date': birth.toString(),
        'sex': 'female',
        'feeding_mode': 'mixed_feeding',
        'created_at': created,
        'updated_at': now,
      },
    ];
    _deletedRecords = {};
    _records = [
      _record('demo-feeding', 'demo-baby', {
        'kind': 'feeding',
        'occurred_at': today
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'method': 'formula',
        'side': null,
        'volume_ml': 75,
        'duration_minutes': null,
        'note': '',
      }),
      _record('demo-diaper', 'demo-baby', {
        'kind': 'diaper',
        'occurred_at': today
            .subtract(const Duration(hours: 2))
            .toIso8601String(),
        'diaper_kind': 'wet',
        'color': null,
        'consistency': null,
        'signs': <String>[],
        'note': '',
      }),
      _record('demo-weight', 'demo-baby', {
        'kind': 'growth',
        'recorded_on': LocalDate.fromDateTime(
          today.subtract(const Duration(days: 1)),
        ).toString(),
        'timezone': 'UTC',
        'metric': 'weight',
        'value': 4.8,
        'unit': 'kg',
      }),
    ];
    _schedule = [
      {
        'id': 'demo-check-in',
        'title': 'A little time for yourself',
        'date': LocalDate.fromDateTime(today).toString(),
        'start_time': '15:00',
        'note': 'A fictional schedule item',
        'updated_at': now,
      },
    ];
  }

  Map<String, Object?> _record(
    String id,
    String babyId,
    Map<String, Object?> observation,
  ) => {
    'id': id,
    'baby_id': babyId,
    'version': 1,
    'observation': observation,
    'created_at': _now().toUtc().toIso8601String(),
    'updated_at': _now().toUtc().toIso8601String(),
    'deleted_at': null,
  };

  String _id(String prefix) => 'demo-$prefix-${++_nextId}';

  /// Copy data at the boundary so widgets cannot mutate the in-memory store.
  Map<String, Object?> _copy(Map<String, Object?> value) => {
    for (final entry in value.entries)
      entry.key: switch (entry.value) {
        Map value => _copy(Map<String, Object?>.from(value)),
        List value => value.map((item) {
          if (item is Map) return _copy(Map<String, Object?>.from(item));
          if (item is List) return List<Object?>.from(item);
          return item;
        }).toList(),
        final value => value,
      },
  };

  Never _unsupported(String method, String path) =>
      throw UnsupportedError('Not available in the Web demo: $method $path');

  String _localPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !path.startsWith('/')) {
      _unsupported('PATH', path);
    }
    return uri.path;
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final clean = _localPath(path);
    if (clean == '/v1/profile/me') return _copy(_profile);
    if (clean == '/v1/profile/lactation') return _copy(_lactation);
    if (clean == '/v1/profile/me-experience') return _copy(_experience);
    if (clean == '/v1/babies') return _copy({'items': _babies});
    if (clean == '/v1/records/pumping') return {'items': <Object?>[]};
    if (clean == '/v1/schedule') {
      final start = query['start_date']?.toString();
      final end = query['end_date']?.toString();
      final entries = _schedule
          .where(
            (item) =>
                (start == null ||
                    (item['date'] as String).compareTo(start) >= 0) &&
                (end == null || (item['date'] as String).compareTo(end) <= 0),
          )
          .toList();
      final offset = (query['offset'] as int? ?? 0).clamp(0, entries.length);
      final limit = (query['limit'] as int? ?? 100).clamp(1, 200);
      return _copy({
        'personal': entries.skip(offset).take(limit).toList(),
        'has_more': offset + limit < entries.length,
        'server_time': _now().toUtc().toIso8601String(),
      });
    }
    final babyPath = RegExp(
      r'^/v1/babies/([^/]+)/records(?:/(latest-growth))?$',
    ).firstMatch(clean);
    if (babyPath != null) {
      final babyId = babyPath.group(1)!;
      _requireBaby(babyId);
      final values = _records.where(
        (record) => record['baby_id'] == babyId && record['deleted_at'] == null,
      );
      if (babyPath.group(2) != null) {
        final growth = values
            .where(
              (record) => (record['observation'] as Map)['kind'] == 'growth',
            )
            .toList();
        return _copy({'items': growth.take(3).toList()});
      }
      final start = query['start_date']?.toString();
      final end = query['end_date']?.toString();
      final kind = query['kind']?.toString();
      final filtered = values.where((record) {
        final observation = record['observation'] as Map;
        final day =
            (observation['recorded_on'] ?? observation['occurred_at'])
                ?.toString()
                .substring(0, 10) ??
            '';
        return (kind == null || observation['kind'] == kind) &&
            (start == null || day.compareTo(start) >= 0) &&
            (end == null || day.compareTo(end) < 0);
      }).toList();
      final offset = (query['offset'] as int? ?? 0).clamp(0, filtered.length);
      final limit = (query['limit'] as int? ?? 100).clamp(1, 200);
      return _copy({
        'items': filtered.skip(offset).take(limit).toList(),
        'total': filtered.length,
        'offset': offset,
        'limit': limit,
        'server_time': _now().toUtc().toIso8601String(),
      });
    }
    _unsupported('GET', path);
  }

  void _requireBaby(String id) {
    if (!_babies.any((baby) => baby['id'] == id)) _unsupported('BABY', id);
  }

  Map<String, Object?> _saveRecord(
    String babyId,
    Map<String, Object?> observation, {
    Map<String, Object?>? existing,
  }) {
    _requireBaby(babyId);
    final record = _record(
      existing?['id'] as String? ?? _id('record'),
      babyId,
      _copy(observation),
    );
    if (existing != null) {
      record['version'] = (existing['version'] as int) + 1;
      _records.remove(existing);
    }
    _records.add(record);
    return _copy(record);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final clean = _localPath(path);
    final restore = RegExp(
      r'^/v1/babies/([^/]+)/records/([^/]+)/restore$',
    ).firstMatch(clean);
    if (restore != null) {
      _requireBaby(restore.group(1)!);
      final deleted = _deletedRecords[restore.group(2)];
      if (deleted == null ||
          deleted['baby_id'] != restore.group(1) ||
          deleted['version'] != body['expected_version']) {
        _unsupported('RESTORE', path);
      }
      _deletedRecords.remove(restore.group(2));
      deleted['deleted_at'] = null;
      deleted['version'] = (deleted['version'] as int) + 1;
      _records.add(deleted);
      return _copy(deleted);
    }
    if (clean == '/v1/schedule/personal') {
      final entry = {
        'id': _id('schedule'),
        'title': body['title'],
        'date': body['date'],
        'start_time': body['start_time'],
        'note': body['note'],
        'updated_at': _now().toUtc().toIso8601String(),
      };
      _schedule.add(entry);
      return _copy(entry);
    }
    if (clean == '/v1/babies') {
      final now = _now().toUtc().toIso8601String();
      final profile = {
        'id': _id('baby'),
        'name': body['name'],
        'birth_date': body['birth_date'],
        'sex': body['sex'],
        'feeding_mode': body['feeding_mode'],
        'version': 1,
        'created_at': now,
        'updated_at': now,
      };
      _babies.add(profile);
      return _copy(profile);
    }
    final match = RegExp(
      r'^/v1/babies/([^/]+)/records(?:/(batch))?$',
    ).firstMatch(clean);
    if (match != null) {
      final babyId = match.group(1)!;
      if (match.group(2) == null) {
        return _saveRecord(
          babyId,
          Map<String, Object?>.from(body['observation'] as Map),
        );
      }
      final observations = (body['observations'] as List).cast<Map>();
      final saved = observations
          .map((value) => _saveRecord(babyId, Map<String, Object?>.from(value)))
          .toList();
      return {'items': saved};
    }
    _unsupported('POST', path);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final clean = _localPath(path);
    if (clean == '/v1/profile/me-experience/order') {
      _experience['order'] = List<Object?>.from(body['order'] as List);
      return {'order': List<Object?>.from(_experience['order'] as List)};
    }
    final concern = RegExp(
      r'^/v1/profile/me-experience/concerns/([^/]+)$',
    ).firstMatch(clean);
    if (concern != null && concern.group(1) == body['id']) {
      final values = _experience['concerns'] as List;
      values.removeWhere((value) => (value as Map)['id'] == body['id']);
      values.add(_copy(body));
      return _copy(body);
    }
    final observation = RegExp(
      r'^/v1/profile/me-experience/records/([^/]+)$',
    ).firstMatch(clean);
    if (observation != null && observation.group(1) == body['id']) {
      final values = _experience['records'] as List;
      values.removeWhere((value) => (value as Map)['id'] == body['id']);
      values.add(_copy(body));
      return _copy(body);
    }
    final baby = RegExp(r'^/v1/babies/([^/]+)$').firstMatch(clean);
    if (baby != null) {
      final current = _babies.singleWhere(
        (value) => value['id'] == baby.group(1),
      );
      if (body['expected_version'] != current['version']) {
        _unsupported('STALE', path);
      }
      current.addAll(
        {...body}
          ..remove('expected_version')
          ..remove('timezone'),
      );
      current['version'] = (current['version'] as int) + 1;
      current['updated_at'] = _now().toUtc().toIso8601String();
      return _copy(current);
    }
    final record = RegExp(
      r'^/v1/babies/([^/]+)/records/([^/]+)$',
    ).firstMatch(clean);
    if (record != null) {
      final current = _records.singleWhere(
        (value) =>
            value['baby_id'] == record.group(1) &&
            value['id'] == record.group(2),
      );
      if (body['expected_version'] != current['version']) {
        _unsupported('STALE', path);
      }
      return _saveRecord(
        record.group(1)!,
        Map<String, Object?>.from(body['observation'] as Map),
        existing: current,
      );
    }
    _unsupported('PUT', path);
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    final clean = _localPath(path);
    if (clean == '/v1/profile/me-experience/profile') {
      (_experience['profile'] as Map).addAll(body);
      if (body['preferred_name'] is String) {
        _profile['preferred_name'] = body['preferred_name'];
      }
      return _copy(Map<String, Object?>.from(_experience['profile'] as Map));
    }
    final schedule = RegExp(
      r'^/v1/schedule/personal/([^/]+)$',
    ).firstMatch(clean);
    if (schedule != null) {
      final current = _schedule.singleWhere(
        (value) => value['id'] == schedule.group(1),
      );
      if (body['expected_updated_at'] != current['updated_at']) {
        _unsupported('STALE', path);
      }
      current.addAll({...body}..remove('expected_updated_at'));
      current['updated_at'] = _now().toUtc().toIso8601String();
      return _copy(current);
    }
    _unsupported('PATCH', path);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final clean = _localPath(path);
    final schedule = RegExp(
      r'^/v1/schedule/personal/([^/]+)$',
    ).firstMatch(clean);
    if (schedule != null) {
      _schedule.removeWhere((item) => item['id'] == schedule.group(1));
      return {};
    }
    final record = RegExp(
      r'^/v1/babies/([^/]+)/records/([^/]+)$',
    ).firstMatch(clean);
    if (record != null) {
      final current = _records.singleWhere(
        (value) =>
            value['baby_id'] == record.group(1) &&
            value['id'] == record.group(2),
      );
      if (headers['If-Match'] != current['version'].toString()) {
        _unsupported('STALE', path);
      }
      current['deleted_at'] = _now().toUtc().toIso8601String();
      current['version'] = (current['version'] as int) + 1;
      _records.remove(current);
      _deletedRecords[current['id'] as String] = current;
      return {'id': current['id'], 'version': current['version']};
    }
    _unsupported('DELETE', path);
  }
}
