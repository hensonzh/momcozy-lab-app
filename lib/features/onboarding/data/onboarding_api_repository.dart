import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';

const onboardingMeEndpoint = '/v1/onboarding/me';

class OnboardingApiRepository {
  const OnboardingApiRepository({
    required this.transport,
    required this.multipartTransport,
  });

  final ApiJsonTransport transport;
  final ApiMultipartTransport multipartTransport;

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

  Future<String> uploadPortrait(OnboardingPortrait portrait) async {
    final response = await multipartTransport.uploadMultipart(
      '$onboardingMeEndpoint/portrait',
      file: ApiUploadFile(
        name: portrait.name,
        mimeType: portrait.mimeType,
        sizeBytes: portrait.bytes.length,
        bytes: portrait.bytes,
      ),
    );
    final id = response['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Portrait upload response has no file id.');
    }
    return id.trim();
  }

  Future<OnboardingState> generateAvatar(String portraitFileId) async {
    return OnboardingState.fromMap(
      await transport.postJson(
        '$onboardingMeEndpoint/avatar-generations',
        body: {'portrait_file_id': portraitFileId},
      ),
    );
  }

  Future<OnboardingState> completeWithAvatar(String generationId) async {
    return _complete({
      'avatar_generation_id': generationId,
      'use_default_avatar': false,
    });
  }

  Future<OnboardingState> completeWithDefault() async {
    return _complete(const {
      'avatar_generation_id': null,
      'use_default_avatar': true,
    });
  }

  Future<OnboardingState> _complete(Map<String, Object?> body) async {
    return OnboardingState.fromMap(
      await transport.postJson('$onboardingMeEndpoint/complete', body: body),
    );
  }
}
