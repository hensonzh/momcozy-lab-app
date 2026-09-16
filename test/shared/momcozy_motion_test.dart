import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_motion.dart';
import '../support/momcozy_test_fonts.dart';
import '../support/motion_preference_scenarios.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('reduced motion flows $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await verifyMotionPreference(
          tester,
          scale: scale,
          capture: (state) async {
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                '../goldens/design_system/reduced-$state-${width.toInt()}-${scale.toInt()}x.png',
              ),
            );
          },
        );
      });
    }
  }
  testWidgets('ordinary scrolling retains its movement and destination', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                FilledButton(
                  onPressed: () => MomCozyMotion.scrollTo(
                    context,
                    scroll,
                    600,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.linear,
                  ),
                  child: const Text('Move'),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: const [SizedBox(height: 2000)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Move'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, inExclusiveRange(0, 600));
    await tester.pumpAndSettle();
    expect(scroll.offset, 600);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
