import 'dart:async';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'fixture_api_transport.dart';

final inventoryBabyNow = DateTime.utc(2026, 9, 13, 8);

/// Isolated server boundary: real repositories/codecs and UI consume these
/// responses. No real baby's records are changed by inventory journeys.
class BabyInventoryTransport extends FixtureApiJsonTransportByPath {
  BabyInventoryTransport() : super({}) {
    for (final p in profiles) {
      p['created_at'] = inventoryBabyNow.toIso8601String();
      p['updated_at'] = inventoryBabyNow.toIso8601String();
    }
  }
  final profiles = <Map<String, Object?>>[
    {
      'id': 'inventory-baby',
      'name': 'Luna',
      'birth_date': '2026-08-22',
      'sex': 'female',
      'feeding_mode': 'unknown',
      'version': 1,
    },
    {
      'id': 'inventory-baby-2',
      'name': 'Leo',
      'birth_date': '2026-08-20',
      'sex': 'male',
      'feeding_mode': 'mixed_feeding',
      'version': 1,
    },
  ];
  final records = <Map<String, Object?>>[];
  final deleted = <String, Map<String, Object?>>{};
  bool failRead = false, failWrite = false;
  int nextId = 1;
  DateTime clock = inventoryBabyNow;
  Completer<void>? readGate, writeGate;
  void check(bool failure) {
    if (failure) {
      throw ApiHttpException.fromBody({
        'http_status': 503,
        'body': {
          'error': {'code': 'unavailable'},
        },
      });
    }
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    getPaths.add(path);
    if (path == '/v1/babies') return {'items': profiles};
    if (path.contains('/records')) {
      await readGate?.future;
      check(failRead);
      final baby = path.split('/')[3];
      final items = records.where((r) {
        final o = r['observation'] as Map<String, Object?>;
        final date = (o['recorded_on'] ?? o['occurred_at'])
            .toString()
            .substring(0, 10);
        return r['baby_id'] == baby &&
            (query['kind'] == null || o['kind'] == query['kind']) &&
            (query['start_date'] == null ||
                date.compareTo(query['start_date'].toString()) >= 0) &&
            (query['end_date'] == null ||
                date.compareTo(query['end_date'].toString()) <= 0);
      }).toList();
      if (path.endsWith('/latest-growth')) {
        final metrics = <Object?, Map<String, Object?>>{};
        for (final r in items) {
          final o = r['observation'] as Map<String, Object?>;
          if (o['kind'] == 'growth') metrics[o['metric']] = r;
        }
        return {'items': metrics.values.toList()};
      }
      final offset = query['offset'] as int? ?? 0,
          limit = query['limit'] as int? ?? 100;
      return {
        'items': items.skip(offset).take(limit).toList(),
        'total': items.length,
        'offset': offset,
        'limit': limit,
        'server_time': inventoryBabyNow.toIso8601String(),
      };
    }
    return super.getJson(path, query: query);
  }

  Map<String, Object?> serverObservation(Map<String, Object?> observation) => {
    ...observation,
    if (observation['kind'] == 'growth')
      'unit': observation['metric'] == 'weight' ? 'kg' : 'cm',
    if (observation['kind'] == 'development')
      'label': babyDevelopmentItems[observation['item_id']],
  };

  Map<String, Object?> create(String baby, Map<String, Object?> observation) {
    final row = <String, Object?>{
      'id': 'inventory-record-${nextId++}',
      'baby_id': baby,
      'version': 1,
      'observation': serverObservation(observation),
      'deleted_at': null,
    };
    records.add(row);
    return row;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await writeGate?.future;
    check(failWrite);
    mutationPaths.add(path);
    if (path.endsWith('/restore')) {
      final id = path.split('/')[5];
      final row = deleted.remove(id)!;
      row['version'] = (row['version'] as int) + 1;
      records.add(row);
      return row;
    }
    if (path.endsWith('/records')) {
      return create(
        path.split('/')[3],
        Map<String, Object?>.from(body['observation'] as Map),
      );
    }
    if (path.endsWith('/batch')) {
      return {
        'items': [
          for (final o in body['observations'] as List)
            create(path.split('/')[3], Map<String, Object?>.from(o as Map)),
        ],
      };
    }
    if (path == '/v1/babies') {
      final p = {
        ...body,
        'id': 'inventory-baby-${profiles.length + 1}',
        'created_at': inventoryBabyNow.toIso8601String(),
        'updated_at': inventoryBabyNow.toIso8601String(),
        'version': 1,
      }..remove('timezone');
      profiles.add(p);
      return p;
    }
    return super.postJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    await writeGate?.future;
    check(failWrite);
    mutationPaths.add(path);
    final id = path.split('/').last;
    final row = (path.contains('/records/') ? records : profiles).singleWhere(
      (r) => r['id'] == id,
    );
    if (body['observation'] != null) {
      row['observation'] = serverObservation(
        Map<String, Object?>.from(body['observation'] as Map),
      );
    } else {
      row.addAll(
        {...body}
          ..remove('timezone')
          ..remove('expected_version'),
      );
    }
    row['version'] = (row['version'] as int) + 1;
    return row;
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    await writeGate?.future;
    check(failWrite);
    mutationPaths.add(path);
    final id = path.split('/').last;
    final row = records.singleWhere((r) => r['id'] == id);
    records.remove(row);
    row['version'] = (row['version'] as int) + 1;
    deleted[id] = row;
    return {'id': id, 'version': row['version']};
  }
}
