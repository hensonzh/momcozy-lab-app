import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
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
      find.byKey(const ValueKey('onboarding-stage-fertility')),
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
    final postpartum = find.byKey(
      const ValueKey('onboarding-stage-postpartum'),
    );
    await tester.ensureVisible(postpartum);
    await tester.tap(postpartum);
    await tester.pumpAndSettle();

    expect(find.text('A few basics first'), findsOneWidget);
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
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('Delivery date'), findsOneWidget);
    expect(find.text('Gestational age at delivery'), findsOneWidget);
    expect(find.text('Weeks *'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(
      find.textContaining('personalize your postpartum recovery'),
      findsOneWidget,
    );
    expect(
      find.textContaining('How far along the pregnancy was at delivery'),
      findsOneWidget,
    );
    expect(find.text('Delivery method (optional)'), findsNothing);
    expect(find.text('How many babies did you welcome?'), findsNothing);

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final deliveryContinue = find.byKey(
      const ValueKey('onboarding-postpartum-delivery-continue'),
    );
    await tester.ensureVisible(deliveryContinue);
    await tester.tap(deliveryContinue);
    await tester.pumpAndSettle();

    expect(find.text('Tell us about your delivery'), findsOneWidget);
    expect(
      find.text('Enter how many weeks pregnant you were at delivery.'),
      findsOneWidget,
    );
    expect(find.text('How was your delivery?'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-gestational-weeks')),
      '39',
    );
    await tester.ensureVisible(deliveryContinue);
    await tester.tap(deliveryContinue);
    await tester.pumpAndSettle();

    expect(find.text('How was your delivery?'), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
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
    expect(find.text('5/5'), findsOneWidget);
    expect(transport.lastBody, {
      'stage': 'postpartum',
      'display_name': 'Mia',
      'age': 32,
      'delivery_date': isA<String>(),
      'delivery_gestational_age': {'weeks': 39},
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
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('Create your digital companion'), findsNothing);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('fertility skips empty details and shows photo use inline', (
    tester,
  ) async {
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
          'current_stage': 'fertility',
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
          userId: 'new-fertility-user',
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
    await tester.tap(find.byKey(const ValueKey('onboarding-stage-fertility')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-display-name')),
      'Ava',
    );
    await tester.enterText(find.byKey(const ValueKey('onboarding-age')), '30');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('You’re all set'), findsNothing);
    expect(find.text('Create your digital companion'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(
      find.textContaining('make your companion feel more like you'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Upload a photo'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'How your photo is used'),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('onboarding-photo-privacy-note')),
      findsOneWidget,
    );
    expect(
      find.textContaining('used only to create your avatar'),
      findsOneWidget,
    );
    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('Choose from library'), findsNothing);

    final uploadPhoto = find.widgetWithText(FilledButton, 'Upload a photo');
    await tester.ensureVisible(uploadPhoto);
    await tester.tap(uploadPhoto);
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    expect(find.text('Choose from library'), findsOneWidget);

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('pregnancy path asks only relevant questions and explains why', (
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
          userId: 'new-pregnancy-user',
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
    await tester.tap(find.byKey(const ValueKey('onboarding-stage-pregnancy')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-display-name')),
      'Lina',
    );
    await tester.enterText(find.byKey(const ValueKey('onboarding-age')), '29');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('About your pregnancy'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('Expected due date'), findsOneWidget);
    expect(find.text('Expected babies'), findsOneWidget);
    expect(
      find.textContaining('help us time pregnancy guidance'),
      findsOneWidget,
    );
    expect(find.text('Delivery date'), findsNothing);

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
      final router = createMomCozyRouter(
        runtimeController: runtimeController,
        onboardingController: onboardingController,
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

      final secondCandidate = find.byKey(
        const ValueKey('onboarding-avatar-candidate-2'),
      );
      await tester.ensureVisible(secondCandidate);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(secondCandidate);
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
}
