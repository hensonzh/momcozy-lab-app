import 'package:flutter/material.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_profile_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'baby_profile_controller_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final longName in [false, true]) {
        testWidgets(
          'profile dialog scrolls and saves at $width / $scale / long=$longName',
          (tester) async {
            tester.view.physicalSize = Size(width, longName ? 600 : 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = BabyProfileController(
              repository: Profiles(),
              initial: longName
                  ? BabyProfile(
                      id: 'baby',
                      name: '宝宝称呼比较长也应该保持完整可读',
                      birthDate: LocalDate(2026, 8, 18),
                      sex: BabySex.female,
                      version: 3,
                    )
                  : null,
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
                          builder: (_) =>
                              BabyProfileEditor(controller: controller),
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
                  '../../goldens/design_system/baby-profile-${longName ? 'short' : 'editor'}-${width.toInt()}.png',
                ),
              );
            }
            final name = longName ? '宝宝称呼比较长也应该保持完整可读' : 'Luna';
            expect(find.byTooltip('关闭宝宝资料').hitTestable(), findsOneWidget);
            await tester.enterText(find.byType(TextField), name);
            if (width == 320) {
              tester.view.viewInsets = const FakeViewPadding(bottom: 300);
              addTearDown(tester.view.resetViewInsets);
              await tester.pumpAndSettle();
            }
            expect(find.text('保存宝宝资料').hitTestable(), findsOneWidget);
            await tester.ensureVisible(find.text('保存宝宝资料'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.tap(find.text('保存宝宝资料'));
            await tester.pumpAndSettle();
            expect(result?.name, name);
            if (longName) {
              expect(result?.id, 'baby');
              expect(result?.version, 4);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
