import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_controller.dart';
import 'package:momcozy_flutter_app/features/onboarding/presentation/onboarding_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import 'fixture_api_transport.dart';

Future<void> verifyOnboardingReading(
  WidgetTester tester, {
  required double scale,
  required Future<void> Function(String) capture,
}) async {
  final runtime = MomCozyRuntimeController(
    MomCozyApiRuntime(
      jsonTransport: FixtureApiJsonTransportByPath(const {
        '/v1/onboarding/me': {'status': 'required', 'profile_confirmed': false},
      }),
      session: const MomCozySession(
        status: MomCozySessionStatus.authenticated,
        userId: 'reading-fixture',
        babyId: '',
        locale: 'en-US',
        accessToken: 'fixture-token',
      ),
    ),
  );
  final controller = OnboardingController(runtimeController: runtime);
  await controller.load();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: momCozyTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: OnboardingPage(
        controller: controller,
        now: () => DateTime(2026, 9, 24),
      ),
    ),
  );
  Future<void> frame() async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> tap(Finder target) async {
    await tester.ensureVisible(target);
    await frame();
    await tester.tap(target);
    await frame();
  }

  try {
    await frame();
    expect(find.text('1/3'), findsOneWidget);
    await capture('basics');
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-display-name')),
      'Mia',
    );
    await tester.enterText(find.byKey(const ValueKey('onboarding-age')), '32');
    await tester.enterText(
      find.byKey(const ValueKey('onboarding-delivery-count')),
      '1',
    );
    await tap(find.widgetWithText(FilledButton, 'Continue'));
    expect(find.text('2/3'), findsOneWidget);
    await capture('delivery');
    await tap(find.text('Choose date'));
    await tap(find.text('OK'));
    await tap(
      find.byKey(const ValueKey('onboarding-postpartum-delivery-continue')),
    );
    expect(find.text('3/3'), findsOneWidget);
    await capture('birth');
  } finally {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    runtime.dispose();
  }
}
