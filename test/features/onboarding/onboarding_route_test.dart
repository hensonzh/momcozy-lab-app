import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/data/onboarding_api_repository.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/avatar_task_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('authenticated new user is redirected outside the app shell', (
    tester,
  ) async {
    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const {
          'status': 'required',
          'current_step': 'profile',
          'profile_confirmed': false,
        }),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final router = createMomCozyRouter(
      runtimeController: runtimeController,
      onboardingController: onboardingController,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onboarding-display-name')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('postpartum path collects delivery and one shared infant set', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final transport = FixtureApiJsonTransportByPath(
      const {
        '/v1/onboarding/me': {
          'status': 'required',
          'current_step': 'profile',
          'profile_confirmed': false,
        },
      },
      writeResponsesByPath: const {
        '/v1/onboarding/me/profile': {
          'status': 'avatar_required',
          'current_step': 'avatar',
          'profile_confirmed': true,
          'current_stage': 'postpartum',
          'can_continue_with_default': true,
        },
      },
    );
    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'new-postpartum-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final router = createMomCozyRouter(
      runtimeController: runtimeController,
      onboardingController: onboardingController,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pumpAndSettle();

    expect(find.text('A few basics first'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(
      find.textContaining('age helps us tailor guidance safely'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-display-name')),
      'Mia',
    );
    await tester.enterText(find.byKey(const ValueKey('onboarding-age')), '32');
    final basicsContinue = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(basicsContinue);
    await tester.tap(basicsContinue);
    await tester.pumpAndSettle();

    expect(find.text('Tell us about your delivery'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('Delivery date'), findsOneWidget);
    expect(
      find.textContaining('personalize postpartum recovery'),
      findsOneWidget,
    );
    expect(find.text('Delivery method (optional)'), findsNothing);
    expect(find.text('How many babies did you welcome?'), findsNothing);

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    final deliveryContinue = find.byKey(
      const ValueKey('onboarding-postpartum-delivery-continue'),
    );
    await tester.ensureVisible(deliveryContinue);
    await tester.tap(deliveryContinue);
    await tester.pumpAndSettle();

    expect(find.text('How was your delivery?'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('Delivery method (optional)'), findsOneWidget);
    expect(find.text('How many babies did you welcome?'), findsOneWidget);
    expect(find.text('Baby 1'), findsNothing);
    expect(find.textContaining('Nickname'), findsNothing);
    expect(find.textContaining('Sex'), findsNothing);
    expect(
      find.textContaining('create the right baby profiles'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-postpartum-save')));
    await tester.pumpAndSettle();

    expect(find.text('Create your digital companion'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
    expect(transport.lastBody, {
      'stage': 'postpartum',
      'display_name': 'Mia',
      'age': 32,
      'delivery_date': isA<String>(),
      'delivery_type': null,
      'infant_count': 1,
      'infants': [
        {'nickname': '', 'sex': null},
      ],
    });

    final avatarBack = find.byKey(const ValueKey('onboarding-avatar-back'));
    expect(avatarBack, findsOneWidget);
    await tester.tap(avatarBack);
    await tester.pumpAndSettle();

    expect(find.text('How was your delivery?'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('Create your digital companion'), findsNothing);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets(
    'avatar generation wait explains queued work on a narrow accessible layout',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport(const {
            'status': 'avatar_generating',
            'current_step': 'generating',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_enter_app': true,
            'avatar_setup_completed': false,
            'can_continue_with_default': true,
            'avatar': {
              'id': 'generation-queued',
              'stage': 'postpartum',
              'status': 'queued',
              'error_code': '',
              'created_at': '2026-08-09T00:00:00Z',
              'candidates': <Object?>[],
            },
          }),
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'avatar-generating-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'access',
          ),
        ),
      );
      final onboardingController = OnboardingController(
        runtimeController: runtimeController,
      );
      await onboardingController.load();
      final router = createMomCozyRouter(
        initialLocation: '/onboarding',
        runtimeController: runtimeController,
        onboardingController: onboardingController,
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, runtimeController: runtimeController),
      );
      await tester.pump();

      expect(find.text('Your four options are on the way'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('onboarding-avatar-generation-recipe')),
        findsOneWidget,
      );
      expect(find.text('Your photo'), findsOneWidget);
      expect(find.text('MomCozy style'), findsOneWidget);
      expect(find.text('4 options'), findsOneWidget);
      expect(find.text('Photo uploaded'), findsOneWidget);
      expect(find.text('Waiting to start'), findsOneWidget);
      expect(find.text('Choose your favorite'), findsOneWidget);
      expect(find.text('Creating four companions…'), findsNothing);

      final waitNote = find.byKey(
        const ValueKey('onboarding-avatar-generation-wait-note'),
      );
      await tester.ensureVisible(waitNote);
      await tester.pump();
      expect(
        find.textContaining('generation continues in the cloud'),
        findsOneWidget,
      );

      router.dispose();
      onboardingController.dispose();
      runtimeController.dispose();
    },
  );

  testWidgets(
    'avatar review offers four generated choices and MomCozy original',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      const candidateIds = [
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000003',
        '00000000-0000-4000-8000-000000000004',
      ];
      final runtimeController = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport({
            'status': 'avatar_review',
            'current_step': 'review',
            'current_stage': 'postpartum',
            'profile_confirmed': true,
            'can_enter_app': true,
            'avatar_setup_completed': false,
            'can_continue_with_default': true,
            'avatar': {
              'id': 'generation-id',
              'stage': 'postpartum',
              'status': 'succeeded',
              'error_code': '',
              'created_at': '2026-08-09T00:00:00Z',
              'candidates': [
                {
                  'id': 'candidate-1',
                  'file_id': candidateIds[0],
                  'position': 1,
                },
                {
                  'id': 'candidate-2',
                  'file_id': candidateIds[1],
                  'position': 2,
                },
                {
                  'id': 'candidate-3',
                  'file_id': candidateIds[2],
                  'position': 3,
                },
                {
                  'id': 'candidate-4',
                  'file_id': candidateIds[3],
                  'position': 4,
                },
              ],
            },
          }),
          multipartTransport: FixtureApiMultipartTransport(const {}),
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'avatar-review-user',
            babyId: '',
            locale: 'en-US',
            accessToken: 'access',
          ),
        ),
      );
      final onboardingController = OnboardingController(
        runtimeController: runtimeController,
      );
      await onboardingController.load();
      var firstCandidateAttempts = 0;
      final router = createMomCozyRouter(
        initialLocation: '/onboarding',
        runtimeController: runtimeController,
        onboardingController: onboardingController,
        avatarThumbnailLoader: (fileId) async {
          if (fileId == candidateIds.first && firstCandidateAttempts++ == 0) {
            throw StateError('thumbnail temporarily unavailable');
          }
          return _onePixelPng;
        },
      );

      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, runtimeController: runtimeController),
      );
      await tester.pump();

      expect(find.text('Choose your companion'), findsOneWidget);
      for (var index = 1; index <= 4; index += 1) {
        expect(
          find.byKey(ValueKey('onboarding-avatar-candidate-$index')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('onboarding-avatar-default')),
        findsOneWidget,
      );
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue with this avatar'),
      );
      expect(confirm.onPressed, isNull);

      final firstCandidate = find.byKey(
        const ValueKey('onboarding-avatar-candidate-1'),
      );
      await tester.ensureVisible(firstCandidate);
      await tester.tap(firstCandidate);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Continue with this avatar'),
            )
            .onPressed,
        isNull,
      );
      final retryImage = find.byKey(
        ValueKey('onboarding-avatar-image-retry-${candidateIds.first}'),
      );
      expect(retryImage, findsOneWidget);
      await tester.tap(retryImage);
      await tester.pumpAndSettle();
      await tester.tap(firstCandidate);
      await tester.pump();
      final enabledConfirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continue with this avatar'),
      );
      expect(enabledConfirm.onPressed, isNotNull);

      router.dispose();
      onboardingController.dispose();
      runtimeController.dispose();
    },
  );

  testWidgets('app shell shows a restorable avatar task and opens review', (
    tester,
  ) async {
    final responses = <String, Map<String, Object?>>{
      onboardingMeEndpoint: _shellGeneratingState,
    };
    final transport = FixtureApiJsonTransportByPath(
      responses,
      writeResponsesByPath: {
        '$onboardingMeEndpoint/complete': _shellCompletedState,
      },
    );
    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: transport,
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'shell-avatar-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final taskController = AvatarTaskController(
      onboardingController: onboardingController,
      pollInterval: const Duration(days: 1),
      completionDisplayDuration: const Duration(minutes: 1),
    );
    final router = createMomCozyRouter(
      initialLocation: '/',
      runtimeController: runtimeController,
      onboardingController: onboardingController,
      avatarTaskController: taskController,
      avatarThumbnailLoader: (_) async => _onePixelPng,
      agentHubBuilder: (context, uri, extra) =>
          const Center(child: Text('App content')),
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('App content'), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-task-banner')), findsOneWidget);
    expect(find.text('Creating your digital companion'), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('avatar-task-banner')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('App content'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-avatar-generation-waiting')),
      findsNothing,
    );

    responses[onboardingMeEndpoint] = _shellReviewState;
    await taskController.refresh();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Your 4 companion options are ready'), findsOneWidget);
    expect(find.text('Tap to choose your favorite'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('avatar-task-banner')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Choose your companion'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-avatar-back')),
      findsOneWidget,
    );
    expect(find.text('5/5'), findsNothing);
    expect(find.byKey(const ValueKey('bottom-nav-me')), findsNothing);

    final firstCandidate = find.byKey(
      const ValueKey('onboarding-avatar-candidate-1'),
    );
    await tester.ensureVisible(firstCandidate);
    await tester.tap(firstCandidate);
    await tester.pump();
    final confirm = find.widgetWithText(
      FilledButton,
      'Continue with this avatar',
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('avatar-activation-success')),
      findsOneWidget,
    );
    expect(find.text('Create your digital companion'), findsNothing);

    await tester.pumpAndSettle();

    expect(find.text('App content'), findsOneWidget);
    expect(find.text('Your digital companion is set'), findsOneWidget);

    router.dispose();
    taskController.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('completed user can open a fresh avatar creation flow', (
    tester,
  ) async {
    final runtimeController = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(_completedAvatarState),
        multipartTransport: FixtureApiMultipartTransport(const {}),
        session: const MomCozySession(
          status: MomCozySessionStatus.authenticated,
          userId: 'avatar-replacement-user',
          babyId: '',
          locale: 'en-US',
          accessToken: 'access',
        ),
      ),
    );
    final onboardingController = OnboardingController(
      runtimeController: runtimeController,
    );
    await onboardingController.load();
    final router = createMomCozyRouter(
      initialLocation: '/avatar/create?from=/me',
      runtimeController: runtimeController,
      onboardingController: onboardingController,
    );

    await tester.pumpWidget(
      MomCozyFlutterApp(router: router, runtimeController: runtimeController),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create a new digital companion'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upload a photo'), findsOneWidget);
    expect(find.text('Use the MomCozy character for now'), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding-avatar-back')),
      findsOneWidget,
    );

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });
}

