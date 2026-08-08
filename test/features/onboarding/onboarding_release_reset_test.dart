import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/core/network/api_json_transport.dart';
import 'package:momcozy_flutter_app/core/update/app_release_lifecycle.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'pending release reset runs before onboarding state is loaded',
    () async {
      final transport = _RecordingTransport(
        {
          onboardingMeEndpoint: const {
            'status': 'required',
            'current_step': 'profile',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: {
          onboardingReleaseResetEndpoint: const {
            'status': 'reset',
            'release_id': '1.0.0+27',
            'deleted_file_count': 0,
            'object_cleanup_queued': false,
          },
        },
      );
      final policy = _FakeReleasePolicy(requiresReset: true);
      final runtimeController = _runtimeController(transport);
      final controller = OnboardingController(
        runtimeController: runtimeController,
        releasePolicy: policy,
      );

      await _waitFor(() => controller.phase == OnboardingGatePhase.ready);

      expect(transport.postPaths, [onboardingReleaseResetEndpoint]);
      expect(transport.getPaths, [onboardingMeEndpoint]);
      expect(transport.postedBodies.single, {'release_id': '1.0.0+27'});
      expect(controller.requiresOnboardingFor('release-user'), isTrue);
      controller.dispose();
      runtimeController.dispose();
    },
  );

  test('cloud reset failure blocks onboarding state and app entry', () async {
    final transport = _RecordingTransport(
      {
        onboardingMeEndpoint: const {
          'status': 'completed',
          'current_step': 'done',
          'profile_confirmed': true,
        },
      },
      writeResponsesByPath: {
        onboardingReleaseResetEndpoint: const {
          'http_status': 500,
          'status_text': 'Internal Server Error',
          'body': {
            'error': {
              'code': 'release_reset_failed',
              'message': 'Reset failed.',
            },
          },
        },
      },
    );
    final runtimeController = _runtimeController(transport);
    final controller = OnboardingController(
      runtimeController: runtimeController,
      releasePolicy: _FakeReleasePolicy(requiresReset: true),
    );

    await _waitFor(() => controller.phase == OnboardingGatePhase.failure);

    expect(transport.postPaths, [onboardingReleaseResetEndpoint]);
    expect(transport.getPaths, isEmpty);
    expect(controller.errorMessage, 'Reset failed.');
    controller.dispose();
    runtimeController.dispose();
  });

  test(
    'completed onboarding marks the current release for that user',
    () async {
      final transport = _RecordingTransport(
        {
          onboardingMeEndpoint: const {
            'status': 'avatar_required',
            'current_step': 'avatar',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_continue_with_default': true,
          },
        },
        writeResponsesByPath: {
          onboardingReleaseResetEndpoint: const {
            'status': 'already_reset',
            'release_id': '1.0.0+27',
            'deleted_file_count': 0,
            'object_cleanup_queued': false,
          },
          '$onboardingMeEndpoint/complete': const {
            'status': 'completed',
            'current_step': 'done',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
          },
        },
      );
      final policy = _FakeReleasePolicy(requiresReset: true);
      final runtimeController = _runtimeController(transport);
      final controller = OnboardingController(
        runtimeController: runtimeController,
        releasePolicy: policy,
      );
      await _waitFor(() => controller.phase == OnboardingGatePhase.ready);

      expect(await controller.completeWithDefaultAvatar(), isTrue);

      expect(policy.completedUsers, ['release-user']);
      expect(await policy.requiresResetFor('release-user'), isFalse);
      controller.dispose();
      runtimeController.dispose();
    },
  );
}

MomCozyRuntimeController _runtimeController(ApiJsonTransport transport) {
  return MomCozyRuntimeController(
    MomCozyApiRuntime(
      jsonTransport: transport,
      multipartTransport: FixtureApiMultipartTransport(const {}),
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'release-user',
        babyId: 'release-baby',
        locale: 'en-US',
        accessToken: 'access',
      ),
    ),
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100 && !predicate(); attempt += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue);
}

class _RecordingTransport extends FixtureApiJsonTransportByPath {
  _RecordingTransport(super.responsesByPath, {super.writeResponsesByPath});

  final List<String> postPaths = [];

  @override
  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) {
    postPaths.add(path);
    return super.postJson(path, body: body, headers: headers);
  }
}

class _FakeReleasePolicy implements OnboardingReleasePolicy {
  _FakeReleasePolicy({required this.requiresReset});

  bool requiresReset;
  final List<String> completedUsers = [];

  @override
  String get releaseId => '1.0.0+27';

  @override
  Future<void> markCompletedFor(String userId) async {
    completedUsers.add(userId);
    requiresReset = false;
  }

  @override
  Future<bool> requiresResetFor(String userId) async => requiresReset;
}
