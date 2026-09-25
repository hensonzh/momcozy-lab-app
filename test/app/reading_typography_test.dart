import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/product_failure.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';
import 'package:momcozy_flutter_app/shared/widgets/product_feedback.dart';

void main() {
  for (final workbench in [false, true]) {
    testWidgets(
      'reading leading is scoped to user paragraphs: workbench=$workbench',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: momCozyTheme(isWorkbench: workbench),
            home: Scaffold(
              body: ListView(
                children: const [
                  ProductEmptyView(
                    title: 'No records',
                    description: 'Your saved notes will appear here.',
                  ),
                  ProductErrorView(
                    failure: ProductFailure(ProductFailureKind.offline),
                    preserveDraft: true,
                  ),
                  ProductLoadingView(label: 'Loading records'),
                  Text('Control label'),
                ],
              ),
            ),
          ),
        );
        for (final copy in [
          'Your saved notes will appear here.',
          'You\'re offline. Connect and try again.',
          'Your entries are still here.',
          'Loading records',
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(copy),
          );
          expect(
            paragraph.text.style!.height,
            workbench ? 1.43 : 1.55,
            reason: copy,
          );
        }
        for (final copy in ['Control label', 'No records']) {
          final label = tester.renderObject<RenderParagraph>(find.text(copy));
          expect(label.text.style!.height, 1.43, reason: copy);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