const _completedAvatarState = <String, Object?>{
  'status': 'completed',
  'current_step': 'done',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': true,
  'active_avatar_file_id': '00000000-0000-4000-8000-000000000001',
};

const _shellGeneratingState = <String, Object?>{
  'status': 'avatar_generating',
  'current_step': 'generating',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': false,
  'avatar': {
    'id': 'shell-generation',
    'stage': 'postpartum',
    'status': 'generating',
    'error_code': '',
    'created_at': '2026-08-09T00:00:00Z',
    'candidates': <Object?>[],
  },
};

const _shellReviewState = <String, Object?>{
  'status': 'avatar_review',
  'current_step': 'review',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': false,
  'can_continue_with_default': true,
  'avatar': {
    'id': 'shell-generation',
    'stage': 'postpartum',
    'status': 'succeeded',
    'error_code': '',
    'created_at': '2026-08-09T00:00:00Z',
    'candidates': [
      {
        'id': 'candidate-1',
        'file_id': '00000000-0000-4000-8000-000000000001',
        'position': 1,
      },
      {
        'id': 'candidate-2',
        'file_id': '00000000-0000-4000-8000-000000000002',
        'position': 2,
      },
      {
        'id': 'candidate-3',
        'file_id': '00000000-0000-4000-8000-000000000003',
        'position': 3,
      },
      {
        'id': 'candidate-4',
        'file_id': '00000000-0000-4000-8000-000000000004',
        'position': 4,
      },
    ],
  },
};

const _shellCompletedState = <String, Object?>{
  'status': 'completed',
  'current_step': 'done',
  'current_stage': 'postpartum',
  'profile_confirmed': true,
  'can_enter_app': true,
  'avatar_setup_completed': true,
  'selected_avatar_file_id': '00000000-0000-4000-8000-000000000001',
};

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
