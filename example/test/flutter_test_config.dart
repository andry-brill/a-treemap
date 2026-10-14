import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs narrow, per-image tolerances and actionable failure diagnostics.
///
/// Canvas-label goldens select Ahem and disable text antialiasing explicitly.
/// Narrow platform-specific tolerances cover residual glyph-edge and fractional
/// canvas-edge differences between Skia renderers. Unlisted goldens remain
/// pixel-exact.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = _PlatformTolerantGoldenComparator(
    Uri.base.resolve('test/flutter_test_config.dart'),
  );
  await testMain();
}

final class _PlatformTolerantGoldenComparator extends LocalFileComparator {
  _PlatformTolerantGoldenComparator(super.testFile);

  static const _geometryTolerances = <String, double>{
    'default.png': .001,
    'example_hierarchy_palette.png': .001,
    'example_builder_aggregation.png': .001,
    'example_screenshot.png': .001,
    'example_four_origins.png': .001,
    'example_axis_orders.png': .001,
  };

  static double _toleranceFor(String name) {
    final geometryTolerance = _geometryTolerances[name];
    if (geometryTolerance != null) return geometryTolerance;

    // Text layout is deterministic, but each host rasterizes some Ahem glyph
    // edges differently even with antialiasing disabled. Keep this allowance
    // platform-specific and well below the ~1.5% difference caused by labels
    // being missing entirely.
    return switch (name) {
      'default_labels.png' =>
        Platform.isMacOS
            ? .004
            : Platform.isLinux
            ? .003
            : .001,
      'rtl_text_scale.png' =>
        Platform.isMacOS
            ? .005
            : Platform.isLinux
            ? .004
            : .001,
      // This image contains six two-line label blocks. Current macOS Skia
      // rasterization changes about 0.512% of their Ahem glyph-edge pixels,
      // while removing label content changes roughly 1.5% of the image.
      'example_hierarchy_palette_labels.png' =>
        Platform.isMacOS
            ? .0055
            : Platform.isLinux
            ? .004
            : .001,
      _ => 0,
    };
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final tolerance = _toleranceFor(golden.pathSegments.last);

    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    final diagnostics = await _describeDifference(result);
    final actualPercent = (result.diffPercent * 100).toStringAsFixed(3);
    final allowedPercent = (tolerance * 100).toStringAsFixed(3);
    result.dispose();
    throw FlutterError(
      '$error\n'
      'Platform tolerance exceeded: $actualPercent% differs; '
      '$allowedPercent% is allowed for ${golden.pathSegments.last} '
      'on ${Platform.operatingSystem}.\n'
      '$diagnostics',
    );
  }
}

