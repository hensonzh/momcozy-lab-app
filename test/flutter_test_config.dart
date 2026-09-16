import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_inventory_capture.dart';

const _toleranceEnvironmentKey = 'MOMCOZY_GOLDEN_PRECISION_TOLERANCE';

bool get isMomcozyTolerantGoldenComparator =>
    goldenFileComparator is _TolerantGoldenFileComparator;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final configuredTolerance = Platform.environment[_toleranceEnvironmentKey];
  if (configuredTolerance != null) {
    final precisionTolerance = double.tryParse(configuredTolerance);
    if (precisionTolerance == null ||
        precisionTolerance < 0 ||
        precisionTolerance > 1) {
      throw FormatException(
        '$_toleranceEnvironmentKey must be a number between 0 and 1.',
      );
    }
    final previousComparator = goldenFileComparator;
    if (previousComparator is! LocalFileComparator) {
      throw StateError(
        'Golden tolerance requires Flutter LocalFileComparator.',
      );
    }
    goldenFileComparator = _TolerantGoldenFileComparator(
      previousComparator.basedir.resolve('momcozy_golden_test.dart'),
      precisionTolerance: precisionTolerance,
    );
  }
  final output = Platform.environment['MOMCOZY_UI_INVENTORY_DIR'];
  if (output != null && output.isNotEmpty) {
    installUiInventoryCapture(Directory(output));
  }
  await testMain();
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
