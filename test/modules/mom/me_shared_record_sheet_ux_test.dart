import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/baby/baby_record.dart';
import 'package:momcozy_flutter_app/modules/baby/application/baby_record_editor_controller.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/me_shared_record_sheet.dart';

import '../baby/baby_test_repositories.dart';

void main() {
  testWidgets('weight fields align and omit the redundant footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = BabyRecordEditorController(
      repository: BabyTestRecords(),
      baby: babyTestProfile,
      timezone: 'Asia/Shanghai',
      now: () => babyTestNow,
      kind: BabyRecordKind.growth,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MeSharedRecordSheet(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final date = find.byType(OutlinedButton);
    final weight = find.byType(TextField);
    final source = find.byType(DropdownButtonFormField<String>);
    final save = find.byType(FilledButton);
    expect(
      find.text('The measurement date will appear with the weight.'),
      findsNothing,
    );
    expect(tester.getSize(date).width, tester.getSize(source).width);
    expect(tester.getSize(weight).width, tester.getSize(source).width);
    expect(tester.getSize(source).height, lessThanOrEqualTo(56));
    expect(
      tester.getTopLeft(save).dy - tester.getBottomLeft(source).dy,
      lessThanOrEqualTo(40),
    );
    await tester.enterText(weight, '4.2');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('feeding form uses compact fields and requires bottle amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = BabyRecordEditorController(
      repository: BabyTestRecords(),
      baby: babyTestProfile,
      timezone: 'Asia/Shanghai',
      now: () => babyTestNow,
      kind: BabyRecordKind.feeding,
    )..setFeedingMethod(BabyFeedingMethod.expressedMilk);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MeSharedRecordSheet(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final method = find.byType(DropdownButtonFormField<BabyFeedingMethod>);
    final time = find.byType(OutlinedButton);
    final amount = find.byType(TextField);
    final save = find.byType(FilledButton);
    expect(
      find.text('No need to enter milliliters for nursing.'),
      findsNothing,
    );
    expect(find.text('How much did your baby drink? *'), findsOneWidget);
    expect(tester.getSize(method).width, lessThanOrEqualTo(300));
    expect(tester.getSize(time).width, tester.getSize(method).width);
    expect(tester.getSize(amount).width, tester.getSize(method).width);
    expect(tester.getSize(method).height, lessThanOrEqualTo(56));
    expect(
      tester.getTopLeft(method).dy - tester.getBottomLeft(time).dy,
      lessThan(42),
    );
    expect(
      tester.getTopLeft(save).dy - tester.getBottomLeft(amount).dy,
      lessThan(40),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(amount, '90');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });
}
