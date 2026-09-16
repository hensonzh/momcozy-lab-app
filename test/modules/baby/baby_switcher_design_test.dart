import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_profile.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_home_controller.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_home_page.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_profile_editor.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import '../../support/momcozy_test_fonts.dart';
import 'baby_test_repositories.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'switcher changes the selected baby and opens its profile at $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final profiles = BabyTestProfiles()
            ..values = [
              babyTestProfile,
              const BabyProfile(id: 'milo', name: 'Milo', version: 1),
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

          final semantics = tester.ensureSemantics();
          await tester.pump();
          final switchNode = tester.getSemantics(
            find.bySemanticsLabel(RegExp('当前宝宝 Luna')),
          );
          expect(switchNode.getSemanticsData().label, '当前宝宝 Luna，女宝宝，切换宝宝');
          expect(
            switchNode.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          semantics.dispose();
          await tester.tap(find.text('Luna').first);
          await tester.pumpAndSettle();
          expect(find.text('切换宝宝'), findsOneWidget);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-switcher-${width.toInt()}.png',
              ),
            );
          }
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Milo'));
          await tester.pumpAndSettle();
          expect(c.baby?.id, 'milo');
          expect(find.text('切换宝宝'), findsNothing);
          await tester.tap(find.text('Milo').first);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('编辑当前宝宝资料'));
          await tester.tap(find.text('编辑当前宝宝资料'));
          await tester.pumpAndSettle();
          expect(find.byType(BabyProfileEditor), findsOneWidget);
          expect(find.text('Milo 的资料'), findsOneWidget);
          if (scale == 1) {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../../goldens/design_system/baby-profile-existing-${width.toInt()}.png',
              ),
            );
          }
          await tester.tap(find.byTooltip('关闭宝宝资料'));
          await tester.pumpAndSettle();
          expect(c.baby?.id, 'milo');
          expect(profiles.values, hasLength(2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
