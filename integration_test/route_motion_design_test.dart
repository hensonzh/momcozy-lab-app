import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/features/auth/presentation/auth_login_chrome.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import 'package:momcozy_flutter_app/shared/widgets/confirm_discard.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android reduced motion dialog, sheet and route', (tester) async {
    var converted = false;
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
        await tester.pump();
      }
      final bytes = await binding.takeScreenshot(name);
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/$name.png').writeAsBytes(bytes);
    }

    for (final scale in [1.0, 2.0]) {
      bool? discard;
      await tester.pumpWidget(
        MaterialApp(
          theme: momCozyTheme().copyWith(
            pageTransitionsTheme: momCozyPageTransitionsTheme,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        discard = await confirmDiscard(context);
                      },
                      child: const Text('Close draft'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: SafeArea(
                              child: SingleChildScrollView(
                                child: AuthLoginHeader(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Close draft'));
      await tester.pump();
      await tester.pump();
      expect(
        ModalRoute.of(
          tester.element(find.byType(AlertDialog)),
        )!.animation!.value,
        1,
      );
      await capture('native-route-confirm-${scale.toInt()}x');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(discard, false);
      await tester.tap(find.text('Open login'));
      await tester.pump();
      await tester.pump();
      final button = find.byKey(const ValueKey('auth-language-button'));
      final first = tester.getRect(button);
      await tester.pumpAndSettle();
      expect(tester.getRect(button), first);
      await capture('native-route-login-${scale.toInt()}x');
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
      expect(
        ModalRoute.of(
          tester.element(find.byType(BottomSheet)),
        )!.animation!.value,
        1,
      );
      await capture('native-route-language-${scale.toInt()}x');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