Future<String> _describeDifference(ComparisonResult result) async {
  final images = result.diffs;
  final expected = images?['masterImage'];
  final actual = images?['testImage'];
  if (expected == null || actual == null) {
    return 'Detailed diff unavailable: decoded comparison images are absent.';
  }
  if (expected.width != actual.width || expected.height != actual.height) {
    return 'Image dimensions differ: expected ${expected.width}×${expected.height}, '
        'actual ${actual.width}×${actual.height}.';
  }

  final expectedData = await expected.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  final actualData = await actual.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  if (expectedData == null || actualData == null) {
    return 'Detailed diff unavailable: raw RGBA pixels could not be decoded.';
  }

  final width = expected.width;
  final height = expected.height;
  final mask = Uint8List(width * height);
  final grid = List<int>.filled(9, 0);
  var changed = 0;
  var rgbChanged = 0;
  var alphaChanged = 0;
  var totalChannelDelta = 0;
  var maximumChannelDelta = 0;
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final pixel = y * width + x;
      final offset = pixel * 4;
      var differs = false;
      var rgbDiffers = false;
      var alphaDiffers = false;
      for (var channel = 0; channel < 4; channel++) {
        final delta =
            (expectedData.getUint8(offset + channel) -
                    actualData.getUint8(offset + channel))
                .abs();
        if (delta == 0) continue;
        differs = true;
        rgbDiffers |= channel < 3;
        alphaDiffers |= channel == 3;
        totalChannelDelta += delta;
        if (delta > maximumChannelDelta) maximumChannelDelta = delta;
      }
      if (!differs) continue;

      mask[pixel] = 1;
      changed++;
      if (rgbDiffers) rgbChanged++;
      if (alphaDiffers) alphaChanged++;
      minX = x < minX ? x : minX;
      minY = y < minY ? y : minY;
      maxX = x > maxX ? x : maxX;
      maxY = y > maxY ? y : maxY;
      final gridColumn = (x * 3 ~/ width).clamp(0, 2);
      final gridRow = (y * 3 ~/ height).clamp(0, 2);
      grid[gridRow * 3 + gridColumn]++;
    }
  }

  if (changed == 0) {
    return 'Raw RGBA pixels are identical; the comparator reported a '
        'non-pixel comparison error.';
  }

  final regions = _majorRegions(mask, width, height);
  final meanDelta = totalChannelDelta / (changed * 4);
  final boundsWidth = maxX - minX + 1;
  final boundsHeight = maxY - minY + 1;
  final buffer = StringBuffer()
    ..writeln('Detailed pixel diff ($width×$height):')
    ..writeln(
      '  Changed $changed pixels; RGB changed in $rgbChanged and alpha '
      'changed in $alphaChanged.',
    )
    ..writeln(
      '  Bounding box: x=$minX..$maxX, y=$minY..$maxY '
      '($boundsWidth×$boundsHeight, ${_locationName(minX, minY, maxX, maxY, width, height)}).',
    )
    ..writeln(
      '  Channel delta: mean ${meanDelta.toStringAsFixed(2)} / 255; '
      'maximum $maximumChannelDelta / 255.',
    )
    ..writeln('  Changed pixels by image ninth (left / center / right):')
    ..writeln('    top:    ${grid[0]} / ${grid[1]} / ${grid[2]}')
    ..writeln('    middle: ${grid[3]} / ${grid[4]} / ${grid[5]}')
    ..writeln('    bottom: ${grid[6]} / ${grid[7]} / ${grid[8]}');
  if (regions.isNotEmpty) {
    buffer.writeln('  Largest changed regions (up to 6):');
    for (final region in regions.take(6)) {
      buffer.writeln(
        '    x=${region.left}..${region.right}, '
        'y=${region.top}..${region.bottom}, ${region.width}×${region.height}, '
        '${region.pixels} px (${_locationName(region.left, region.top, region.right, region.bottom, width, height)})',
      );
    }
  }
  return buffer.toString().trimRight();
}

List<_DiffRegion> _majorRegions(Uint8List mask, int width, int height) {
  final rowCounts = List<int>.filled(height, 0);
  for (var y = 0; y < height; y++) {
    final rowOffset = y * width;
    for (var x = 0; x < width; x++) {
      rowCounts[y] += mask[rowOffset + x];
    }
  }

  final regions = <_DiffRegion>[];
  for (final rowSpan in _activeSpans(rowCounts, mergeGap: 3)) {
    final columnCounts = List<int>.filled(width, 0);
    for (var y = rowSpan.start; y <= rowSpan.end; y++) {
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        columnCounts[x] += mask[rowOffset + x];
      }
    }
    for (final columnSpan in _activeSpans(columnCounts, mergeGap: 7)) {
      var pixels = 0;
      for (var y = rowSpan.start; y <= rowSpan.end; y++) {
        final rowOffset = y * width;
        for (var x = columnSpan.start; x <= columnSpan.end; x++) {
          pixels += mask[rowOffset + x];
        }
      }
      regions.add(
        _DiffRegion(
          left: columnSpan.start,
          top: rowSpan.start,
          right: columnSpan.end,
          bottom: rowSpan.end,
          pixels: pixels,
        ),
      );
    }
  }
  regions.sort((a, b) => b.pixels.compareTo(a.pixels));
  return regions;
}

List<_Span> _activeSpans(List<int> counts, {required int mergeGap}) {
  final spans = <_Span>[];
  int? start;
  int? lastActive;
  for (var index = 0; index < counts.length; index++) {
    if (counts[index] == 0) continue;
    if (start == null || index - lastActive! > mergeGap + 1) {
      if (start != null) spans.add(_Span(start, lastActive!));
      start = index;
    }
    lastActive = index;
  }
  if (start != null) spans.add(_Span(start, lastActive!));
  return spans;
}

String _locationName(
  int left,
  int top,
  int right,
  int bottom,
  int width,
  int height,
) {
  final centerX = (left + right) / 2;
  final centerY = (top + bottom) / 2;
  final horizontal = centerX < width / 3
      ? 'left'
      : centerX >= width * 2 / 3
      ? 'right'
      : 'center';
  final vertical = centerY < height / 3
      ? 'top'
      : centerY >= height * 2 / 3
      ? 'bottom'
      : 'middle';
  return '$vertical-$horizontal';
}

final class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;
}

final class _DiffRegion {
  const _DiffRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.pixels,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final int pixels;

  int get width => right - left + 1;
  int get height => bottom - top + 1;
}
