import 'dart:convert';
import 'dart:io';
import 'mom_inventory_transport.dart';
import 'service_inventory_transport.dart';

/// Isolated HTTP responses for the real user consultation routes. The native
/// device boundary is separate; no expert, room server or payment is contacted.
class ConsultationInventoryTransport extends ServiceInventoryTransport {
  ConsultationInventoryTransport() {
    ownPlan();
    final start = inventoryMomNow.add(const Duration(minutes: 5));
    appointment = {
      'id': 'service-appointment',
      'episode_id': 'service-episode',
      'provider_id': provider['user_id'],
      'provider_name': provider['display_name'],
      'starts_at': start.toIso8601String(),
      'ends_at': start.add(const Duration(hours: 1)).toIso8601String(),
      'timezone': 'America/Los_Angeles',
      'region': 'CA',
      'status': 'confirmed',
      'version': 2,
      'intake_version': 1,
      'confirmed_at': inventoryMomNow.toIso8601String(),
      'hold_expires_at': inventoryMomNow.toIso8601String(),
      'cancelled_at': null,
    };
    intake = {
      'id': 'service-intake',
      'appointment_id': appointment!['id'],
      'episode_id': episode!['id'],
      'version': 1,
      'submitted_at': inventoryMomNow.toIso8601String(),
      'symptoms': ['pumping_schedule'],
      'feeding_goal': 'Isolated inventory consultation',
      'support_needed': '',
      'profile': {
        'baby_id': 'inventory-baby',
        'baby_name': 'Test baby',
        'baby_birth_date': '2026-08-18',
        'baby_sex': 'female',
        'feeding_mode': 'mixed_feeding',
        'delivery_date': '2026-08-18',
        'region': 'CA',
      },
    };
    consents.add({
      'id': 'service-case-consent',
      'episode_id': episode!['id'],
      'scope': 'ibclc_case',
      'active': true,
      'version': 1,
      'policy_version': '2026-09-08',
      'recorded_at': inventoryMomNow.toIso8601String(),
    });
    roomData =
        Map<String, Object?>.from(
            jsonDecode(
                  File(
                    'test/fixtures/product_baseline/room_context.json',
                  ).readAsStringSync(),
                )
                as Map,
          )
          ..['appointment'] = appointment
          ..['opens_at'] = inventoryMomNow
              .subtract(const Duration(minutes: 5))
              .toIso8601String()
          ..['closes_at'] = inventoryMomNow
              .add(const Duration(minutes: 80))
              .toIso8601String()
          ..['server_time'] = inventoryMomNow.toIso8601String();
  }

  late final Map<String, Object?> roomData;
  int connectionNumber = 0;
  Map<String, Object?>? publication;

