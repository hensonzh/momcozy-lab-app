import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/mom_bottom_navigation.dart';
import '../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);
  for (final entry in {'me': 393.0, 'baby': 390.0}.entries) {
    testWidgets('Figma navigation capture ${entry.key}', (tester) async {
      tester.view.physicalSize = Size(entry.value, 100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: MomCozyBottomNavigation(location: '/${entry.key}'),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MomCozyBottomNavigation));
        for (final name in [
          'ArtworkSoftMe',
          'ArtworkSoftBaby',
          'AvatarCozymateNav',
        ]) {
          await precacheImage(
            AssetImage('assets/images/navigation_figma/$name.png'),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const ValueKey('bottom-nav-chrome'))),
        Rect.fromLTWH(0, 18, entry.value, 82),
      );
      await tester.runAsync(() async {
        final png =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await png.toByteData(format: ui.ImageByteFormat.png);
        final out = Directory('build/navigation-figma')
          ..createSync(recursive: true);
        File(
          '${out.path}/app-${entry.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        png.dispose();
      });
    });
  }
}
