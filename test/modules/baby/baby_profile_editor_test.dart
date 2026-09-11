import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'baby_profile_controller_test.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profile dialog scrolls and saves at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = BabyProfileController(
          repository: Profiles(),
          timezone: 'UTC',
          now: () => DateTime.utc(2026, 9, 8),
        );
        addTearDown(controller.dispose);
        BabyProfile? result;
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
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showDialog<BabyProfile>(
                      context: context,
                      builder: (_) => BabyProfileEditor(controller: controller),
                    );
                  },
                  child: const Text('添加宝宝'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('添加宝宝'));
        await tester.pumpAndSettle();
        if (scale == 1) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/baby-profile-editor-${width.toInt()}.png',
            ),
          );
        }
        await tester.enterText(find.byType(TextField), 'Luna');
        await tester.ensureVisible(find.text('保存宝宝资料'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('保存宝宝资料'));
        await tester.pumpAndSettle();
        expect(result?.name, 'Luna');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
