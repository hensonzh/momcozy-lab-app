import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/domain/shared/local_date.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_diary_page.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_theme.dart';

import '../../support/momcozy_test_fonts.dart';
import 'mother_diary_test.dart' show DiaryFixture;

void main() {
  testWidgets('inventory independent diary loading then ready', (tester) async {
    await loadMomCozyTestFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<void>();
    final repository = DiaryFixture()..loadGate = gate;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: momCozyTheme(),
        home: MotherDiaryPage(
          repository: repository,
          date: LocalDate(2026, 9, 12),
          onClose: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/ui_inventory/mom-diary-loading-390.png'),
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('保存今天的记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
