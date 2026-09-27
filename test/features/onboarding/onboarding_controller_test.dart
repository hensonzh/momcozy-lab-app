import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/domain/onboarding.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  test(
    'new user is gated until profile is saved; infant selection follows',
    () async {
      final transport = FixtureApiJsonTransportByPath(
        const {
          '/v1/onboarding/me': {
            'status': 'required',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: const {
          '/v1/onboarding/me/profile': {
            'status': 'avatar_required',
            'profile_confirmed': true,
            'can_enter_app': false,
            'primary_infant_id': 'baby-1',
          },
        },
      );
      final runtime = _runtime(transport);
      final selected = <String>[];
      final controller = OnboardingController(
        runtimeController: runtime,
        onPrimaryInfantSelected: (id) async => selected.add(id),
      );
      await controller.load();
      expect(controller.requiresOnboardingFor('new-user'), isTrue);
      expect(await controller.confirmProfile(_draft()), isTrue);
      expect(controller.requiresOnboardingFor('new-user'), isFalse);
      expect(selected, ['baby-1']);
      expect(transport.mutationPaths, ['/v1/onboarding/me/profile']);
      controller.dispose();
      runtime.dispose();
    },
  );

  test('rejected save retains required state and draft for retry', () async {
    final transport = FixtureApiJsonTransportByPath(
      const {
        '/v1/onboarding/me': {'status': 'required', 'profile_confirmed': false},
      },
      writeResponsesByPath: const {
        '/v1/onboarding/me/profile': {
          'status': 'required',
          'profile_confirmed': false,
        },
      },
    );
    final runtime = _runtime(transport);
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    expect(await controller.confirmProfile(_draft()), isFalse);
    expect(controller.requiresOnboardingFor('new-user'), isTrue);
    expect(controller.errorMessage, isNotEmpty);
    controller.dispose();
    runtime.dispose();
  });

  test('late save response cannot complete a different account', () async {
    final oldTransport = _DeferredOnboardingTransport();
    final runtime = _runtime(oldTransport);
    final selected = <String>[];
    final controller = OnboardingController(
      runtimeController: runtime,
      onPrimaryInfantSelected: (id) async => selected.add(id),
    );
    await controller.load();
    final pending = Completer<Map<String, Object?>>();
    oldTransport.pendingSave = pending;
    final saving = controller.confirmProfile(_draft());
    await Future<void>.delayed(Duration.zero);

    final newTransport = _DeferredOnboardingTransport();
    runtime.replaceRuntime(
      MomCozyApiRuntime(
        jsonTransport: newTransport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'other-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'other-access',
        ),
      ),
    );
    await controller.load();
    expect(controller.requiresOnboardingFor('other-user'), isTrue);
    pending.complete(const {
      'status': 'completed',
      'profile_confirmed': true,
      'primary_infant_id': 'old-baby',
    });
    expect(await saving, isFalse);
    expect(controller.requiresOnboardingFor('other-user'), isTrue);
    expect(selected, isEmpty);
    controller.dispose();
    runtime.dispose();
  });

  test(
    'late save from a previous login cannot complete a new session',
    () async {
      final oldTransport = _DeferredOnboardingTransport();
      final runtime = _runtime(oldTransport);
      final controller = OnboardingController(runtimeController: runtime);
      await controller.load();
      final pending = Completer<Map<String, Object?>>();
      oldTransport.pendingSave = pending;
      final saving = controller.confirmProfile(_draft());
      await Future<void>.delayed(Duration.zero);

      runtime.replaceRuntime(
        MomCozyApiRuntime(
          jsonTransport: _DeferredOnboardingTransport(),
          session: const MomCozySession(
            status: MomCozySessionStatus.anonymous,
            userId: 'new-user',
            babyId: '',
            locale: 'en-US',
          ),
        ),
      );
      runtime.replaceRuntime(
        MomCozyApiRuntime(
          jsonTransport: _DeferredOnboardingTransport(),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'new-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'new-login',
          ),
        ),
      );
      await controller.load();
      pending.complete(const {
        'status': 'completed',
        'profile_confirmed': true,
      });
      expect(await saving, isFalse);
      expect(controller.requiresOnboardingFor('new-user'), isTrue);
      controller.dispose();
      runtime.dispose();
    },
  );

  test('a late state fetch cannot undo a confirmed profile', () async {
    final transport = _DeferredOnboardingTransport();
    final runtime = _runtime(transport);
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    final pending = Completer<Map<String, Object?>>();
    transport.pendingLoad = pending;
    final staleLoad = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.confirmProfile(_draft()), isTrue);
    pending.complete(const {'status': 'required', 'profile_confirmed': false});
    await staleLoad;
    expect(controller.requiresOnboardingFor('new-user'), isFalse);
    expect(controller.state?.profileConfirmed, isTrue);
    controller.dispose();
    runtime.dispose();
  });

  test('already-confirmed profile passes the onboarding gate', () async {
    final transport = FixtureApiJsonTransportByPath(const {
      '/v1/onboarding/me': {
        'status': 'avatar_generating',
        'profile_confirmed': true,
        'can_enter_app': false,
      },
    });
    final runtime = _runtime(transport);
    final controller = OnboardingController(runtimeController: runtime);
    await controller.load();
    expect(controller.state?.status, OnboardingStatus.completed);
    expect(controller.requiresOnboardingFor('new-user'), isFalse);
    controller.dispose();
    runtime.dispose();
  });
}

OnboardingProfileDraft _draft() => OnboardingProfileDraft(
  displayName: 'Mia',
  age: 32,
  deliveryDate: DateTime(2026, 9, 20),
  deliveryCount: 1,
  gestationWeeks: 39,
  gestationDays: 2,
  feedingMethods: ['direct', 'formula'],
);

MomCozyRuntimeController _runtime(FixtureApiJsonTransportByPath transport) =>
    MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );

class _DeferredOnboardingTransport extends FixtureApiJsonTransportByPath {
  _DeferredOnboardingTransport()
    : super(
        const {
          '/v1/onboarding/me': {
            'status': 'required',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: const {
          '/v1/onboarding/me/profile': {
            'status': 'completed',
            'profile_confirmed': true,
          },
        },
      );

  Completer<Map<String, Object?>>? pendingLoad;
  Completer<Map<String, Object?>>? pendingSave;

  @override
  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?> query = const {},
  }) => pendingLoad?.future ?? super.getJson(path, query: query);

  @override
  Future<Map<String, Object?>> putJson(
    String path, {
    Map<String, Object?> body = const {},
    Map<String, String> headers = const {},
  }) =>
      pendingSave?.future ?? super.putJson(path, body: body, headers: headers);
}
