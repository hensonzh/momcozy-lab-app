@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';
import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  testWidgets('loading has a single accessible status when label is omitted', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(const ProductLoadingView(), 1));
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Loading'))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      await tester.pumpWidget(
        _app(
          const ProductErrorView(
            failure: ProductFailure(ProductFailureKind.offline),
          ),
          1,
        ),
      );
      expect(
        tester
            .getSemantics(find.byType(ProductErrorView))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('loading remains readable in a short region at 2x', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Center(
          child: SizedBox(
            width: 280,
            height: 90,
            child: ProductLoadingView(label: 'Loading records, please wait'),
          ),
        ),
        2,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Loading records, please wait'));
    expect(
      find.text('Loading records, please wait').hitTestable(),
      findsOneWidget,
    );
  });
  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('feedback layout and retry callbacks $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(const ProductLoadingView(label: 'Loading records'), scale),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await _golden('loading', width, scale);
        var actions = 0;
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: ProductEmptyView(
                textAlign: TextAlign.start,
                title: 'No records yet',
                description: 'Your records will appear here.',
                action: TextButton(
                  onPressed: () => actions++,
                  child: const Text('Add a record'),
                ),
              ),
            ),
            scale,
          ),
        );
        await tester.pumpAndSettle();
        await _golden('empty', width, scale);
        await tester.tap(find.text('Add a record'));
        expect(actions, 1);
        for (final kind in ProductFailureKind.values) {
          await tester.pumpWidget(
            _app(
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProductErrorView(
                    failure: ProductFailure(kind),
                    preserveDraft: true,
                    onRetry: () => actions++,
                  ),
                ],
              ),
              scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Your entries are still here.'), findsOneWidget);
          final retry = find.text(
            kind == ProductFailureKind.conflict ? 'Reload' : 'Try again',
          );
          await tester.tap(retry);
          expect(actions, kind.index + 2);
          if (kind == ProductFailureKind.conflict) {
            await _golden('conflict', width, scale);
          }
          if (kind == ProductFailureKind.offline) {
            await _golden('offline', width, scale);
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}

Widget _app(Widget body, double scale) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: momCozyTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
    ),
    child: child!,
  ),
  home: RepaintBoundary(
    key: const ValueKey('feedback-capture'),
    child: Scaffold(
      appBar: AppBar(title: const Text('Records')),
      body: SafeArea(child: body),
    ),
  ),
);

Future<void> _golden(String name, double width, double scale) => expectLater(
  find.byKey(const ValueKey('feedback-capture')),
  matchesGoldenFile(
    '../goldens/design_system/feedback-$name-${width.toInt()}${scale == 2 ? '-2x' : ''}.png',
  ),
);
