import 'package:flutter/material.dart';

import '../controller.dart';
import 'color_scale.dart';
import 'style.dart';

typedef TreemapValueFormatter<K> =
    String Function(TreemapNodeDetails<K> details);
typedef TreemapLocalizedValueFormatter<K> =
    String Function(TreemapNodeDetails<K> details, Locale locale);

/// Resolves a canvas label color from the tile appearance.
typedef TreemapLabelColorResolver =
    Color Function(TreemapAppearance appearance);

/// Builds arbitrary styled lines for the optimized canvas label renderer.
typedef TreemapCanvasLabelLinesBuilder<K> =
    Iterable<TreemapCanvasLabelLine> Function(
      TreemapNodeDetails<K> details,
      TreemapAppearance appearance,
      Locale? locale,
    );

/// One styled text line painted by the canvas label implementation.
final class TreemapCanvasLabelLine {
  const TreemapCanvasLabelLine({required this.text, required this.style});

  /// Text painted for this line.
  final String text;

  /// Complete style used to lay out and paint this line.
  final TextStyle style;
}

Color _contrastingTreemapLabelColor(TreemapAppearance appearance) =>
    treemapContrastingTextColor(appearance.color ?? const Color(0x00000000));

/// Configures text produced and painted by the canvas label implementation.
final class TreemapLabelConfig<K> {
  const TreemapLabelConfig({
    this.showTitle = true,
    this.showValue = true,
    this.titleFormatter,
    this.valueFormatter,
    this.localizedValueFormatter,
    this.fallbackTitle = 'Other',
    this.weightFractionDigits = 2,
    this.titleStyle = const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
    ),
    this.valueStyle = const TextStyle(fontSize: 11),
    this.valueColorOpacity = .82,
    this.colorResolver = _contrastingTreemapLabelColor,
    this.linesBuilder,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.ellipsis = '...',
    this.alignment = Alignment.topLeft,
    this.textDirection,
  }) : assert(weightFractionDigits >= 0),
       assert(valueColorOpacity >= 0 && valueColorOpacity <= 1),
       assert(maxLines > 0),
       assert(ellipsis.length > 0);

  final bool showTitle;
  final bool showValue;
  final TreemapValueFormatter<K>? titleFormatter;
  final TreemapValueFormatter<K>? valueFormatter;
  final TreemapLocalizedValueFormatter<K>? localizedValueFormatter;

  /// Title used when neither the node nor its key supplies one.
  final String fallbackTitle;

  /// Decimal places used by the built-in weight formatter for non-integers.
  final int weightFractionDigits;

  /// Base title style used when the resolved tile appearance has no override.
  final TextStyle titleStyle;

  /// Base value style used when the resolved tile appearance has no override.
  final TextStyle valueStyle;

  /// Opacity applied to the resolved value color when [valueStyle] has none.
  final double valueColorOpacity;

  /// Resolves the title and value base color from node and tile appearance.
  final TreemapLabelColorResolver colorResolver;

  /// Replaces built-in title/value line construction while retaining the
  /// optimized canvas renderer, clipping, ellipsis, alignment, and cache.
  final TreemapCanvasLabelLinesBuilder<K>? linesBuilder;

  final int maxLines;
  final TextOverflow overflow;

  /// Text appended when [overflow] is [TextOverflow.ellipsis].
  final String ellipsis;
  final Alignment alignment;
  final TextDirection? textDirection;

  TreemapLabelConfig<K> copyWith({
    bool? showTitle,
    bool? showValue,
    TreemapValueFormatter<K>? titleFormatter,
    TreemapValueFormatter<K>? valueFormatter,
    TreemapLocalizedValueFormatter<K>? localizedValueFormatter,
    String? fallbackTitle,
    int? weightFractionDigits,
    TextStyle? titleStyle,
    TextStyle? valueStyle,
    double? valueColorOpacity,
    TreemapLabelColorResolver? colorResolver,
    TreemapCanvasLabelLinesBuilder<K>? linesBuilder,
    int? maxLines,
    TextOverflow? overflow,
    String? ellipsis,
    Alignment? alignment,
    TextDirection? textDirection,
  }) => TreemapLabelConfig<K>(
    showTitle: showTitle ?? this.showTitle,
    showValue: showValue ?? this.showValue,
    titleFormatter: titleFormatter ?? this.titleFormatter,
    valueFormatter: valueFormatter ?? this.valueFormatter,
    localizedValueFormatter:
        localizedValueFormatter ?? this.localizedValueFormatter,
    fallbackTitle: fallbackTitle ?? this.fallbackTitle,
    weightFractionDigits: weightFractionDigits ?? this.weightFractionDigits,
    titleStyle: titleStyle ?? this.titleStyle,
    valueStyle: valueStyle ?? this.valueStyle,
    valueColorOpacity: valueColorOpacity ?? this.valueColorOpacity,
    colorResolver: colorResolver ?? this.colorResolver,
    linesBuilder: linesBuilder ?? this.linesBuilder,
    maxLines: maxLines ?? this.maxLines,
    overflow: overflow ?? this.overflow,
    ellipsis: ellipsis ?? this.ellipsis,
    alignment: alignment ?? this.alignment,
    textDirection: textDirection ?? this.textDirection,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapLabelConfig<K> &&
      showTitle == other.showTitle &&
      showValue == other.showValue &&
      titleFormatter == other.titleFormatter &&
      valueFormatter == other.valueFormatter &&
      localizedValueFormatter == other.localizedValueFormatter &&
      fallbackTitle == other.fallbackTitle &&
      weightFractionDigits == other.weightFractionDigits &&
      titleStyle == other.titleStyle &&
      valueStyle == other.valueStyle &&
      valueColorOpacity == other.valueColorOpacity &&
      colorResolver == other.colorResolver &&
      linesBuilder == other.linesBuilder &&
      maxLines == other.maxLines &&
      overflow == other.overflow &&
      ellipsis == other.ellipsis &&
      alignment == other.alignment &&
      textDirection == other.textDirection;

  @override
  int get hashCode => Object.hash(
    showTitle,
    showValue,
    titleFormatter,
    valueFormatter,
    localizedValueFormatter,
    fallbackTitle,
    weightFractionDigits,
    titleStyle,
    valueStyle,
    valueColorOpacity,
    colorResolver,
    linesBuilder,
    maxLines,
    overflow,
    ellipsis,
    alignment,
    textDirection,
  );

  /// Resolves the lines painted for one visible leaf.
  List<TreemapCanvasLabelLine> resolveLines(
    TreemapNodeDetails<K> details,
    TreemapAppearance appearance,
    Locale? locale,
  ) {
    final customLines = linesBuilder?.call(details, appearance, locale);
    if (customLines != null) return List.unmodifiable(customLines);

    final fallbackLabel = details.key.sourceKey?.toString() ?? fallbackTitle;
    final title =
        titleFormatter?.call(details) ?? details.label ?? fallbackLabel;
    final localizedFormatter = localizedValueFormatter;
    final value = localizedFormatter != null
        ? localizedFormatter(details, locale!)
        : valueFormatter?.call(details) ??
              details.node?.valueLabel ??
              details.weight.toStringAsFixed(
                details.weight.truncateToDouble() == details.weight
                    ? 0
                    : weightFractionDigits,
              );
    final baseColor = colorResolver(appearance);
    return [
      if (showTitle && title.isNotEmpty)
        TreemapCanvasLabelLine(
          text: title,
          style: _withFallbackTextColor(
            appearance.titleStyle ?? titleStyle,
            baseColor,
          ),
        ),
      if (showValue && value.isNotEmpty)
        TreemapCanvasLabelLine(
          text: value,
          style: _withFallbackTextColor(
            appearance.valueStyle ?? valueStyle,
            baseColor.withValues(alpha: valueColorOpacity),
          ),
        ),
    ];
  }
}

TextStyle _withFallbackTextColor(TextStyle style, Color fallback) =>
    style.color != null || style.foreground != null
    ? style
    : style.copyWith(color: fallback);
