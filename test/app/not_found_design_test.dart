import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_app.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../support/fixture_api_transport.dart';
import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('unknown route shows a recoverable page at $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final runtime = MomCozyApiRuntime(
          jsonTransport: FixtureApiJsonTransport(const {}),
          timezoneProvider: () async => 'UTC',
        );
        final router = createMomCozyRouter(
          initialLocation: '/missing-page?internal=hidden',
        );
        await tester.pumpWidget(
          MomCozyRuntimeScope(
            apiRuntime: runtime,
            child: MaterialApp.router(
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
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('页面未找到'), findsOneWidget);
        expect(find.textContaining('Flutter route map'), findsNothing);
        expect(find.textContaining('missing-page'), findsNothing);
        expect(find.text('返回首页').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../goldens/design_system/not-found-${width.toInt()}.png',
            ),
          );
        }
        if (width == 320 && scale == 2) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../goldens/design_system/not-found-320-2x.png'),
          );
        }
        await tester.tap(find.text('返回首页'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/me');
        expect(find.byType(MomCozyNotFoundPage), findsNothing);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      });
    }
  }
  testWidgets('an unauthenticated unknown route cannot bypass login', (
    tester,
  ) async {
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: FixtureApiJsonTransport(const {})),
    );
    final router = createMomCozyRouter(
      runtimeController: controller,
      sessionStore: MemoryMomCozySessionStore(),
      initialLocation: '/missing-private-page',
    );
    await tester.pumpWidget(
      MaterialApp.router(theme: momCozyTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    if (find.text('返回首页').evaluate().isNotEmpty) {
      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();
    }
    expect(router.routeInformationProvider.value.uri.path, '/login');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    controller.dispose();
  });
}
