import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:momcozy_flutter_app/app/ibclc/workbench_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_auth_api.dart';
import 'package:momcozy_flutter_app/domain/care/intake.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/services/consultations/intake_codec.dart';
import 'package:momcozy_flutter_app/services/ibclc/workbench_codec.dart';
import 'workbench_auth_test_support.dart';

Map<String, Object?> workbenchFixture(String name) => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/product_baseline/workbench_$name.json',
        ).readAsStringSync(),
      )
      as Map,
);

class TestWorkbenchRepository implements WorkbenchRepository {
  Map<String, Object?> appointmentsJson = workbenchFixture('appointments');
  Map<String, Object?> clientsJson = workbenchFixture('clients');
  Map<String, Object?> clientJson = workbenchFixture('client');
  final appointmentCalls = <({LocalDate? date, int offset})>[];
  final clientCalls =
      <({String query, WorkbenchClientFilter filter, int offset})>[];
  Future<WorkbenchAppointments> Function(LocalDate? date, int offset)?
  onAppointments;
  Future<WorkbenchClients> Function(String query)? onClients;
  @override
  Future<WorkbenchAppointments> appointments({
    LocalDate? date,
    int offset = 0,
    int limit = 10,
  }) async {
    appointmentCalls.add((date: date, offset: offset));
    return onAppointments == null
        ? readWorkbenchAppointments(appointmentsJson)
        : onAppointments!(date, offset);
  }

  @override
  Future<WorkbenchClients> clients({
    String query = '',
    WorkbenchClientFilter filter = WorkbenchClientFilter.all,
    int offset = 0,
    int limit = 20,
  }) async {
    clientCalls.add((query: query, filter: filter, offset: offset));
    return onClients == null
        ? readWorkbenchClients(clientsJson)
        : onClients!(query);
  }

  @override
  Future<WorkbenchClientDetail> client(
    String patientRef, {
    int offset = 0,
    int limit = 20,
  }) async => readWorkbenchClientDetail(clientJson);
  @override
  Future<CareIntake> intake(String appointmentId) async =>
      readIntake(workbenchFixture('intake'));
}

