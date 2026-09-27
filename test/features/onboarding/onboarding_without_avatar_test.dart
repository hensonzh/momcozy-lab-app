import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets(
    'saving the third setup step enters the app without avatar work',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transport = FixtureApiJsonTransportByPath(
        const {
          '/v1/onboarding/me': {
            'status': 'required',
            'profile_confirmed': false,
          },
        },
        writeResponsesByPath: const {
          '/v1/onboarding/me/profile': {
            'status': 'avatar_required', // A previously deployed response.
            'profile_confirmed': true,
            'can_enter_app': false,
            'primary_infant_id': 'baby-1',
          },
        },
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
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
      final onboarding = OnboardingController(runtimeController: runtime);
      await onboarding.load();
      final router = createMomCozyRouter(
        runtimeController: runtime,
        onboardingController: onboarding,
        initialLocation: '/onboarding',
      );
      addTearDown(() {
        router.dispose();
        onboarding.dispose();
        runtime.dispose();
      });
      await tester.pumpWidget(
        MomCozyFlutterApp(router: router, runtimeController: runtime),
      );
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-display-name')),
        'M' * 121,
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-age')),
        '32',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-delivery-count')),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Name must be 120 characters or fewer.'),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      expect(transport.mutationPaths, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-display-name')),
        'Mia',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-age')),
        '32',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-delivery-count')),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter gestational age at delivery'),
        findsOneWidget,
      );
      expect(find.text('2/3'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-gestation-weeks')),
        '39',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-gestation-days')),
        '2',
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
      );
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text('Save and start'), findsOneWidget);
      expect(
        find.text('Before this delivery, had you ever had a cesarean birth?'),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your current feeding methods.'), findsOneWidget);
      expect(transport.mutationPaths, isEmpty);
      final unsure = find.byKey(const ValueKey('onboarding-feeding-unknown'));
      await tester.ensureVisible(unsure);
      await tester.tap(unsure);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(unsure).selected, isTrue);
      for (final method in ['direct', 'formula']) {
        final chip = find.byKey(ValueKey('onboarding-feeding-$method'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<FilterChip>(unsure).selected, isFalse);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('onboarding-feeding-direct')),
            )
            .selected,
        isTrue,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/me');
      expect(transport.mutationPaths, ['/v1/onboarding/me/profile']);
      expect(transport.lastBody?['delivery_count'], 1);
      expect(transport.lastBody?['has_cesarean_history'], false);
      expect(transport.lastBody?['gestation_weeks'], 39);
      expect(transport.lastBody?['gestation_days'], 2);
      expect(transport.lastBody?['feeding_methods'], ['direct', 'formula']);
      expect(find.text('Create your digital companion'), findsNothing);
    },
  );
}
