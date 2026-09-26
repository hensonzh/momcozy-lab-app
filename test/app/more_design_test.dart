import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/modules/profile/presentation/more_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import '../support/momcozy_test_fonts.dart';
import '../support/fixture_api_transport.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('More account layout at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final runtime = MomCozyApiRuntime.fromSession(
          const MomCozySession(
            status: MomCozySessionStatus.authenticated,
            userId: 'mia-with-a-long-account-identifier',
            babyId: 'baby',
            locale: 'en',
          ),
          jsonTransport: FixtureApiJsonTransport({
            'display_name': 'Mia Chen',
            'email': 'mia@example.test',
          }),
        );
        final router = GoRouter(
          initialLocation: '/more',
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => MomCozyRuntimeScope(
                apiRuntime: runtime,
                child: Scaffold(
                  body: SafeArea(
                    child: MorePage(
                      onLogout: null,
                      onDeleteAccount: () async {},
                    ),
                  ),
                  bottomNavigationBar: const MomCozyBottomNavigation(
                    location: '/more',
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MorePage));
        await tester.runAsync(() async {
          for (final asset in [MomCozyAssets.agentAvatar]) {
            await precacheImage(AssetImage(asset), context);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../goldens/design_system/more-${width.toInt()}.png',
            ),
          );
        }
        expect(find.text('Mia Chen'), findsOneWidget);
        expect(find.text('mia@example.test'), findsOneWidget);
        expect(find.text('Privacy'), findsNothing);
        for (final removed in [
          'Account settings',
          'Notifications',
          'Expert support',
          'Everyday settings',
          'Expert care',
        ]) {
          expect(find.text(removed), findsNothing);
        }
        expect(find.byKey(const ValueKey('account-delete')), findsOneWidget);
        expect(find.text('Request account deletion'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
