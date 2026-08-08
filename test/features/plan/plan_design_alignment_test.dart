import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  const cases = [
    _AlignmentCase(
      name: 'empty',
      sourcePath: 'MomcozyAI主要页面0806/plan-empty-state-deeprose@2x.png',
      goldenPath: 'test/goldens/plan/empty_design_2x.png',
      sourceCrop: _ImageRect(0, 0, 780, 2556),
      logicalHeight: 1278,
      referenceTop: 44,
      comparisonHeight: 1140,
      maxMeanAbsoluteError: 7.5,
      maxSignificantDifferenceRatio: 0.05,
      // Product-approved simplification: the Service chat action and the
      // duplicate assistant card no longer follow the original 0806 export.
      ignoredRegions: [
        _ImageRect(12, 514, 366, 109),
        _ImageRect(12, 1024, 366, 104),
      ],
      regions: [
        _AlignmentRegion('header', _ImageRect(0, 0, 390, 70)),
        _AlignmentRegion(
          'week strip',
          _ImageRect(12, 86, 366, 64),
          maxMeanAbsoluteError: 13,
        ),
        _AlignmentRegion('empty hero', _ImageRect(12, 175, 366, 270)),
        _AlignmentRegion(
          'create button',
          _ImageRect(12, 450, 366, 66),
          maxMeanAbsoluteError: 9,
        ),
        _AlignmentRegion(
          'service cards',
          _ImageRect(0, 617, 390, 400),
          maxMeanAbsoluteError: 10,
        ),
      ],
    ),
    _AlignmentCase(
      name: 'multi-category',
      sourcePath: 'MomcozyAI主要页面0806/plan-multi-category-week-deeprose@2x.png',
      goldenPath: 'test/goldens/plan/multi_category_design_2x.png',
      sourceCrop: _ImageRect(64, 0, 780, 1688),
      logicalHeight: 844,
      referenceTop: 44,
      comparisonHeight: 683,
      maxMeanAbsoluteError: 6.5,
      maxSignificantDifferenceRatio: 0.05,
      regions: [
        _AlignmentRegion('header', _ImageRect(0, 0, 390, 66)),
        _AlignmentRegion('plan controls', _ImageRect(12, 70, 366, 128)),
        _AlignmentRegion(
          'week strip',
          _ImageRect(12, 200, 366, 88),
          maxMeanAbsoluteError: 13,
        ),
        _AlignmentRegion('sessions', _ImageRect(12, 294, 366, 228)),
        _AlignmentRegion('week summary', _ImageRect(12, 537, 366, 129)),
      ],
    ),
    _AlignmentCase(
      name: 'single-category',
      sourcePath: 'MomcozyAI主要页面0806/plan-single-category-deeprose@2x.png',
      goldenPath: 'test/goldens/plan/single_category_design_2x.png',
      sourceCrop: _ImageRect(64, 0, 780, 2454),
      logicalHeight: 1227,
      referenceTop: 44,
      comparisonHeight: 1060,
      maxMeanAbsoluteError: 6.5,
      maxSignificantDifferenceRatio: 0.05,
      regions: [
        _AlignmentRegion(
          'header',
          _ImageRect(0, 0, 390, 62),
          maxMeanAbsoluteError: 10,
        ),
        _AlignmentRegion('milestone', _ImageRect(12, 74, 366, 124)),
        _AlignmentRegion('week strip', _ImageRect(12, 202, 366, 82)),
        _AlignmentRegion('sessions', _ImageRect(12, 294, 366, 375)),
        _AlignmentRegion(
          'volume',
          _ImageRect(12, 679, 366, 138),
          maxMeanAbsoluteError: 11.5,
        ),
        _AlignmentRegion('settings', _ImageRect(12, 827, 366, 233)),
      ],
    ),
  ];

  for (final alignmentCase in cases) {
    test('${alignmentCase.name} stays aligned with the 0806 design', () {
      final source = _decode(alignmentCase.sourcePath);
      final sourceCrop = alignmentCase.sourceCrop;
      final screen = image.copyResize(
        image.copyCrop(
          source,
          x: sourceCrop.x,
          y: sourceCrop.y,
          width: sourceCrop.width,
          height: sourceCrop.height,
        ),
        width: 390,
        height: alignmentCase.logicalHeight,
        interpolation: image.Interpolation.cubic,
      );
      final reference = image.copyCrop(
        screen,
        x: 0,
        y: alignmentCase.referenceTop,
        width: 390,
        height: alignmentCase.comparisonHeight,
      );
      image.fillRect(
        reference,
        x1: 0,
        y1: 0,
        x2: 389,
        y2: 10,
        color: image.ColorRgb8(0xfb, 0xf5, 0xf3),
      );
      final rendered = image.copyCrop(
        _decode(alignmentCase.goldenPath),
        x: 0,
        y: 0,
        width: 390,
        height: alignmentCase.comparisonHeight,
      );
      _maskApprovedDifferences(
        reference,
        rendered,
        alignmentCase.ignoredRegions,
      );

      final rawDifference = _measureDifference(reference, rendered);
      final difference = _measurePerceptualDifference(reference, rendered);
      final report = <String>[
        'overall raw: MAE ${rawDifference.meanAbsoluteError.toStringAsFixed(3)}, '
            '>20 ${(rawDifference.significantDifferenceRatio * 100).toStringAsFixed(2)}%',
        'overall perceptual: MAE ${difference.meanAbsoluteError.toStringAsFixed(3)}, '
            '>40 ${(difference.significantDifferenceRatio * 100).toStringAsFixed(2)}%',
      ];
      final failures = <String>[];
      if (difference.meanAbsoluteError > alignmentCase.maxMeanAbsoluteError) {
        failures.add('overall MAE');
      }
      if (difference.significantDifferenceRatio >
          alignmentCase.maxSignificantDifferenceRatio) {
        failures.add('overall significant-pixel ratio');
      }

      for (final region in alignmentCase.regions) {
        final regionReference = _crop(reference, region.rect);
        final regionRendered = _crop(rendered, region.rect);
        final regionDifference = _measurePerceptualDifference(
          regionReference,
          regionRendered,
        );
        report.add(
          '${region.name}: MAE '
          '${regionDifference.meanAbsoluteError.toStringAsFixed(3)}',
        );
        if (regionDifference.meanAbsoluteError > region.maxMeanAbsoluteError) {
          failures.add('${region.name} MAE');
        }
      }
      expect(
        failures,
        isEmpty,
        reason:
            '${alignmentCase.name} exceeded design-parity limits in '
            '${failures.join(', ')}.\n${report.join('\n')}',
      );
    });
  }

  const componentCases = [
    _ComponentAlignmentCase(
      name: 'empty header',
      sourcePath: 'MomcozyAI切图0806/Header-3.png',
      renderedPath: 'test/goldens/plan/empty_design_2x.png',
      renderedRect: _ImageRect(0, 22, 390, 48),
      maxMeanAbsoluteError: 8,
    ),
    _ComponentAlignmentCase(
      name: 'multi-category header',
      sourcePath: 'MomcozyAI切图0806/Header-4.png',
      renderedPath: 'test/goldens/plan/multi_category_design_2x.png',
      renderedRect: _ImageRect(0, 18, 390, 48),
      maxMeanAbsoluteError: 8,
    ),
    _ComponentAlignmentCase(
      name: 'single-category header',
      sourcePath: 'MomcozyAI切图0806/Header-2.png',
      renderedPath: 'test/goldens/plan/single_category_design_2x.png',
      renderedRect: _ImageRect(0, 18, 390, 44),
      maxMeanAbsoluteError: 13,
    ),
    _ComponentAlignmentCase(
      name: 'multi-category week calendar',
      sourcePath: 'MomcozyAI切图0806/WeekCalendarStrip.png',
      renderedPath: 'test/goldens/plan/multi_category_design_2x.png',
      renderedRect: _ImageRect(17, 205, 356, 80),
      maxMeanAbsoluteError: 8,
    ),
    _ComponentAlignmentCase(
      name: 'multi-category completed session',
      sourcePath: 'MomcozyAI切图0806/SessionCard.png',
      renderedPath: 'test/goldens/plan/multi_category_design_2x.png',
      renderedRect: _ImageRect(18, 329, 354, 59),
      maxMeanAbsoluteError: 7,
    ),
    _ComponentAlignmentCase(
      name: 'multi-category week summary',
      sourcePath: 'MomcozyAI切图0806/WeekSummaryCard.png',
      renderedPath: 'test/goldens/plan/multi_category_design_2x.png',
      renderedRect: _ImageRect(18, 569, 354, 94),
      maxMeanAbsoluteError: 8,
    ),
    _ComponentAlignmentCase(
      name: 'empty service cards',
      sourcePath: 'MomcozyAI切图0806/ServiceCardsStack.png',
      renderedPath: 'test/goldens/plan/empty_design_2x.png',
      renderedRect: _ImageRect(6, 612, 378, 413),
      maxMeanAbsoluteError: 11,
    ),
  ];

  for (final componentCase in componentCases) {
    test('${componentCase.name} matches its exported 0806 component', () {
      final rect = componentCase.renderedRect;
      final reference = image.copyResize(
        _flatten(
          _decode(componentCase.sourcePath),
          const _RgbColor(0xfb, 0xf5, 0xf3),
        ),
        width: rect.width,
        height: rect.height,
        interpolation: image.Interpolation.cubic,
      );
      final rendered = _crop(_decode(componentCase.renderedPath), rect);
      final difference = _measurePerceptualDifference(reference, rendered);
      expect(
        difference.meanAbsoluteError,
        lessThanOrEqualTo(componentCase.maxMeanAbsoluteError),
        reason:
            '${componentCase.name} perceptual MAE '
            '${difference.meanAbsoluteError.toStringAsFixed(3)} exceeded '
            '${componentCase.maxMeanAbsoluteError.toStringAsFixed(1)}',
      );
      expect(
        difference.significantDifferenceRatio,
        lessThanOrEqualTo(0.10),
        reason:
            '${componentCase.name} material-difference ratio '
            '${(difference.significantDifferenceRatio * 100).toStringAsFixed(2)}% '
            'exceeded 10.0%',
      );
    });
  }

  test('Plan bottom navigation stays aligned with the 0806 design', () {
    final source = _flatten(
      _decode('MomcozyAI切图0806/BottomTabBar-2.png'),
      const _RgbColor(0xfb, 0xf5, 0xf3),
    );
    final reference = image.copyResize(
      image.copyCrop(source, x: 0, y: 0, width: 780, height: 168),
      width: 390,
      height: 84,
      interpolation: image.Interpolation.cubic,
    );
    final renderedScreen = _decode(
      'test/goldens/component_parity/bottom_nav_plan_selected.png',
    );
    final rendered = image.copyCrop(
      renderedScreen,
      x: 0,
      y: renderedScreen.height - 84,
      width: 390,
      height: 84,
    );
    // Product-approved Plan navigation keeps the Cozymate avatar but hides
    // its label, so only that center slot intentionally differs from 0806.
    _maskApprovedDifferences(reference, rendered, const [
      _ImageRect(156, 0, 78, 84),
    ]);

    final difference = _measurePerceptualDifference(reference, rendered);
    expect(
      difference.meanAbsoluteError,
      lessThanOrEqualTo(6.5),
      reason:
          'bottom navigation mean RGB error '
          '${difference.meanAbsoluteError.toStringAsFixed(3)} exceeded 6.5',
    );
    expect(
      difference.significantDifferenceRatio,
      lessThanOrEqualTo(0.05),
      reason:
          'bottom navigation significant RGB error '
          '${(difference.significantDifferenceRatio * 100).toStringAsFixed(2)}% '
          'exceeded 5.0%',
    );
  });
}

