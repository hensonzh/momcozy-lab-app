import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_status_card.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_line_icon.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

void main() {
  testWidgets('mother and baby status cards expose a semantic tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 180,
                child: MotherStatusCard(
                  kind: MotherCardKind.rest,
                  label: 'Last night’s rest',
                  value: '4–5 hours',
                  onTap: () {},
                ),
              ),
              SizedBox(
                height: 180,
                child: BabyStatusCard(
                  label: 'Feeding',
                  value: '2 times',
                  hasRecord: true,
                  detail: 'Last fed at 09:00',
                  icon: MomCozyLineGlyph.drop,
                  gradient: MomCozyGradients.rest,
                  artwork: 'feeding',
                  asset: 'IconDrop',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in [
      'Last night’s rest, 4–5 hours',
      "Today's Feeding: 2 times. Last fed at 09:00",
    ]) {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }
    semantics.dispose();
  });
}
