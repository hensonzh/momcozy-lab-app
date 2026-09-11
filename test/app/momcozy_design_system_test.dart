import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momcozy_flutter_app/shared/design_system/momcozy_design_system.dart';

void main() {
  test('semantic colors match the approved product design', () {
    expect(MomCozyColors.primaryDark, const Color(0xff8e3f54));
    expect(MomCozyColors.foreground, const Color(0xff302a29));
    expect(MomCozyColors.background, const Color(0xfffaf7f3));
    expect(MomCozyColors.raised, const Color(0xfffffefc));
    expect(MomCozyColors.roseSoft, const Color(0xfff6e7eb));
    expect(MomCozyColors.care, const Color(0xff4d846f));
    expect(MomCozySpacing.page, 16);
    expect(MomCozyTapTargets.minimum, 44);
  });
}