  void publishSummary() {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/product_baseline/patient_care_summary.json',
              ).readAsStringSync(),
            )
            as Map;
    publication = Map<String, Object?>.from(fixture['publication'] as Map)
      ..['id'] = 'inventory-publication'
      ..['consultation_id'] = 'inventory-room'
      ..['published_at'] = inventoryMomNow.toIso8601String();
  }

  void consultation({
    String status = 'waiting_room',
    String roomStatus = 'ready',
    String? endReason,
  }) {
    final previous = roomData['consultation'] as Map?;
    if (status == 'in_progress') {
      appointment!['status'] = 'in_progress';
      appointment!['version'] = (appointment!['version'] as int) + 1;
      roomData['participants'] = [
        ...((roomData['participants'] as List).where(
          (p) => (p as Map)['role'] != 'ibclc',
        )),
        {
          'role': 'ibclc',
          'presence': 'joined',
          'connection_version': 1,
          'joined_at': roomData['server_time'],
          'last_seen_at': roomData['server_time'],
        },
      ];
    }
    // Mirror room_service.end: every terminal reason completes the appointment;
    // only a completed consultation consumes a session.
    if (endReason != null) {
      appointment!['status'] = 'completed';
      appointment!['version'] = (appointment!['version'] as int) + 1;
      if (endReason == 'completed') {
        episode!['remaining_sessions'] =
            (episode!['remaining_sessions'] as int) - 1;
      }
    }
    roomData['consultation'] = {
      'id': 'inventory-room',
      'appointment_id': appointment!['id'],
      'episode_id': episode!['id'],
      'version': (previous?['version'] as int? ?? 0) + 1,
      'status': status,
      'room_status': roomStatus,
      'video_provider': 'sandbox',
      'started_at': status == 'in_progress'
          ? roomData['server_time']
          : previous?['started_at'],
      'ended_at': endReason == null ? null : roomData['server_time'],
      'end_reason': endReason,
    };
  }

  Future<void> _read(String path) async {
    await readGates[path]?.future;
    check(failingReads.contains(path));
    getPaths.add(path);
  }

  Future<void> _write(
    String path,
    Map<String, Object?> body,
    Map<String, String> headers,
  ) async {
    requests.add({
      'path': path,
      'body': Map<String, Object?>.from(body),
      'headers': Map<String, String>.from(headers),
    });
    mutationPaths.add(path);
    await writeGate?.future;
    check(failWrite || failingWrites.contains(path));
  }

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.endsWith('/room')) {
      await _read(path);
      return roomData;
    }
    if (path.endsWith('/consents')) {
      await _read(path);
      return {'items': consents};
    }
    if (path.endsWith('/summary')) {
      await _read(path);
      return {
        'episode': episode,
        'appointment': appointment,
        'consultation': roomData['consultation'],
        'publication': publication,
      };
    }
    return super.getJson(path, query: query);
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.endsWith('/location-check')) {
      await _write(path, body, headers);
      final location = {
        'id': 'inventory-location',
        'region': body['region'],
        'decision': body['region'] == 'CA' ? 'passed' : 'blocked',
        'created_at': inventoryMomNow.toIso8601String(),
        'expires_at': inventoryMomNow
            .add(const Duration(minutes: 30))
            .toIso8601String(),
      };
      roomData['location'] = location;
      return location;
    }
    if (path.endsWith('/consents')) {
      await _write(path, body, headers);
      final value = {
        'id': 'inventory-video-consent',
        'episode_id': episode!['id'],
        'scope': body['scope'],
        'active': body['active'],
        'version': (body['expected_version'] as int) + 1,
        'policy_version': body['policy_version'],
        'recorded_at': inventoryMomNow.toIso8601String(),
      };
      consents.removeWhere((c) => c['scope'] == body['scope']);
      consents.add(value);
      if (body['scope'] == 'video') roomData['video_consent'] = body['active'];
      return value;
    }
    if (path.endsWith('/room')) {
      await _write(path, body, headers);
      consultation();
      return roomData;
    }
    if (path.endsWith('/room/join')) {
      await _write(path, body, headers);
      return {
        'context': roomData,
        'connection_id': 'inventory-connection-${++connectionNumber}',
        'credentials': null,
      };
    }
    return super.postJson(path, body: body, headers: headers);
  }

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (path.endsWith('/room/presence')) {
      await _write(path, body, headers);
      roomData['participants'] = [
        ...((roomData['participants'] as List).where(
          (p) => (p as Map)['role'] != 'mom',
        )),
        {
          'role': 'mom',
          'presence': body['presence'],
          'connection_version': connectionNumber,
          'joined_at': inventoryMomNow.toIso8601String(),
          'last_seen_at': inventoryMomNow.toIso8601String(),
        },
      ];
      return roomData;
    }
    if (path.startsWith('/v1/care/plan-publications/')) {
      await _write(path, body, headers);
      final task = (publication!['tasks'] as List).cast<Map>().singleWhere(
        (t) => t['source_key'] == path.split('/').last,
      );
      task['status'] = body['status'];
      task['progress_version'] = (task['progress_version'] as int) + 1;
      return publication!;
    }
    return super.putJson(path, body: body, headers: headers);
  }
}
