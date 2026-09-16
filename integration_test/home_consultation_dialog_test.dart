import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:momcozy_flutter_app/domain/care/appointment.dart';
import 'package:momcozy_flutter_app/modules/consultation/presentation/home_consultation_dialog.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../test/modules/consultation/room_test_support.dart';

class _Appointments extends Fake implements AppointmentRepository {}

/// Native presentation only, with the canonical JSON supplied by --dart-define.
/// No API, account writes, permissions or remote media are used.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android home preparation overlay closes and reopens',
    (tester) async {
      final fixture = Map<String, Object?>.from(
        jsonDecode(
              utf8.decode(
                base64Decode(
                  const String.fromEnvironment(
                    'HOME_PREPARATION_FIXTURE_BASE64',
                  ),
                ),
              ),
            )
            as Map,
      );
      final rooms = TestRoomRepository(fixture: fixture);
      final media = <TestConsultationMedia>[];
      var returned = 0;
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: momCozyTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () async {
                      final current = TestConsultationMedia();
                      media.add(current);
                      await showHomeConsultationDialog(
                        context,
                        createController: () => testController(rooms, current),
                        appointments: _Appointments(),
                      );
                      returned++;
                    },
                    child: const Text('查看预约'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('查看预约'));
        await tester.pumpAndSettle();
        expect(find.text('00:05:00'), findsOneWidget);
        expect(find.text('预约详情'), findsOneWidget);
        if (scale == 1) await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        final bytes = await binding.takeScreenshot(
          'native-home-preparation-${scale.toInt()}x',
        );
        final directory = await getApplicationDocumentsDirectory();
        await File(
          '${directory.path}/native-home-preparation-${scale.toInt()}x.png',
        ).writeAsBytes(bytes);
        await tester.tap(find.byTooltip('关闭预约详情'));
        await tester.pumpAndSettle();
        expect(find.text('预约详情'), findsNothing);
        expect(rooms.keys, isEmpty);
        expect(media.last.connectCalls, 0);
        expect(tester.takeException(), isNull);
      }
      expect(returned, 2);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
