@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/momcozy_test_fonts.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('second delivery asks about previous cesarean at $width/$scale', (
      tester,
    ) async {
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
            'status': 'required',
            'profile_confirmed': false,
          },
        },
      );
      final runtime = MomCozyRuntimeController(
        MomCozyApiRuntime(
          jsonTransport: transport,
          session: const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'second-birth-user',
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
      expect(
        find.text('Including this birth, how many times have you given birth?'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-display-name')),
        'Mia',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-age')),
        '32',
      );
      final countField = find.byKey(
        const ValueKey('onboarding-delivery-count'),
      );
      final continueButton = find.widgetWithText(FilledButton, 'Continue');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(
        find.text('Enter how many times you have given birth (1–20).'),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(countField, '0');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(countField, '21');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      await tester.enterText(countField, '2');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-gestation-weeks')),
        '39',
      );
      await tester.enterText(
        find.byKey(const ValueKey('onboarding-gestation-days')),
        '2',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Before this delivery, had you ever had a cesarean birth?'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-previous-cesarean')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../goldens/design_system/onboarding-birth-repeat-${width.toInt()}${scale == 1 ? '' : '-2x'}.png',
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-previous-cesarean')),
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-previous-cesarean')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes').last);
      await tester.pumpAndSettle();
      for (final method in ['direct', 'formula']) {
        final chip = find.byKey(ValueKey('onboarding-feeding-$method'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.tap(
        find.byKey(const ValueKey('onboarding-postpartum-save')),
      );
      await tester.pumpAndSettle();
      expect(transport.lastBody?['delivery_count'], 2);
      expect(transport.lastBody?['has_cesarean_history'], true);
      expect(transport.lastBody?['gestation_weeks'], 39);
      expect(transport.lastBody?['gestation_days'], 2);
      expect(transport.lastBody?['feeding_methods'], ['direct', 'formula']);
    });
  }
}
