import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/ibclc/workbench_shell.dart';
import 'package:momcozy_flutter_app/domain/care/service_package.dart';
import 'package:momcozy_flutter_app/domain/ibclc/workbench.dart';

void main() {
  testWidgets('workbench uses English expert identity and language labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identity = WorkbenchIdentity(
      provider: const CareProvider(
        id: 'provider',
        displayName: '王顾问',
        timezone: 'America/Los_Angeles',
        regions: ['CA'],
        languages: ['en', 'Français'],
        bio: 'Cozymate 泌乳服务',
        sandbox: false,
      ),
      email: 'expert@example.test',
      mfaExpiresAt: DateTime.utc(2026, 9, 24, 20),
      serverTime: DateTime.utc(2026, 9, 24, 19),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchShell(
          identity: identity,
          destinations: const [],
          location: '/ibclc',
          onNavigate: (_) {},
          onLogout: () {},
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(identity.provider.publicName), findsOneWidget);
    expect(find.textContaining('王顾问'), findsNothing);
    await tester.tap(find.byTooltip('Work account'));
    await tester.pumpAndSettle();
    expect(find.text('Languages: English, French'), findsOneWidget);
    expect(find.textContaining('Français'), findsNothing);
    expect(find.textContaining('王顾问'), findsNothing);
    expect(identity.provider.displayName, '王顾问');
  });
}
