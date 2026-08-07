import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/app/momcozy_design_system.dart';

void main() {
  test('V3 semantic tokens match the approved brand baseline', () {
    expect(MomCozyV3Colors.brand, const Color(0xff7a2840));
    expect(MomCozyV3Colors.ink, const Color(0xff1a1a1a));
    expect(MomCozyV3Colors.background, const Color(0xfffbf5f3));
    expect(MomCozyV3Colors.surface, Colors.white);
    expect(MomCozyV3Colors.roseTint, const Color(0xfff5e6eb));
    expect(MomCozyV3Colors.success, const Color(0xff4caf50));
    expect(MomCozySpacing.page, 16);
    expect(MomCozyTapTargets.minimum, 44);
  });
}
