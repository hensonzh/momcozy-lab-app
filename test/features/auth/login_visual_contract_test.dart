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

  testWidgets('login default matches the 393x844 design contract', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 844);
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
        home: MomCozyAuthPage(
          runtimeController: runtime,
          sessionStore: MemoryMomCozySessionStore(),
          internalInviteOnly: false,
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await precacheImage(
        const AssetImage('assets/images/google_sign_in.png'),
        context,
      );
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../../design-contract/login/comparisons/actual/flutter-login-393x844.png',
      ),
    );
  });
}
