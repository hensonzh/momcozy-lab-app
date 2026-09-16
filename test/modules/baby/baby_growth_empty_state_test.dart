import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_growth_curve.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final missing in ['birth', 'sex', 'both']) {
        testWidgets(
          'missing $missing growth profile at $width/$scale is actionable without fabricated reference',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final profiles = BabyTestProfiles()
              ..values = [
                BabyProfile(
                  id: 'baby',
                  name: 'Luna',
                  birthDate: missing == 'sex' ? LocalDate(2026, 8, 18) : null,
                  sex: missing == 'birth'
                      ? BabySex.female
                      : BabySex.unspecified,
                  version: 1,
                ),
              ];
            final c = BabyHomeController(
              profileRepository: profiles,
              recordRepository: BabyTestRecords(),
              timezoneProvider: () async => 'Asia/Shanghai',
              now: () => babyTestNow,
            );
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
                  body: BabyHomePage(
                    controller: c,
                    onAsk: (_) {},
                    onHistory: (_) async {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              for (final asset in [
                'assets/images/momcozy-agent.png',
                'assets/images/me_baby_overview/nursery_camera_clean.png',
              ]) {
                await precacheImage(
                  AssetImage(asset),
                  tester.element(find.byType(MaterialApp)),
                );
              }
            });
            await tester.pumpAndSettle();

            await tester.scrollUntilVisible(
              find.text('完善资料'),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(find.byType(BabyGrowthCurve));
            await tester.pumpAndSettle();
            expect(find.text('补充出生日期和出生记录性别后，才能显示对应的生长参考范围。'), findsOneWidget);
            expect(find.bySemanticsLabel(RegExp('.*浅绿色为 WHO.*')), findsNothing);
            if (scale == 1) {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../../goldens/design_system/baby-growth-missing-$missing-${width.toInt()}.png',
                ),
              );
            }
            final metric = find.descendant(
              of: find.byType(BabyGrowthCurve),
              matching: find.text('头围'),
            );
            await tester.ensureVisible(metric);
            await tester.tap(metric);
            await tester.pumpAndSettle();
            expect(find.textContaining(' · cm'), findsOneWidget);
            await tester.ensureVisible(find.text('完善资料'));
            await tester.tap(find.text('完善资料'));
            await tester.pumpAndSettle();
            expect(find.byType(BabyProfileEditor), findsOneWidget);
            expect(find.byType(TextField), findsOneWidget);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'Luna',
            );
            await tester.tap(find.byTooltip('关闭宝宝资料'));
            await tester.pumpAndSettle();
            expect(
              profiles.values.single.birthDate,
              missing == 'sex' ? LocalDate(2026, 8, 18) : null,
            );
            profiles.values = [babyTestProfile];
            await c.load();
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byType(BabyGrowthCurve),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text('完善资料'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