image.Image _decode(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing image: $path');
  final decoded = image.decodePng(file.readAsBytesSync());
  expect(decoded, isNotNull, reason: 'Unable to decode image: $path');
  return decoded!;
}

image.Image _crop(image.Image source, _ImageRect rect) => image.copyCrop(
  source,
  x: rect.x,
  y: rect.y,
  width: rect.width,
  height: rect.height,
);

void _maskApprovedDifferences(
  image.Image reference,
  image.Image rendered,
  List<_ImageRect> regions,
) {
  final background = image.ColorRgb8(0xfb, 0xf5, 0xf3);
  for (final rect in regions) {
    image.fillRect(
      reference,
      x1: rect.x,
      y1: rect.y,
      x2: rect.x + rect.width - 1,
      y2: rect.y + rect.height - 1,
      color: background,
    );
    image.fillRect(
      rendered,
      x1: rect.x,
      y1: rect.y,
      x2: rect.x + rect.width - 1,
      y2: rect.y + rect.height - 1,
      color: background,
    );
  }
}

image.Image _flatten(image.Image source, _RgbColor background) {
  final result = image.Image(width: source.width, height: source.height);
  for (var y = 0; y < source.height; y += 1) {
    for (var x = 0; x < source.width; x += 1) {
      final pixel = source.getPixel(x, y);
      final alpha = pixel.a / 255;
      result.setPixelRgb(
        x,
        y,
        (pixel.r * alpha + background.r * (1 - alpha)).round(),
        (pixel.g * alpha + background.g * (1 - alpha)).round(),
        (pixel.b * alpha + background.b * (1 - alpha)).round(),
      );
    }
  }
  return result;
}

