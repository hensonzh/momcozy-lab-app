import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_shared_record_sheet.dart';

import '../baby/baby_test_repositories.dart';

void main() {
  for (final (kind, title) in <(BabyRecordKind, String)>[
    (BabyRecordKind.feeding, 'Log a feeding'),
    (BabyRecordKind.diaper, 'Log a diaper change'),
    (BabyRecordKind.growth, "Log your baby's weight"),
  ]) {
    testWidgets('$kind title and form fit at 320px with double text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BabyRecordEditorController(
        repository: BabyTestRecords(),
        baby: babyTestProfile,
        timezone: 'America/Los_Angeles',
        now: () => babyTestNow,
        kind: kind,
      );
      addTearDown(controller.dispose);
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
              body: Center(
                child: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MeSharedRecordSheet(controller: controller),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 1,
        ),
      );
      expect(tester.takeException(), isNull);

      if (kind == BabyRecordKind.feeding) {
        final feedingMethod = find.byType(
          DropdownButtonFormField<BabyFeedingMethod>,
        );
        await tester.ensureVisible(feedingMethod);
        await tester.tap(feedingMethod);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bottle-fed breast milk').last);
        await tester.pumpAndSettle();
        final selected = find.descendant(
          of: feedingMethod,
          matching: find.text('Bottle-fed breast milk'),
        );
        final label = tester.renderObject<RenderParagraph>(selected);
        expect(
          label.size.height,
          greaterThanOrEqualTo(
            label.getMaxIntrinsicHeight(label.size.width) - 1,
          ),
        );
        expect(controller.feedingMethod, BabyFeedingMethod.expressedMilk);
        expect(tester.takeException(), isNull);
      } else if (kind == BabyRecordKind.diaper) {
        final both = find.text('Both');
        await tester.ensureVisible(both);
        await tester.tap(both);
        await tester.pumpAndSettle();
        expect(controller.diaperKind, DiaperKind.both);
        expect(tester.takeException(), isNull);
      } else {
        final source = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(source);
        await tester.tap(source);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clinic or checkup').last);
        await tester.pumpAndSettle();
        final selected = find.descendant(
          of: source,
          matching: find.text('Clinic or checkup'),
        );
        final label = tester.renderObject<RenderParagraph>(selected);
        expect(
          label.size.height,
          greaterThanOrEqualTo(
            label.getMaxIntrinsicHeight(label.size.width) - 1,
          ),
        );
        expect(controller.measurementSource, 'clinic');
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Save record'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
