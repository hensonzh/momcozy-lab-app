@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../flutter_test_config.dart';

void main() {
  test('configured golden comparator remains active during test execution', () {
    final toleranceConfigured =
        Platform.environment['MOMCOZY_GOLDEN_PRECISION_TOLERANCE'] != null;

    expect(isMomcozyTolerantGoldenComparator, toleranceConfigured);
  });
}
