import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/app/momcozy_app.dart';
import 'package:app/app/momcozy_design_system.dart';
import 'package:app/features/agent_hub/agent_hub_page.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  for (final viewport in _viewports) {
    testWidgets('hospital bag cart preview matches ${viewport.label} baseline', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('hospital-bag-cart-preview-golden-surface'),
          child: MaterialApp(
            theme: momCozyTheme(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: MomCozyColors.background,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 42),
                      Expanded(
                        child: AgentMarkdownText(
                          '我也把适合放入购物车参考的妈妈和宝宝用品整理好了，不用一次买完，可以按优先级删减后再决定是否购买。\n\n'
                          '**[打开待产包购物车](/hospital-bag-cart)**',
                          onArtifactAction: (_) {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('hospital-bag-cart-preview-golden-surface')),
        matchesGoldenFile(viewport.filePath),
      );
    });
  }
}

const _viewports = [
  _PreviewViewport(
    label: 'narrow mobile 360x300',
    size: Size(360, 300),
    filePath:
        '../../goldens/agent_hub/narrow_360x800/hospital_bag_cart_preview.png',
  ),
  _PreviewViewport(
    label: 'compact mobile 390x300',
    size: Size(390, 300),
    filePath: '../../goldens/agent_hub/hospital_bag_cart_preview.png',
  ),
  _PreviewViewport(
    label: 'large mobile 430x300',
    size: Size(430, 300),
    filePath:
        '../../goldens/agent_hub/large_430x932/hospital_bag_cart_preview.png',
  ),
];

class _PreviewViewport {
  const _PreviewViewport({
    required this.label,
    required this.size,
    required this.filePath,
  });

  final String label;
  final Size size;
  final String filePath;
}
