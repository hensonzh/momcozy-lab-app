import '../../core/network/api_json_transport.dart';
import '../../domain/care/intake.dart';
import '../shared/json_value.dart';
import '../shared/product_failure_mapper.dart';
import 'intake_codec.dart';

class IntakeApiRepository implements IntakeRepository {
  const IntakeApiRepository({required this.transport});
  final ApiJsonTransport transport;
  String _path(String id) =>
      '/v1/care/appointments/${Uri.encodeComponent(id)}/intake';
  String _consents(String id) =>
      '/v1/care/episodes/${Uri.encodeComponent(id)}/consents';
  @override
  Future<IntakeContext> load(String appointmentId) => withProductFailure(
    () async =>
        readIntakeContext(await transport.getJson(_path(appointmentId))),
  );
  @override
  Future<CareIntake> save(
    String appointmentId, {
    required IntakeContent content,
    required int expectedVersion,
    required int expectedConsentVersion,
    required String policyVersion,
  }) => withProductFailure(
    () async => readIntake(
      await (transport as ApiJsonMutationTransport).putJson(
        _path(appointmentId),
        body: {
          ...writeIntakeContent(content),
          'expected_version': expectedVersion,
          'expected_consent_version': expectedConsentVersion,
          'consent_to_share': true,
          'consent_policy_version': policyVersion,
        },
      ),
    ),
  );
  @override
  Future<List<CareConsent>> consents(String episodeId) => withProductFailure(
    () async => jsonList(
      (await transport.getJson(_consents(episodeId)))['items'],
      readCareConsent,
    ),
  );
  @override
  Future<CareConsent> setConsent(
    String episodeId, {
    required CareConsentScope scope,
    required bool active,
    required int expectedVersion,
    required String policyVersion,
  }) => withProductFailure(
    () async => readCareConsent(
      await transport.postJson(
        _consents(episodeId),
        body: {
          'scope': careConsentScopeWire.write(scope),
          'active': active,
          'expected_version': expectedVersion,
          'policy_version': policyVersion,
        },
      ),
    ),
  );
}
