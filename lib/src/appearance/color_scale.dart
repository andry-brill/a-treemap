import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Describes one discrete value, range, or stop exposed by a color scale.
final class TreemapLegendEntry {
  const TreemapLegendEntry({
    required this.label,
    required this.color,
    this.value,
    this.minimum,
    this.maximum,
  });

  final String label;
  final Color color;
  final Object? value;
  final double? minimum;
  final double? maximum;
}

/// Maps caller-provided color values to explicit colors and legend entries.
abstract class TreemapColorScale {
  const TreemapColorScale();

  factory TreemapColorScale.exact(
    Map<Object?, Color> colors, {
    Map<Object?, String> labels = const {},
    required Color fallback,
  }) => TreemapExactColorScale(colors, labels: labels, fallback: fallback);

  factory TreemapColorScale.categorical(
    List<Color> colors, {
    List<String> labels = const [],
    required Color fallback,
  }) =>
      TreemapCategoricalColorScale(colors, labels: labels, fallback: fallback);

  factory TreemapColorScale.numericRange(
    List<TreemapNumericColorRange> ranges, {
    required Color fallback,
  }) => TreemapNumericRangeColorScale(ranges, fallback: fallback);

  factory TreemapColorScale.interpolated({
    required double minimum,
    required double maximum,
    required List<Color> colors,
    required Color fallback,
    TreemapContinuousLegendLabelFormatter labelFormatter =
        _oneFractionLegendLabel,
  }) => TreemapInterpolatedColorScale(
    minimum: minimum,
    maximum: maximum,
    colors: colors,
    fallback: fallback,
    labelFormatter: labelFormatter,
  );

  factory TreemapColorScale.saturation({
    required double minimum,
    required double maximum,
    required Color color,
    double minimumSaturation = .15,
    double maximumSaturation = 1,
    required Color fallback,
    TreemapContinuousLegendLabelFormatter labelFormatter = _plainLegendLabel,
  }) => TreemapSaturationColorScale(
    minimum: minimum,
    maximum: maximum,
    color: color,
    minimumSaturation: minimumSaturation,
    maximumSaturation: maximumSaturation,
    fallback: fallback,
    labelFormatter: labelFormatter,
  );

  Color colorFor(Object? value);
  List<TreemapLegendEntry> get legendEntries;
  bool get isContinuous => false;
  double? get minimum => null;
  double? get maximum => null;
}

/// Formats numeric color-scale stops for legend labels.
typedef TreemapContinuousLegendLabelFormatter = String Function(double value);

String _oneFractionLegendLabel(double value) => value.toStringAsFixed(1);

String _plainLegendLabel(double value) => value.toString();

/// Resolves values through an exact value-to-color map.
final class TreemapExactColorScale extends TreemapColorScale {
  TreemapExactColorScale(
    Map<Object?, Color> colors, {
    Map<Object?, String> labels = const {},
    required this.fallback,
  }) : colors = UnmodifiableMapView(Map.of(colors)),
       labels = UnmodifiableMapView(Map.of(labels));

  final Map<Object?, Color> colors;
  final Map<Object?, String> labels;
  final Color fallback;

  @override
  Color colorFor(Object? value) => colors[value] ?? fallback;

  @override
  List<TreemapLegendEntry> get legendEntries => List.unmodifiable(
    colors.entries.map(
      (entry) => TreemapLegendEntry(
        label: labels[entry.key] ?? entry.key.toString(),
        color: entry.value,
        value: entry.key,
      ),
    ),
  );
}

/// Deterministically distributes non-null values across a color palette.
final class TreemapCategoricalColorScale extends TreemapColorScale {
  TreemapCategoricalColorScale(
    List<Color> colors, {
    List<String> labels = const [],
    required this.fallback,
  }) : colors = List.unmodifiable(colors),
       labels = List.unmodifiable(labels) {
    if (colors.isEmpty) {
      throw ArgumentError.value(colors, 'colors', 'must not be empty');
    }
  }

  final List<Color> colors;
  final List<String> labels;
  final Color fallback;

  @override
  Color colorFor(Object? value) {
    if (value == null) return fallback;
    return colors[value.hashCode.abs() % colors.length];
  }

  @override
  List<TreemapLegendEntry> get legendEntries => List.unmodifiable([
    for (final entry in colors.indexed)
      TreemapLegendEntry(
        label: entry.$1 < labels.length
            ? labels[entry.$1]
            : 'Category ${entry.$1 + 1}',
        color: entry.$2,
        value: entry.$1,
      ),
  ]);
}

/// Defines one numeric interval and its corresponding legend appearance.
final class TreemapNumericColorRange {
  const TreemapNumericColorRange({
    required this.minimum,
    required this.maximum,
    required this.color,
    this.label,
  });

  final double minimum;
  final double maximum;
  final Color color;
  final String? label;
}

/// Assigns colors from ordered, non-overlapping numeric intervals.
final class TreemapNumericRangeColorScale extends TreemapColorScale {
  TreemapNumericRangeColorScale(
    List<TreemapNumericColorRange> ranges, {
    required this.fallback,
  }) : ranges = List.unmodifiable(
         List<TreemapNumericColorRange>.of(ranges)
           ..sort((a, b) => a.minimum.compareTo(b.minimum)),
       ) {
    for (final entry in this.ranges.indexed) {
      final range = entry.$2;
      if (!range.minimum.isFinite ||
          !range.maximum.isFinite ||
          range.maximum < range.minimum) {
        throw ArgumentError('Numeric color ranges must be finite and ordered.');
      }
      if (entry.$1 > 0 && this.ranges[entry.$1 - 1].maximum > range.minimum) {
        throw ArgumentError('Numeric color ranges must not overlap.');
      }
    }
  }

