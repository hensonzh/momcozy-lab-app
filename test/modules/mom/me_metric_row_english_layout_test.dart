@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/domain/me_experience.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_design.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });

  for (final scale in [1.0, 2.0]) {
    for (final metric in [
      MeMetric.energy,
      MeMetric.sleep,
      MeMetric.pain,
      MeMetric.bottle,
      MeMetric.storage,
    ]) {
      testWidgets('${metric.label} fits the suggested record at 320px/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MeMetricRow(metric, onTap: () => taps++),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = tester.getRect(find.byType(MeMetricRow));
        final label = tester.getRect(find.text(metric.label));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(metric.label),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
          ),
        );
        expect(label.bottom, lessThanOrEqualTo(row.bottom - 7));
        expect(tester.takeException(), isNull);
        if (scale == 2 && metric == MeMetric.bottle) {
          await expectLater(
            find.byType(MeMetricRow),
            matchesGoldenFile(
              '../../goldens/design_system/me-suggested-record-bottle-320-2x.png',
            ),
          );
        }
        await tester.tap(find.text(metric.label));
        expect(taps, 1);
      });
    }
  }
}