_ImageDifference _measureDifference(
  image.Image left,
  image.Image right, {
  double significantThreshold = 20,
}) {
  expect(right.width, left.width);
  expect(right.height, left.height);

  var difference = 0.0;
  var significantPixels = 0;
  for (var y = 0; y < left.height; y += 1) {
    for (var x = 0; x < left.width; x += 1) {
      final leftPixel = left.getPixel(x, y);
      final rightPixel = right.getPixel(x, y);
      final pixelDifference =
          ((leftPixel.r - rightPixel.r).abs() +
              (leftPixel.g - rightPixel.g).abs() +
              (leftPixel.b - rightPixel.b).abs()) /
          3;
      difference += pixelDifference;
      if (pixelDifference > significantThreshold) significantPixels += 1;
    }
  }
  final pixelCount = left.width * left.height;
  return _ImageDifference(
    meanAbsoluteError: difference / pixelCount,
    significantDifferenceRatio: significantPixels / pixelCount,
  );
}

_ImageDifference _measurePerceptualDifference(
  image.Image left,
  image.Image right,
) => _measureDifference(
  image.gaussianBlur(image.Image.from(left), radius: 1),
  image.gaussianBlur(image.Image.from(right), radius: 1),
  significantThreshold: 40,
);

class _AlignmentCase {
  const _AlignmentCase({
    required this.name,
    required this.sourcePath,
    required this.goldenPath,
    required this.sourceCrop,
    required this.logicalHeight,
    required this.referenceTop,
    required this.comparisonHeight,
    required this.maxMeanAbsoluteError,
    required this.maxSignificantDifferenceRatio,
    required this.regions,
    this.ignoredRegions = const [],
  });

