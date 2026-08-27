import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _toleranceEnvironmentKey = 'MOMCOZY_GOLDEN_PRECISION_TOLERANCE';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previousComparator = goldenFileComparator;
  try {
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
    await testMain();
  } finally {
    goldenFileComparator = previousComparator;
  }
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
