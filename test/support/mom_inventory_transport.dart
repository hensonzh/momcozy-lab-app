import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'fixture_api_transport.dart';

final inventoryMomNow = DateTime.utc(2026, 9, 13, 8);

/// Isolated HTTP boundary; production repositories parse every response.
class MomInventoryTransport extends FixtureApiJsonTransportByPath {
  MomInventoryTransport()
    : super({
        '/v1/profile/me': {'preferred_name': 'Mia', 'age': 30},
        '/v1/profile/lactation': {
          'actual_delivery_date': '2026-08-24',
          'current_delivery_method': 'vaginal',
        },
        '/v1/care/catalog': Map<String, Object?>.from(
          jsonDecode(
                File(
                  'test/fixtures/product_baseline/care_catalog.json',
                ).readAsStringSync(),
              )
              as Map,
        ),
        '/v1/care/overview': {'orders': [], 'episodes': []},
      });
  final records = <Map<String, Object?>>[];
  final deleted = <String, Map<String, Object?>>{};
  final failingReads = <String>{};
  final readGates = <String, Completer<void>>{};
  bool failWrite = false;
  int failureStatus = 503;
  Completer<void>? writeGate;
  int nextId = 1;

  void check(bool fail) {
    if (fail) {
      throw ApiHttpException.fromBody({
        'http_status': failureStatus,
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
    await readGates[path]?.future;
    check(failingReads.contains(path));

    if (path == '/v1/lactation/records') {
      return {
        'items': records.where((r) {
          final instant = DateTime.parse(
            (r['observation'] as Map)['occurred_at'] as String,
          );
          return (query['start'] == null ||
                  !instant.isBefore(
                    DateTime.parse(query['start'] as String),
                  )) &&
              (query['end'] == null ||
                  instant.isBefore(DateTime.parse(query['end'] as String)));
        }).toList(),
      };
    }
    return super.getJson(path, query: query);
  }

  Map<String, Object?> seedMilk(Map<String, Object?> observation) {
    final row = <String, Object?>{
      'id': 'inventory-milk-${nextId++}',
      'owner_user_id': 'inventory-user',
      'version': 1,
      'observation': observation,
    };
    records.add(row);
    return row;
  }

  void seedPlan() {
    final episode = <String, Object?>{
      'id': 'inventory-episode',
      'order_id': 'inventory-order',
      'package_id': 'feeding-confidence',
      'status': 'active',
      'stage': 'preparation',
      'total_sessions': 2,
      'remaining_sessions': 2,
      'starts_at': inventoryMomNow.toIso8601String(),
      'ends_at': inventoryMomNow.add(const Duration(days: 7)).toIso8601String(),
      'version': 1,
    };
    responsesByPath['/v1/care/overview'] = {
      'orders': [
        {
          'id': 'inventory-order',
          'package_id': 'feeding-confidence',
          'status': 'paid',
          'price_minor': 21900,
          'currency': 'USD',
          'duration_days': 7,
          'total_sessions': 2,
          'payment_mode': 'sandbox',
          'region': 'CA',
          'version': 1,
          'created_at': inventoryMomNow.toIso8601String(),
          'updated_at': inventoryMomNow.toIso8601String(),
        },
      ],
      'episodes': [episode],
    };
    responsesByPath['/v1/care/episodes/inventory-episode/booking'] = {
      'episode': episode,
      'providers': [],
      'appointments': [],
      'server_time': inventoryMomNow.toIso8601String(),
    };
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
      final id = path.split('/')[4];
      final row = deleted.remove(id)!;
      row['version'] = (row['version'] as int) + 1;
      records.add(row);
      return row;
    }
    if (path == '/v1/lactation/records') {
      return seedMilk(Map<String, Object?>.from(body['observation'] as Map));
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

    if (path.startsWith('/v1/lactation/records/')) {
      final row = records.singleWhere((r) => r['id'] == path.split('/').last);
      row['observation'] = body['observation'];
      row['version'] = (row['version'] as int) + 1;
      return row;
    }
    return super.putJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    await writeGate?.future;
    check(failWrite);
    mutationPaths.add(path);
    if (path.startsWith('/v1/lactation/records/')) {
      final id = path.split('/').last;
      final row = records.singleWhere((r) => r['id'] == id);
      records.remove(row);
      row['version'] = (row['version'] as int) + 1;
      deleted[id] = row;
      return {'id': id, 'version': row['version']};
    }
    return super.deleteJson(path, headers: headers);
  }
}
