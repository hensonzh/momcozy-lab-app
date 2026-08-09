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

    expect(find.text('When did you give birth?'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('Delivery date'), findsOneWidget);
    expect(find.text('Pregnancy weeks (optional)'), findsOneWidget);
    expect(
      find.textContaining('time recovery and baby guidance'),
      findsOneWidget,
    );
    expect(find.text('Delivery method (optional)'), findsNothing);
    expect(find.text('How many babies did you welcome?'), findsNothing);

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
    );
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
      'delivery_gestational_age': null,
      'delivery_type': null,
      'infant_count': 1,
      'infants': [
        {'nickname': '', 'sex': null},
      ],
    });

    router.dispose();
    onboardingController.dispose();
    runtimeController.dispose();
  });

  testWidgets('fertility skips empty details and explains photo use', (
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
}
