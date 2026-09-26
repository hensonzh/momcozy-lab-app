import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

const onboardingMeEndpoint = '/v1/onboarding/me';
const onboardingReleaseResetEndpoint = '$onboardingMeEndpoint/release-reset';

class OnboardingApiRepository {
  const OnboardingApiRepository({required this.transport});

  final ApiJsonTransport transport;

  Future<OnboardingReleaseReset> resetForRelease(String releaseId) async {
    final normalizedReleaseId = releaseId.trim();
    if (normalizedReleaseId.isEmpty) {
      throw ArgumentError.value(releaseId, 'releaseId', 'must not be empty');
    }
    final result = OnboardingReleaseReset.fromMap(
      await transport.postJson(
        onboardingReleaseResetEndpoint,
        body: {'release_id': normalizedReleaseId},
      ),
    );
    if (result.releaseId != normalizedReleaseId) {
      throw const FormatException(
        'Onboarding release reset response does not match this app release.',
      );
    }
    return result;
  }

  Future<OnboardingState> fetchState() async {
    return OnboardingState.fromMap(
      await transport.getJson(onboardingMeEndpoint),
    );
  }

  Future<OnboardingState> confirmProfile(OnboardingProfileDraft draft) async {
    final mutation = transport;
    if (mutation is! ApiJsonMutationTransport) {
      throw StateError('Onboarding profile mutation is not configured.');
    }
    return OnboardingState.fromMap(
      await (mutation as ApiJsonMutationTransport).putJson(
        '$onboardingMeEndpoint/profile',
        body: draft.toMap(),
      ),
    );
  }
}
