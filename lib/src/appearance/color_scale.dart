import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Selects the data used to infer a continuous scale's automatic bounds.
enum TreemapColorDomainScope {
  /// All source branches and leaves, excluding the container root.
  global,

  /// All visible target tiles at the current focus and depth, including aggregates.
  visible,
}

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
    double minimum = double.negativeInfinity,
    double maximum = double.infinity,
    TreemapColorDomainScope domainScope = TreemapColorDomainScope.global,
    required List<Color> colors,
    required Color fallback,
    TreemapContinuousLegendLabelFormatter labelFormatter =
        _oneFractionLegendLabel,
  }) => TreemapInterpolatedColorScale(
    minimum: minimum,
    maximum: maximum,
    domainScope: domainScope,
    colors: colors,
    fallback: fallback,
    labelFormatter: labelFormatter,
  );

  factory TreemapColorScale.saturation({
    double minimum = double.negativeInfinity,
    double maximum = double.infinity,
    TreemapColorDomainScope domainScope = TreemapColorDomainScope.global,
    required Color color,
    double minimumSaturation = .15,
    double maximumSaturation = 1,
    required Color fallback,
    TreemapContinuousLegendLabelFormatter labelFormatter = _plainLegendLabel,
  }) => TreemapSaturationColorScale(
    minimum: minimum,
    maximum: maximum,
    domainScope: domainScope,
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
///
/// Omitted bounds are inferred by the chart, or by [resolveDomain] for standalone
/// use. Either bound can independently be fixed to a finite number.
final class TreemapInterpolatedColorScale extends TreemapColorScale {
  TreemapInterpolatedColorScale({
    this.minimum = double.negativeInfinity,
    this.maximum = double.infinity,
    this.domainScope = TreemapColorDomainScope.global,
    required List<Color> colors,
    required this.fallback,
    this.labelFormatter = _oneFractionLegendLabel,
  }) : colors = List.unmodifiable(colors) {
    _validateDomain(minimum, maximum);
    if (colors.length < 2) {
      throw ArgumentError('Interpolated scales require at least two colors.');
    }
  }

  @override
  final double minimum;
  @override
  final double maximum;
  final TreemapColorDomainScope domainScope;
  final List<Color> colors;
  final Color fallback;
  final TreemapContinuousLegendLabelFormatter labelFormatter;

  @override
  bool get isContinuous => true;

  @override
  Color colorFor(Object? value) {
    _requireResolved(this);
    if (value is! num || !value.isFinite) return fallback;
    return _colorAt(_fraction(value, minimum, maximum));
  }

  Color _colorAt(double t) {
    final scaled = t * (colors.length - 1);
    final index = scaled.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[index], colors[index + 1], scaled - index)!;
  }

  @override
  List<TreemapLegendEntry> get legendEntries {
    _requireResolved(this);
    return List.unmodifiable([
      for (final entry in colors.indexed)
        TreemapLegendEntry(
          label: labelFormatter(
            _domainValue(minimum, maximum, entry.$1 / (colors.length - 1)),
          ),
          color: entry.$2,
          value: _domainValue(minimum, maximum, entry.$1 / (colors.length - 1)),
        ),
    ]);
  }
}

/// Maps numeric values by varying the saturation of a single base color.
///
/// Uses the same automatic bound and scope rules as [TreemapInterpolatedColorScale].
final class TreemapSaturationColorScale extends TreemapColorScale {
  TreemapSaturationColorScale({
    this.minimum = double.negativeInfinity,
    this.maximum = double.infinity,
    this.domainScope = TreemapColorDomainScope.global,
    required this.color,
    this.minimumSaturation = .15,
    this.maximumSaturation = 1,
    required this.fallback,
    this.labelFormatter = _plainLegendLabel,
  }) {
    _validateDomain(minimum, maximum);
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
  final TreemapColorDomainScope domainScope;
  final Color color;
  final double minimumSaturation;
  final double maximumSaturation;
  final Color fallback;
  final TreemapContinuousLegendLabelFormatter labelFormatter;

  @override
  bool get isContinuous => true;

  @override
  Color colorFor(Object? value) {
    _requireResolved(this);
    if (value is! num || !value.isFinite) return fallback;
    return _colorAt(_fraction(value, minimum, maximum));
  }

  Color _colorAt(double t) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(
          minimumSaturation + (maximumSaturation - minimumSaturation) * t,
        )
        .toColor();
  }

