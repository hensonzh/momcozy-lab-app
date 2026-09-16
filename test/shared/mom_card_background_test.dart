import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_companion_widgets.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('backgrounds preserve content layout and taps at $scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        var taps = 0;
        const contentKey = ValueKey('card-content');
        const surfaceKey = ValueKey('card-surface');
        Future<void> render(MomCardDecoration? decoration) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      child: MomHomeSurface(
                        key: surfaceKey,
                        gradient: const LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ),
                        backgroundDecoration: decoration,
                        onTap: () => taps++,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Card title and a longer description that wraps.',
                            key: contentKey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await render(null);
        final content = tester.getRect(find.byKey(contentKey));
        final surface = tester.getRect(find.byKey(surfaceKey));
        for (final decoration in MomCardDecoration.values) {
          await render(decoration);
          expect(
            tester.getRect(find.byKey(contentKey)),
            content,
            reason: decoration.name,
          );
          expect(
            tester.getRect(find.byKey(surfaceKey)),
            surface,
            reason: decoration.name,
          );
          expect(
            find.bySemanticsLabel(
              'Card title and a longer description that wraps.',
            ),
            findsOneWidget,
          );
          final before = taps;
          await tester.tapAt(surface.topRight + const Offset(-8, 8));
          expect(taps, before + 1, reason: decoration.name);
          expect(tester.takeException(), isNull, reason: decoration.name);
        }
      } finally {
        semantics.dispose();
      }
    });
  }
}