  final String name;
  final String sourcePath;
  final String goldenPath;
  final _ImageRect sourceCrop;
  final int logicalHeight;
  final int referenceTop;
  final int comparisonHeight;
  final double maxMeanAbsoluteError;
  final double maxSignificantDifferenceRatio;
  final List<_AlignmentRegion> regions;
  final List<_ImageRect> ignoredRegions;
}

class _AlignmentRegion {
  const _AlignmentRegion(this.name, this.rect, {this.maxMeanAbsoluteError = 8});

  final String name;
  final _ImageRect rect;
  final double maxMeanAbsoluteError;
}

class _ComponentAlignmentCase {
  const _ComponentAlignmentCase({
    required this.name,
    required this.sourcePath,
    required this.renderedPath,
    required this.renderedRect,
    required this.maxMeanAbsoluteError,
  });

  final String name;
  final String sourcePath;
  final String renderedPath;
  final _ImageRect renderedRect;
  final double maxMeanAbsoluteError;
}

class _ImageDifference {
  const _ImageDifference({
    required this.meanAbsoluteError,
    required this.significantDifferenceRatio,
  });

  final double meanAbsoluteError;
  final double significantDifferenceRatio;
}

class _RgbColor {
  const _RgbColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

class _ImageRect {
  const _ImageRect(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;
}
