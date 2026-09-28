@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_concerns.dart';

import '../../support/momcozy_test_fonts.dart';

void main() {
  setUpAll(() async {
    await loadMomCozyTestFonts();
    await (FontLoader(
      'BabyNotoSans',
    )..addFont(rootBundle.load('assets/fonts/BabyNotoSans-VF.ttf'))).load();
  });
  for (final size in [const Size(320, 568), const Size(393, 844)]) {
    for (final action in ['Not now', 'Open settings']) {
      testWidgets('notification settings $action remains usable at $size/2x', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Future<bool?>? result;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => result = showMeNotificationSettings(context),
                  child: const Text('Open prompt'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open prompt'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width == 320 && action == 'Not now') {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              '../../goldens/design_system/me-notification-settings-320-2x.png',
            ),
          );
        }
        for (final label in [
          'Turn on notifications',
          'Open settings',
          'Not now',
        ]) {
          final text = find.text(label);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(
            paragraph.size.height,
            greaterThanOrEqualTo(
              paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
            ),
            reason: '$label should not be clipped',
          );
        }
        final title = find.text('Turn on notifications');
        final word = TextPainter(
          text: TextSpan(
            text: 'notifications',
            style: tester.widget<Text>(title).style,
          ),
          textDirection: TextDirection.ltr,
          textScaler: const TextScaler.linear(2),
        )..layout();
        expect(
          tester.getSize(title).width,
          greaterThanOrEqualTo(word.width),
          reason:
              'The English title should wrap between words, not inside a word.',
        );
        word.dispose();
        final button = find.text(action);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(await result, action == 'Open settings');
        expect(find.text('Turn on notifications'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