class WorkbenchHttpHarness {
  WorkbenchHttpHarness({bool signedIn = true}) {
    final identity = workbenchFixture('identity');
    tokens = MomCozyAuthTokenResponse(
      accessToken: 'synthetic-access',
      refreshToken: 'synthetic-refresh',
      expiresIn: 900,
      user: MomCozyAuthUser(
        id: readWorkbenchIdentity(identity).provider.id,
        displayName: '',
      ),
    );
    store = TestTokenStore()..saved = signedIn ? tokens : null;
    runtime = WorkbenchRuntime(
      baseUri: Uri.parse('http://localhost:8000'),
      tokenStore: store,
      deviceStore: TestDeviceStore(),
      client: MockClient((request) async {
        requests.add(request);
        Map<String, Object?> value;
        switch (request.url.path) {
          case '/v1/ibclc/auth/login':
            value = {
              'challenge': 'synthetic-challenge',
              'expires_at': '2026-09-08T12:05:00Z',
            };
          case '/v1/ibclc/auth/verify':
            value = {
              'access_token': tokens.accessToken,
              'refresh_token': tokens.refreshToken,
              'expires_in': tokens.expiresIn,
              'token_type': 'Bearer',
              'user': {'id': tokens.user.id},
            };
          case '/v1/ibclc/me':
            value = identity;
          case '/v1/ibclc/appointments':
            value = workbenchFixture('appointments');
          case '/v1/ibclc/calendar':
            final source = workbenchFixture('appointments');
            final selected = LocalDate.parse(
              request.url.queryParameters['date'] ?? source['date']! as String,
            );
            final week = selected.addDays(1 - selected.weekday);
            final hasEvent = week == LocalDate(2026, 9, 7);
            value = {
              ...source,
              'week_start': week.toString(),
              'items': hasEvent ? source['items'] : [],
              'total': hasEvent ? 1 : 0,
              'limit': 100,
            }..remove('date');
          case '/v1/ibclc/clients':
            value = workbenchFixture('clients');
          case '/v1/ibclc/followups':
            value = Map.of(followupsJson);
            final items = List<Map>.from(value['items']! as List);
            final status = request.url.queryParameters['status'];
            final q = request.url.queryParameters['q'] ?? '';
            value['items'] = items
                .where(
                  (item) =>
                      (status == null ||
                          status == 'all' ||
                          item['status'] == status) &&
                      (q.isEmpty || jsonEncode(item).contains(q)),
                )
                .toList();
            value['total'] = (value['items'] as List).length;
          case '/v1/ibclc/reminders':
            value = remindersJson;
          case '/v1/auth/logout':
            value = {'ok': true};
          default:
            final reportClient = workbenchFixture('report_client');
            if (request.url.path ==
                '/v1/ibclc/clients/${(reportClient['client'] as Map)['patient_ref']}') {
              value = reportClient;
            } else if (request.url.path.contains('/ibclc/episodes/') &&
                request.url.path.endsWith('/reports/history')) {
              value = reportHistoryJson;
            } else if (request.url.path.contains('/ibclc/episodes/') &&
                request.url.path.endsWith('/reports')) {
              if (reportsDenied) {
                return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'ai_consent_required',
                      'message': 'AI consent was withdrawn',
                    },
                  }),
                  403,
                );
              }
              value = reportJson;
            } else if (request.url.path.contains('/ibclc/reports/') &&
                request.url.path.endsWith('/reviews') &&
                request.method == 'POST') {
              final body = jsonDecode(request.body) as Map;
              final report = reportJson['report'] as Map;
              final previous = report['review'] as Map?;
              if (body['expected_version'] != (previous?['version'] ?? 0)) {
                return http.Response(
                  jsonEncode({
                    'error': {
                      'code': 'care_report_review_changed',
                      'message': 'Review changed',
                    },
                  }),
                  409,
                );
              }
              report['review'] = {
                'id': '11111111-2222-4333-8444-555555555555',
                'version': (previous?['version'] as int? ?? 0) + 1,
                'decision': body['decision'],
                'feedback': body['feedback'],
                'provider_id': (identity['provider'] as Map)['id'],
                'created_at': reportJson['server_time'],
              };
              final queueItem = (followupsJson['items'] as List).first as Map;
              queueItem['status'] = 'completed';
              ((queueItem['services'] as List).first
                      as Map)['review_decision'] =
                  body['decision'];
              followupsJson['completed_count'] = 1;
              followupsJson['pending_count'] = 0;
              ((reportHistoryJson['items'] as List).first
                      as Map)['review_decision'] =
                  body['decision'];
              value = Map<String, Object?>.from(report);
            } else if (request.url.path.startsWith('/v1/ibclc/reminders/') &&
                request.method == 'PUT') {
              final id = request.url.path.split('/')[4];
              for (final item in remindersJson['items'] as List) {
                if (item['id'] == id && item['read_at'] == null) {
                  item['read_at'] = '2026-09-10T16:01:00Z';
                  remindersJson['unread_count'] =
                      (remindersJson['unread_count'] as int) - 1;
                }
              }
              return http.Response('', 204);
            } else if (request.url.path.endsWith('/intake')) {
              value = workbenchFixture('intake');
            } else if (request.url.path.startsWith('/v1/ibclc/clients/')) {
              value = workbenchFixture('client');
            } else {
              return http.Response(
                jsonEncode({
                  'error': {
                    'code': 'not_found',
                    'message': 'Test path not configured',
                  },
                }),
                404,
              );
            }
        }
        return http.Response(
          jsonEncode(value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  }
  late final MomCozyAuthTokenResponse tokens;
  late final TestTokenStore store;
  late final WorkbenchRuntime runtime;
  final requests = <http.Request>[];
  final followupsJson = workbenchFixture('followups');
  final reportJson = workbenchFixture('report');
  final reportHistoryJson = workbenchFixture('report_history');
  bool reportsDenied = false;
  final remindersJson = workbenchFixture('reminders');
}
