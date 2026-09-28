@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('three-step onboarding at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
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
              'http_status': 503,
              'body': {
                'error': {
                  'code': 'unavailable',
                  'message': 'Profile could not be saved. Try again.',
                },
              },
            },
          },
        );
        final runtime = MomCozyRuntimeController(
          MomCozyApiRuntime(
            jsonTransport: transport,
            multipartTransport: FixtureApiMultipartTransport(const {}),
            session: const MomCozySession(
              status: MomCozySessionStatus.authenticated,
              userId: 'visual-user',
              babyId: '',
              locale: 'en-US',
              accessToken: 'access',
            ),
          ),
        );
        final controller = OnboardingController(runtimeController: runtime);
        addTearDown(controller.dispose);
        addTearDown(runtime.dispose);
        await controller.load();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: OnboardingPage(
              controller: controller,
              now: () => DateTime(2026, 9, 24),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String state) async {
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/onboarding-$state-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
            ),
          );
        }

        Future<void> tap(Finder target) async {
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        expect(find.text('1/3'), findsOneWidget);
        await capture('basics');
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
        await tap(find.widgetWithText(FilledButton, 'Continue'));
        expect(find.text('2/3'), findsOneWidget);
        expect(find.text('Tell us about this delivery'), findsOneWidget);
        expect(find.text('Date of this delivery'), findsOneWidget);
        expect(find.text('Gestational weeks at this delivery'), findsOneWidget);
        final weeksField = tester.getRect(
          find.byKey(const ValueKey('onboarding-gestation-weeks')),
        );
        final daysField = tester.getRect(
          find.byKey(const ValueKey('onboarding-gestation-days')),
        );
        expect((weeksField.top - daysField.top).abs(), lessThan(0.5));
        expect((weeksField.bottom - daysField.bottom).abs(), lessThan(0.5));
        await capture('delivery');
        await tap(find.text('Choose date'));
        await tap(find.text('OK'));
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-gestation-weeks')),
          '39',
        );
        await tester.enterText(
          find.byKey(const ValueKey('onboarding-gestation-days')),
          '2',
        );
        await tap(
          find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
        );
        expect(find.text('3/3'), findsOneWidget);
        expect(find.text('How was this delivery?'), findsOneWidget);
        expect(
          find.text('How many babies were born in this delivery?'),
          findsOneWidget,
        );
        expect(find.text('Save and start'), findsOneWidget);
        await capture('birth');
        await tap(find.byKey(const ValueKey('onboarding-feeding-direct')));
        await tap(find.byKey(const ValueKey('onboarding-feeding-formula')));
        await tap(find.byKey(const ValueKey('onboarding-postpartum-save')));
        expect(
          find.text('Profile could not be saved. Try again.'),
          findsOneWidget,
        );
        await capture('birth-error');
        expect(transport.mutationPaths, ['/v1/onboarding/me/profile']);
      });
    }
  }
}
