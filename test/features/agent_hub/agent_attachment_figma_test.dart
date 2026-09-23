import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/agent_attachment_scenarios.dart';
import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(loadMomCozyTestFonts);

  testWidgets(
    'attachment menu matches Figma geometry and keeps actions usable',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await verifyAgentAttachments(
        tester,
        scale: 1,
        capture: (state) async {
          if (state != 'menu') return;
          final menu = find.byKey(const ValueKey('agent-attachment-menu'));
          final rect = tester.getRect(menu);
          expect(rect.size, const Size(208, 144));
          for (final action in ['camera', 'photo', 'file']) {
            expect(
              tester
                  .getSize(
                    find.byKey(ValueKey('agent-attachment-$action-button')),
                  )
                  .height,
              48,
            );
          }
          final layer =
              tester.binding.renderViews.first.debugLayer! as OffsetLayer;
          const offset = Offset.zero;
          await tester.runAsync(() async {
            final image = await layer.toImage(
              Offset.zero & const Size(393, 844),
            );
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final out = Directory(
              'build/design-evidence/cozymate/attachment-menu',
            );
            out.createSync(recursive: true);
            File(
              '${out.path}/app-capture.png',
            ).writeAsBytesSync(png!.buffer.asUint8List());
            File('${out.path}/app-menu-bounds.json').writeAsStringSync(
              jsonEncode({
                'crop': [
                  rect.left - offset.dx - 6,
                  rect.top - offset.dy - 6,
                  rect.right - offset.dx + 6,
                  rect.bottom - offset.dy + 6,
                ],
                'viewport': [393, 844],
                'dpr': 1,
                'textScale': 1,
              }),
            );
            image.dispose();
          });
        },
      );
    },
  );
}
