import 'mom_inventory_transport.dart';
import 'consultation_inventory_transport.dart';

/// Isolated HTTP data consumed by the production schedule repository.
class ScheduleInventoryTransport extends ConsultationInventoryTransport {
  final personal = <Map<String, Object?>>[];
  final extraEpisodes = <Map<String, Object?>>[];
  bool showCare = false;
  final queries = <Map<String, Object?>>[];
  final createKeys = <String?>[];

  void seedCare() {
    showCare = true;
    publishSummary();
    for (final task in publication!['tasks'] as List) {
      (task as Map)['scheduled_date'] = '2026-09-13';
    }
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path != '/v1/schedule') return super.getJson(path, query: query);
    getPaths.add(path);
    queries.add(Map.of(query));
    await readGates[path]?.future;
    check(failingReads.contains(path));
    final matching = personal
        .where(
          (row) =>
              row['date'].toString().compareTo(
                    query['start_date'].toString(),
                  ) >=
                  0 &&
              row['date'].toString().compareTo(query['end_date'].toString()) <
                  0,
        )
        .toList();
    final offset = query['offset'] as int? ?? 0;
    final limit = query['limit'] as int? ?? 100;
    return {
      'personal': matching.skip(offset).take(limit).toList(),
      'appointments': showCare ? [appointment] : [],
      'episodes': showCare ? [episode, ...extraEpisodes] : [],
      'plans': showCare
          ? [
              {
                'episode_id': episode!['id'],
                'appointment_id': appointment!['status'] == 'completed'
                    ? appointment!['id']
                    : 'previous-appointment',
                'publication': publication,
              },
            ]
          : [],
      'server_time': inventoryMomNow.toIso8601String(),
      'has_more': matching.length > offset + limit,
    };
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path != '/v1/schedule/personal') {
      return super.postJson(path, body: body, headers: headers);
    }
    createKeys.add(headers['Idempotency-Key']);
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite);
    final row = <String, Object?>{
      ...body,
      'id': 'schedule-${nextId++}',
      'updated_at': inventoryMomNow.toIso8601String(),
    };
    personal.add(row);
    return row;
  }

  @override
  Future<Map<String, Object?>> patchJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/schedule/personal/')) {
      return super.patchJson(path, body: body, headers: headers);
    }
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite);
    final row = personal.singleWhere((r) => r['id'] == path.split('/').last);
    row.addAll({
      ...body,
      'updated_at': inventoryMomNow
          .add(const Duration(seconds: 1))
          .toIso8601String(),
    });
    return row;
  }

  @override
  Future<Map<String, Object?>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    if (!path.startsWith('/v1/schedule/personal/')) {
      return super.deleteJson(path, headers: headers);
    }
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite);
    final id = Uri.parse(path).pathSegments.last;
    personal.removeWhere((row) => row['id'] == id);
    return {};
  }
}
