import '../../core/auth/momcozy_auth_api.dart';
import '../../core/network/api_json_transport.dart';
import '../../domain/ibclc/workbench.dart';
import '../../domain/ibclc/workbench_calendar.dart';
import '../../domain/ibclc/workbench_reminder.dart';
import '../../domain/ibclc/workbench_followup.dart';
import 'followups_codec.dart';
import 'reminders_codec.dart';
import '../../domain/care/intake.dart';
import '../../domain/shared/local_date.dart';
import '../../modules/ibclc/auth/application/auth_gateway.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import '../consultations/intake_codec.dart';
import 'workbench_codec.dart';

class WorkbenchApiRepository
    implements
        WorkbenchRepository,
        WorkbenchCalendarRepository,
        WorkbenchFollowupsRepository,
        WorkbenchRemindersRepository {
  const WorkbenchApiRepository({required this.transport});
  final ApiJsonTransport transport;
  @override
  Future<WorkbenchFollowups> followups({
    String query = '',
    WorkbenchFollowupFilter filter = WorkbenchFollowupFilter.all,
    int offset = 0,
  }) => withProductFailure(
    () async => readFollowups(
      await transport.getJson(
        '/v1/ibclc/followups',
        query: {
          'q': query.trim(),
          'status': followupFilterWire.write(filter),
          'offset': offset,
          'limit': 20,
        },
      ),
    ),
  );
  @override
  Future<WorkbenchReminders> reminders({int offset = 0}) => withProductFailure(
    () async => readReminders(
      await transport.getJson(
        '/v1/ibclc/reminders',
        query: {'offset': offset, 'limit': 20},
      ),
    ),
  );
  @override
  Future<void> readReminder(String eventId) => withProductFailure(() async {
    await (transport as ApiJsonMutationTransport).putJson(
      '/v1/ibclc/reminders/${Uri.encodeComponent(eventId)}/read',
    );
  });
  @override
  Future<WorkbenchCalendar> calendar({LocalDate? date, int offset = 0}) =>
      withProductFailure(
        () async => readWorkbenchCalendar(
          await transport.getJson(
            '/v1/ibclc/calendar',
            query: {'date': date?.toString(), 'offset': offset, 'limit': 100},
          ),
        ),
      );
  @override
  Future<CareIntake> intake(String appointmentId) => withProductFailure(
    () async => readIntake(
      await transport.getJson(
        '/v1/ibclc/appointments/${Uri.encodeComponent(appointmentId)}/intake',
      ),
    ),
  );
  @override
  Future<WorkbenchAppointments> appointments({
    LocalDate? date,
    int offset = 0,
    int limit = 10,
  }) => withProductFailure(
    () async => readWorkbenchAppointments(
      await transport.getJson(
        '/v1/ibclc/appointments',
        query: {'date': date?.toString(), 'offset': offset, 'limit': limit},
      ),
    ),
  );
  @override
  Future<WorkbenchClients> clients({
    String query = '',
    WorkbenchClientFilter filter = WorkbenchClientFilter.all,
    int offset = 0,
    int limit = 20,
  }) => withProductFailure(
    () async => readWorkbenchClients(
      await transport.getJson(
        '/v1/ibclc/clients',
        query: {
          'q': query.trim(),
          'status': workbenchClientFilterWire.write(filter),
          'offset': offset,
          'limit': limit,
        },
      ),
    ),
  );
  @override
  Future<WorkbenchClientDetail> client(
    String patientRef, {
    int offset = 0,
    int limit = 20,
  }) => withProductFailure(
    () async => readWorkbenchClientDetail(
      await transport.getJson(
        '/v1/ibclc/clients/${Uri.encodeComponent(patientRef)}',
        query: {'offset': offset, 'limit': limit},
      ),
    ),
  );
}

class WorkbenchAuthApiGateway implements WorkbenchAuthGateway {
  const WorkbenchAuthApiGateway({
    required this.anonymous,
    required this.authenticated,
  });
  final ApiJsonTransport anonymous, authenticated;
  @override
  Future<WorkbenchLoginChallenge> begin({
    required String email,
    required String password,
    required String deviceId,
  }) => withProductFailure(() async {
    final json = await anonymous.postJson(
      '/v1/ibclc/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'device_id': deviceId,
      },
    );
    return WorkbenchLoginChallenge(
      value: jsonString(json['challenge']),
      expiresAt: jsonInstant(json['expires_at']),
    );
  });
  @override
  Future<MomCozyAuthTokenResponse> verify({
    required String challenge,
    required String code,
  }) => withProductFailure(
    () async => MomCozyAuthTokenResponse.fromMap(
      await anonymous.postJson(
        '/v1/ibclc/auth/verify',
        body: {'challenge': challenge, 'code': code},
      ),
    ),
  );
  @override
  Future<MomCozyAuthTokenResponse> refresh(String refreshToken) =>
      withProductFailure(
        () async => MomCozyAuthTokenResponse.fromMap(
          await anonymous.postJson(
            '/v1/auth/refresh',
            body: {'refresh_token': refreshToken},
          ),
        ),
      );
  @override
  Future<WorkbenchIdentity> identity() => withProductFailure(
    () async =>
        readWorkbenchIdentity(await authenticated.getJson('/v1/ibclc/me')),
  );
  @override
  Future<void> logout(String accessToken) => withProductFailure(() async {
    await anonymous.postJson(
      '/v1/auth/logout',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
  });
}
