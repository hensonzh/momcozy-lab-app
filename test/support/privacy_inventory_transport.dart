import 'dart:async';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'notification_inventory_transport.dart';
import 'mom_inventory_transport.dart';

const inventoryConsentPath = '/v1/care/episodes/service-episode/consents';

/// Versioned HTTP fixtures for actual privacy UI and repository flows.
class PrivacyInventoryTransport extends NotificationInventoryTransport {
  PrivacyInventoryTransport() {
    for (final id in ['service-episode', 'other-episode']) {
      byEpisode[id] = {
        for (final scope in [
          'ibclc_case',
          'video',
          'ai_context',
          'notifications',
        ])
          scope: {
            'id': '$id-$scope',
            'episode_id': id,
            'scope': scope,
            'active': true,
            'version': 2,
            'policy_version': '2026-09-08',
            'recorded_at': inventoryMomNow.toIso8601String(),
          },
      };
    }
  }
  final byEpisode = <String, Map<String, Map<String, Object?>>>{};
  final consentWrites = <Map<String, Object?>>[];
  bool emptyEpisodes = false;
  int? writeStatus;
  String? failScope;
  Completer<void>? consentGate;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    if (path.endsWith('/consents')) {
      await readNotification(path);
      return {
        'items': byEpisode[path.split('/')[4]]!.values
            .map((e) => Map<String, Object?>.from(e))
            .toList(),
      };
    }
    final response = await super.getJson(path, query: query);
    if (path == '/v1/care/overview') {
      return {
        ...response,
        'episodes': emptyEpisodes
            ? []
            : [
                episode,
                {
                  ...episode!,
                  'id': 'other-episode',
                  'package_id': 'unlisted-support',
                  'starts_at': null,
                },
              ],
      };
    }
    return response;
  }

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) async {
    if (!path.endsWith('/consents')) {
      return super.postJson(path, body: body, headers: headers);
    }
    final episodeId = path.split('/')[4];
    consentWrites.add({'episode_id': episodeId, ...body});
    mutationPaths.add(path);
    await consentGate?.future;
    if (writeStatus != null &&
        (failScope == null || failScope == body['scope'])) {
      throw ApiHttpException(
        statusCode: writeStatus!,
        statusText: 'Isolated consent response',
        body: {
          'error': {
            'code': writeStatus == 409 ? 'version_conflict' : 'unavailable',
            'message': 'Isolated response',
          },
        },
      );
    }
    final scope = body['scope'] as String;
    final value = {
      ...byEpisode[episodeId]![scope]!,
      'active': body['active'],
      'version': (body['expected_version'] as int) + 1,
    };
    byEpisode[episodeId]![scope] = value;
    return value;
  }
}
