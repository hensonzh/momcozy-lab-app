import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_bootstrap.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';
import 'package:momcozy_flutter_app/core/auth/flutter_secure_momcozy_session_store.dart';

void main() {
  testWidgets('startup surface matches the chat-first canvas', (tester) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(MomCozyBootstrap(load: () => pending.future));
    await tester.pump();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      MomCozyColors.chatFirstCanvas,
    );
    pending.complete(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('secure storage failure never enters a substitute app', (
    tester,
  ) async {
    var attempts = 0;
    final retry = Completer<Widget>();
    await tester.pumpWidget(
      MomCozyBootstrap(
        load: () {
          if (++attempts == 1) {
            throw const MomCozySessionPersistenceException(
              operation: 'read',
              causeType: 'PlatformException',
              causeStatus: -34018,
            );
          }
          return retry.future;
        },
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-error')), findsOneWidget);
    expect(find.text('authenticated app'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('startup-retry')));
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-loading')), findsOneWidget);
    expect(attempts, 2);
    retry.complete(const MaterialApp(home: Text('authenticated app')));
    await tester.pumpAndSettle();
    expect(find.text('authenticated app'), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-error')), findsNothing);
  });
}
