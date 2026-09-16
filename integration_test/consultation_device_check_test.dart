import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/device_check_dialog.dart';
import 'package:momcozy_flutter_app/services/consultations/device_check.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

/// Run on a local Android emulator with CAMERA and RECORD_AUDIO granted.
/// Use `flutter test --no-uninstall` to preserve the installed app and evidence.
/// No account, consultation room, API or remote media connection is created.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native camera and microphone check releases devices and can repeat',
    (tester) async {
      final check = ConsultationDeviceCheck();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: momCozyTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        ConsultationDeviceCheckDialog(createCheck: () => check),
                  ),
                  child: const Text('检查本机设备'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('检查本机设备'));
      await _waitUntilReady(tester);
      await tester.pumpAndSettle();
      expect(check.video, isNull);
      expect(check.microphoneAvailable, isFalse);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final bytes = await binding.takeScreenshot('native-device-ready');
      final directory = await getApplicationDocumentsDirectory();
      await File(
        '${directory.path}/native-device-ready.png',
      ).writeAsBytes(bytes);
      await tester.ensureVisible(find.text('重新检查'));
      await tester.tap(find.text('重新检查'));
      await _waitUntilReady(tester);
      expect(check.video, isNull);
      expect(check.microphoneAvailable, isFalse);
      await tester.ensureVisible(find.text('完成'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(find.byType(ConsultationDeviceCheckDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _waitUntilReady(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('摄像头和麦克风均可用').evaluate().isNotEmpty) return;
    if (find.text('检查未通过，请重试').evaluate().isNotEmpty) {
      fail(
        'Real device check failed; verify Android permission and device availability.',
      );
    }
  }
  fail('Device check did not complete within 30 seconds.');
}
