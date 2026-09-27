import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_api_runtime.dart';
import 'package:momcozy_flutter_app/core/auth/momcozy_session.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_page.dart';

import '../../support/fixture_api_transport.dart';

void main() {
  testWidgets('release login UI follows its compile-time lane switch', (
    tester,
  ) async {
    const inviteOnly = bool.fromEnvironment('MOMCOZY_INTERNAL_INVITE_LOGIN');
    final controller = MomCozyRuntimeController(
      MomCozyApiRuntime(jsonTransport: FixtureApiJsonTransport({})),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MomCozyAuthPage(
          runtimeController: controller,
          sessionStore: MemoryMomCozySessionStore(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('auth-invite-code-field')),
      inviteOnly ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-invite-login-button')),
      inviteOnly ? findsOneWidget : findsNothing,
    );
    expect(
      find.byKey(const ValueKey('auth-email-field')),
      inviteOnly ? findsNothing : findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('auth-password-field')),
      inviteOnly ? findsNothing : findsOneWidget,
    );
  });
}