  final List<TreemapNumericColorRange> ranges;
  final Color fallback;

  @override
  Color colorFor(Object? value) {
    if (value is! num || !value.isFinite) return fallback;
    for (final entry in ranges.indexed) {
      final range = entry.$2;
      final last = entry.$1 == ranges.length - 1;
      if (value >= range.minimum &&
          (value < range.maximum || (last && value <= range.maximum))) {
        return range.color;
      }
    }
    return fallback;
  }

  @override
  List<TreemapLegendEntry> get legendEntries => List.unmodifiable(
    ranges.map(
      (range) => TreemapLegendEntry(
        label: range.label ?? '${range.minimum}–${range.maximum}',
        color: range.color,
        minimum: range.minimum,
        maximum: range.maximum,
      ),
    ),
  );

  @override
  double? get minimum => ranges.isEmpty ? null : ranges.first.minimum;
  @override
  double? get maximum => ranges.isEmpty ? null : ranges.last.maximum;
}

/// Interpolates numeric values across two or more color stops.
final class TreemapInterpolatedColorScale extends TreemapColorScale {
  TreemapInterpolatedColorScale({
    required this.minimum,
    required this.maximum,
    required List<Color> colors,
    required this.fallback,
    this.labelFormatter = _oneFractionLegendLabel,
  }) : colors = List.unmodifiable(colors) {
    if (!minimum.isFinite || !maximum.isFinite || maximum <= minimum) {
      throw ArgumentError(
        'Interpolation domain must be finite and increasing.',
      );
    }
    if (colors.length < 2) {
      throw ArgumentError('Interpolated scales require at least two colors.');
    }
  }

  @override
  final double minimum;
  @override
  final double maximum;
  final List<Color> colors;
  final Color fallback;
  final TreemapContinuousLegendLabelFormatter labelFormatter;

  @override
  bool get isContinuous => true;

  @override
  Color colorFor(Object? value) {
    if (value is! num || !value.isFinite) return fallback;
    final t = ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
    final scaled = t * (colors.length - 1);
    final index = scaled.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[index], colors[index + 1], scaled - index)!;
  }

  @override
  List<TreemapLegendEntry> get legendEntries => List.unmodifiable([
    for (final entry in colors.indexed)
      TreemapLegendEntry(
        label: labelFormatter(
          minimum + (maximum - minimum) * entry.$1 / (colors.length - 1),
        ),
        color: entry.$2,
        value: minimum + (maximum - minimum) * entry.$1 / (colors.length - 1),
      ),
  ]);
}

/// Maps numeric values by varying the saturation of a single base color.
final class TreemapSaturationColorScale extends TreemapColorScale {
  TreemapSaturationColorScale({
    required this.minimum,
    required this.maximum,
    required this.color,
    this.minimumSaturation = .15,
    this.maximumSaturation = 1,
    required this.fallback,
    this.labelFormatter = _plainLegendLabel,
  }) {
    if (!minimum.isFinite || !maximum.isFinite || maximum <= minimum) {
      throw ArgumentError('Saturation domain must be finite and increasing.');
    }
    if (minimumSaturation < 0 ||
        maximumSaturation > 1 ||
        minimumSaturation > maximumSaturation) {
      throw ArgumentError('Saturation values must form an ordered 0–1 range.');
    }
  }

  @override
  final double minimum;
  @override
  final double maximum;
  final Color color;
  final double minimumSaturation;
  final double maximumSaturation;
  final Color fallback;
  final TreemapContinuousLegendLabelFormatter labelFormatter;

  @override
  bool get isContinuous => true;

  @override
  Color colorFor(Object? value) {
    if (value is! num || !value.isFinite) return fallback;
    final t = ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(
          minimumSaturation + (maximumSaturation - minimumSaturation) * t,
        )
        .toColor();
  }

  @override
  List<TreemapLegendEntry> get legendEntries => [
    TreemapLegendEntry(
      label: labelFormatter(minimum),
      color: colorFor(minimum),
      value: minimum,
    ),
    TreemapLegendEntry(
      label: labelFormatter(maximum),
      color: colorFor(maximum),
      value: maximum,
    ),
  ];
}

Color treemapContrastingTextColor(Color color) {
  return color.computeLuminance() > .42
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}

double treemapColorFraction(TreemapColorScale scale, Object? value) {
  if (value is! num || scale.minimum == null || scale.maximum == null) return 0;
  return ((value - scale.minimum!) / (scale.maximum! - scale.minimum!)).clamp(
    0.0,
    1.0,
  );
}

List<Color> treemapSampleScale(TreemapColorScale scale, {int count = 32}) {
  final minimum = scale.minimum;
  final maximum = scale.maximum;
  if (minimum == null || maximum == null) {
    return scale.legendEntries.map((entry) => entry.color).toList();
  }
  return [
    for (var index = 0; index < math.max(2, count); index++)
      scale.colorFor(minimum + (maximum - minimum) * index / (count - 1)),
  ];
}
