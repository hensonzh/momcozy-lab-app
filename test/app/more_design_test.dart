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

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('More navigation and privacy at $width / $scale', (
        tester,
      ) async {
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
        );
        final router = GoRouter(
          initialLocation: '/more',
          routes: [
            GoRoute(
              path: '/more',
              builder: (context, state) => MomCozyRuntimeScope(
                apiRuntime: runtime,
                child: const Scaffold(
                  body: SafeArea(child: MorePage(onLogout: null)),
                  bottomNavigationBar: MomCozyBottomNavigation(
                    location: '/more',
                  ),
                ),
              ),
            ),
            for (final path in ['/account', '/notifications', '/services'])
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(body: Text(path)),
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
        await tester.runAsync(
          () => precacheImage(
            const AssetImage(MomCozyAssets.agentAvatar),
            context,
          ),
        );
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
        final privacy = find.text('隐私与授权');
        await tester.scrollUntilVisible(privacy, 240);
        await tester.pumpAndSettle();
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('知道了'));
        await tester.pumpAndSettle();
        for (final entry in {
          'Account settings': '/account',
          '通知': '/notifications',
          '专家支持': '/services',
        }.entries) {
          await tester.scrollUntilVisible(
            find.text(entry.key),
            entry.key == 'Account settings' ? -240 : 240,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.key));
          await tester.pumpAndSettle();
          expect(find.text(entry.value), findsOneWidget);
          router.go('/more');
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