  @override
  List<TreemapLegendEntry> get legendEntries {
    _requireResolved(this);
    return [
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
}

/// Resolves automatic bounds without mutating the supplied scale.
extension TreemapColorScaleDomainResolution on TreemapColorScale {
  /// Infers each automatic bound from finite numbers in [values].
  ///
  /// Explicit and custom scales are returned unchanged. Charts resolve their
  /// configured scope through the controller; standalone callers supply values
  /// here before reading colors, legend entries, or sampling an automatic scale.
  TreemapColorScale resolveDomain(Iterable<Object?> values) {
    final scale = this;
    final Color fallback;
    final Color Function(double) colorAt;
    final TreemapContinuousLegendLabelFormatter formatter;
    final int stopCount;
    switch (scale) {
      case TreemapInterpolatedColorScale():
        fallback = scale.fallback;
        colorAt = scale._colorAt;
        formatter = scale.labelFormatter;
        stopCount = scale.colors.length;
      case TreemapSaturationColorScale():
        fallback = scale.fallback;
        colorAt = scale._colorAt;
        formatter = scale.labelFormatter;
        stopCount = 2;
      default:
        return scale;
    }
    final autoMinimum = minimum == double.negativeInfinity;
    final autoMaximum = maximum == double.infinity;
    if (!autoMinimum && !autoMaximum) return scale;
    double? low;
    double? high;
    for (final value in values) {
      if (value is! num || !value.isFinite) continue;
      final number = value.toDouble();
      low = low == null ? number : math.min(low, number);
      high = high == null ? number : math.max(high, number);
    }
    if (low != null) {
      low = autoMinimum ? low : minimum!;
      high = autoMaximum ? high! : maximum!;
      if (low > high) {
        if (autoMinimum) {
          low = high;
        } else {
          high = low;
        }
      }
    }
    return _ResolvedContinuousColorScale(
      minimum: low,
      maximum: high,
      fallback: fallback,
      colorAt: colorAt,
      formatter: formatter,
      stopCount: stopCount,
    );
  }
}

final class _ResolvedContinuousColorScale extends TreemapColorScale {
  const _ResolvedContinuousColorScale({
    required this.minimum,
    required this.maximum,
    required this.fallback,
    required this.colorAt,
    required this.formatter,
    required this.stopCount,
  });

  @override
  final double? minimum;
  @override
  final double? maximum;
  final Color fallback;
  final Color Function(double) colorAt;
  final TreemapContinuousLegendLabelFormatter formatter;
  final int stopCount;

  @override
  bool get isContinuous => true;

  @override
  Color colorFor(Object? value) =>
      minimum == null || value is! num || !value.isFinite
      ? fallback
      : colorAt(_fraction(value, minimum!, maximum!));

  @override
  List<TreemapLegendEntry> get legendEntries {
    final low = minimum;
    final high = maximum;
    if (low == null || high == null) return const [];
    final count = low == high ? 1 : stopCount;
    return List.unmodifiable([
      for (var index = 0; index < count; index++)
        TreemapLegendEntry(
          label: formatter(
            _domainValue(low, high, count == 1 ? .5 : index / (count - 1)),
          ),
          color: colorAt(count == 1 ? .5 : index / (count - 1)),
          value: _domainValue(low, high, count == 1 ? .5 : index / (count - 1)),
        ),
    ]);
  }
}

void _validateDomain(double minimum, double maximum) {
  if (minimum.isNaN ||
      maximum.isNaN ||
      minimum == double.infinity ||
      maximum == double.negativeInfinity ||
      (minimum.isFinite && maximum.isFinite && maximum <= minimum)) {
    throw ArgumentError(
      'Color bounds must be finite and increasing, or use negativeInfinity '
      'for an automatic minimum and infinity for an automatic maximum.',
    );
  }
}

void _requireResolved(TreemapColorScale scale) {
  if ((scale is TreemapInterpolatedColorScale ||
          scale is TreemapSaturationColorScale) &&
      (scale.minimum == double.negativeInfinity ||
          scale.maximum == double.infinity)) {
    throw StateError(
      'Automatic color bounds need data. Use presentation.resolveColorScale(scale) '
      'in a chart or scale.resolveDomain(values) before reading colors or legends.',
    );
  }
}

double _fraction(num value, double minimum, double maximum) {
  if (minimum == maximum && value == minimum) return .5;
  if (value <= minimum) return 0;
  if (value >= maximum) return 1;
  final span = maximum - minimum;
  return span.isFinite
      ? ((value - minimum) / span).clamp(0.0, 1.0)
      : ((value / 2 - minimum / 2) / (maximum / 2 - minimum / 2)).clamp(
          0.0,
          1.0,
        );
}

double _domainValue(double minimum, double maximum, double t) {
  if (t == 0) return minimum;
  if (t == 1) return maximum;
  final span = maximum - minimum;
  return span.isFinite ? minimum + span * t : minimum * (1 - t) + maximum * t;
}

Color treemapContrastingTextColor(Color color) {
  return color.computeLuminance() > .42
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);
}

double treemapColorFraction(TreemapColorScale scale, Object? value) {
  _requireResolved(scale);
  if (value is! num ||
      !value.isFinite ||
      scale.minimum == null ||
      scale.maximum == null) {
    return 0;
  }
  return _fraction(value, scale.minimum!, scale.maximum!);
}

List<Color> treemapSampleScale(TreemapColorScale scale, {int count = 32}) {
  _requireResolved(scale);
  final minimum = scale.minimum;
  final maximum = scale.maximum;
  if (minimum == null || maximum == null) {
    return scale.legendEntries.map((entry) => entry.color).toList();
  }
  final samples = math.max(2, count);
  return [
    for (var index = 0; index < samples; index++)
      scale.colorFor(_domainValue(minimum, maximum, index / (samples - 1))),
  ];
}
