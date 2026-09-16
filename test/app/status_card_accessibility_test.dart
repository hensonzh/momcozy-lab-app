import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/modules/baby/presentation/baby_overview_cards.dart';
import 'package:momcozy_flutter_app/modules/mom/presentation/mother_status_card.dart';
import 'package:momcozy_flutter_app/shared/widgets/momcozy_line_icon.dart';
import 'package:momcozy_flutter_app/shared/widgets/mom_card_background.dart';
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
                  label: '昨夜休息',
                  value: '4–5 小时',
                  onTap: () {},
                ),
              ),
              SizedBox(
                height: 180,
                child: BabyStatusCard(
                  label: '喂养',
                  value: '2 次',
                  hasRecord: true,
                  detail: '最近一次 09:00',
                  icon: MomCozyLineGlyph.drop,
                  gradient: MomCozyGradients.rest,
                  backgroundDecoration: MomCardDecoration.feeding,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (final label in ['昨夜休息，4–5 小时', '今日喂养，2 次，最近一次 09:00']) {
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
