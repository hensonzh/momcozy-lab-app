import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/fixture_api_transport.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  Future<void> mount(
    WidgetTester tester,
    Size viewport, {
    TextScaler? textScaler,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runtime = MomCozyRuntimeController(
      MomCozyApiRuntime(
        jsonTransport: FixtureApiJsonTransport(const <String, dynamic>{}),
      ),
    );
    addTearDown(runtime.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: MomCozyAuthPage(
          runtimeController: runtime,
          sessionStore: MemoryMomCozySessionStore(),
          internalInviteOnly: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login default follows the approved 393x844 Figma frame', (
    tester,
  ) async {
    await mount(tester, const Size(393, 844));

    expect(find.byKey(const ValueKey('auth-brand-panel')), findsNothing);
    expect(find.byKey(const ValueKey('auth-brand-illustration')), findsNothing);
    expect(find.byKey(const ValueKey('auth-google-button')), findsNothing);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('OR'), findsNothing);

    final title = find.byKey(const ValueKey('auth-login-title'));
    expect(tester.widget<Text>(title).data, 'Momcozy');
    expect(tester.widget<Text>(title).style?.fontFamily, 'LibreCaslonDisplay');
    expect(tester.widget<Text>(title).style?.fontSize, 48);
    expect(tester.widget<Text>(title).style?.color, const Color(0xffb54f78));
    expect(
      find.text('Care and support, every step of the way.'),
      findsOneWidget,
    );
    expect(tester.getTopLeft(title).dy, closeTo(98, 4));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth-email-field'))).dy,
      closeTo(246, 5),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth-password-field'))).dy,
      closeTo(326, 5),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('auth-submit-button'))).dy,
      closeTo(478, 8),
    );
    final signup = find.text('Sign up now');
    expect(tester.getTopLeft(signup).dy, closeTo(618, 12));
    expect(signup, findsOneWidget);
    expect(find.byKey(const ValueKey('auth-remember-me')), findsNothing);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../design-contract/login/comparisons/actual/flutter-login-approved-393x844.png',
      ),
    );
  });

  testWidgets('login remains operable with keyboard open', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await mount(tester, const Size(393, 844));
    await tester.enterText(
      find.byKey(const ValueKey('auth-email-field')),
      'mia@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password-field')),
      'secret123',
    );
    for (final key in ['auth-submit-button', 'auth-register-button']) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legal links and language fit on standard login without scrolling',
    (tester) async {
      await mount(tester, const Size(393, 844));
      expect(
        find.byKey(const ValueKey('auth-resume-verification')),
        findsNothing,
      );
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth-language-button')),
        findsOneWidget,
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent,
        0,
      );
      expect(
        tester
            .getBottomRight(find.byKey(const ValueKey('auth-language-button')))
            .dy,
        lessThanOrEqualTo(844),
      );
    },
  );

  testWidgets(
    'registration shows an unclipped email label and clear legal notice',
    (tester) async {
      await mount(tester, const Size(393, 844));
      await tester.tap(find.byKey(const ValueKey('auth-register-button')));
      await tester.pumpAndSettle();

      final label = find.text('Email address');
      expect(label, findsOneWidget);
      expect(find.text('Continue email verification'), findsNothing);
      expect(find.text('By continuing, you agree to our'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text(' · Read our '), findsOneWidget);
      expect(find.text('Privacy Policy.'), findsOneWidget);
      expect(
        tester
            .widgetList<Material>(
              find.ancestor(of: label, matching: find.byType(Material)),
            )
            .where((material) => material.clipBehavior != Clip.none),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login wordmark stays on one line at 320px with 2x text', (
    tester,
  ) async {
    await mount(
      tester,
      const Size(320, 844),
      textScaler: const TextScaler.linear(2),
    );

    final title = find.byKey(const ValueKey('auth-login-title'));
    expect(tester.getSize(title).height, lessThan(72));
    expect(tester.getRect(title).left, greaterThanOrEqualTo(24));
    expect(tester.getRect(title).right, lessThanOrEqualTo(296));
    expect(find.text('Save password'), findsNothing);
    expect(find.byKey(const ValueKey('auth-forgot-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/design_system/auth-login-wordmark-320-2x.png',
      ),
    );
  });

  testWidgets('narrow login retains all actions by scrolling', (tester) async {
    await mount(tester, const Size(320, 700));
    expect(find.byKey(const ValueKey('auth-google-button')), findsNothing);
    for (final key in [
      'auth-email-field',
      'auth-password-field',
      'auth-submit-button',
      'auth-register-button',
      'auth-language-button',
    ]) {
      final finder = find.byKey(ValueKey(key));
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
    }
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
