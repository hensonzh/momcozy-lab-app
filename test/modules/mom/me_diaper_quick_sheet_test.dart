import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/shared/zoned_time.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_shared_record_sheet.dart';

import '../baby/baby_test_repositories.dart';

void main() {
  testWidgets(
    'one quick diaper entry records wet and dirty without extra fields',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = BabyTestRecords();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMeSharedRecordSheet(
                  context,
                  repository: repo,
                  baby: babyTestProfile,
                  timezone: 'Asia/Shanghai',
                  now: () => babyTestNow,
                  kind: BabyRecordKind.diaper,
                ),
                child: const Text('Open diaper'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open diaper'));
      await tester.pumpAndSettle();
      expect(find.text('Log a diaper change'), findsOneWidget);
      expect(find.text('Diaper change time'), findsNothing);
      expect(find.text('Additional notes (optional)'), findsNothing);
      expect(
        find.text(
          'Your home page shows the number of diaper changes you logged.',
        ),
        findsNothing,
      );
      expect(find.byType(DropdownButtonFormField<DiaperKind>), findsNothing);
      for (final choice in ['Wet', 'Dirty', 'Both']) {
        expect(find.text(choice), findsOneWidget);
      }
      final save = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.text('Both'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final record = repo.values.single as BabyDiaperRecord;
      expect(record.kind, DiaperKind.both);
      expect(record.note, isEmpty);
      await tester.tap(find.text('Open diaper'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save record'));
      await tester.pumpAndSettle();
      final summary = BabyDaySummary.fromRecords(
        repo.values,
        babyId: babyTestProfile.id,
        window: zonedDayWindow(LocalDate(2026, 9, 8), 'Asia/Shanghai'),
        now: babyTestNow,
      );
      expect(summary.wetCount, 2);
      expect(summary.dirtyCount, 1);
    },
  );
}
