import 'package:flutter/material.dart';

import '../controller.dart';
import '../presentation/state.dart';
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
/// The fourth argument contains resolved base/state/per-node typography. Both
/// styles are populated; the callback owns its returned styles and colors.
typedef TreemapCanvasLabelLinesBuilder<K> =
    Iterable<TreemapCanvasLabelLine> Function(
      TreemapNodeDetails<K> details,
      TreemapAppearance appearance,
      Locale? locale,
      TreemapLabelStyle styles,
    );

const _unchangedLabelStyle = Object();

/// Optional title and value overrides. Each supplied style replaces the whole
/// preceding style; null leaves that part unchanged during resolution.
@immutable
final class TreemapLabelStyle {
  const TreemapLabelStyle({this.titleStyle, this.valueStyle});

  final TextStyle? titleStyle;
  final TextStyle? valueStyle;

  /// Omitted arguments are preserved; explicit null clears an override.
  TreemapLabelStyle copyWith({
    Object? titleStyle = _unchangedLabelStyle,
    Object? valueStyle = _unchangedLabelStyle,
  }) => TreemapLabelStyle(
    titleStyle: identical(titleStyle, _unchangedLabelStyle)
        ? this.titleStyle
        : titleStyle as TextStyle?,
    valueStyle: identical(valueStyle, _unchangedLabelStyle)
        ? this.valueStyle
        : valueStyle as TextStyle?,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapLabelStyle &&
      titleStyle == other.titleStyle &&
      valueStyle == other.valueStyle;

  @override
  int get hashCode => Object.hash(titleStyle, valueStyle);
}

/// Final rendering-only label overrides, after hover, selection and focus.
typedef TreemapLabelStyleResolver<K> =
    TreemapLabelStyle? Function(
      BuildContext context,
      TreemapNodeDetails<K> details,
      Set<TreemapVisualState> states,
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

/// Shared label configuration for canvas labels and custom widget builders.
///
/// Canvas labels apply formatting and text policies directly. Widget labels
/// use the styles, [padding], [spacing] and [textDirection] for header sizing;
/// builders own their content and apply these settings themselves.
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
    this.hoverStyle,
    this.selectedStyle,
    this.focusedStyle,
    this.nodeStyleResolver,
    this.padding = EdgeInsets.zero,
    this.spacing = 0,
    this.valueColorOpacity = .82,
    this.colorResolver = _contrastingTreemapLabelColor,
    this.linesBuilder,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.ellipsis = '...',
    this.alignment = Alignment.topLeft,
    this.textDirection,
  }) : assert(weightFractionDigits >= 0),
       assert(spacing >= 0 && spacing < double.infinity),
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

  /// Base title style and nominal title metrics for automatic parent headers.
  final TextStyle titleStyle;

  /// Base value style and nominal value metrics for automatic parent headers.
  final TextStyle valueStyle;

  /// Rendering-only hover overrides; automatic header metrics use base styles.
  final TreemapLabelStyle? hoverStyle;

  /// Rendering-only selection overrides, applied after [hoverStyle].
  final TreemapLabelStyle? selectedStyle;

  /// Rendering-only keyboard focus overrides, applied after [selectedStyle].
  final TreemapLabelStyle? focusedStyle;

  /// Final rendering-only overrides. Never invoked during header measurement.
  final TreemapLabelStyleResolver<K>? nodeStyleResolver;

  /// Insets for child labels and parent headers, in logical pixels.
  ///
  /// Defaults to zero and is independent of text scaling and layout padding.
  /// Canvas labels apply this to standard and custom lines. Widget builders
  /// apply it themselves. Automatic headers include [EdgeInsets.vertical];
  /// an explicit parent height already includes this padding.
  final EdgeInsets padding;

  /// Gap between nonempty standard title and value blocks, in logical pixels.
  ///
  /// Shared by ordinary labels and parent headers; unaffected by text scaling.
  /// Custom canvas [linesBuilder] output keeps its own layout and ignores this
  /// value. Widget builders insert their own spacer using this same setting.
  final double spacing;

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

  /// Copies settings. Explicit null clears any of the four style override
  /// fields; omitting those arguments preserves their current values.
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
    Object? hoverStyle = _unchangedLabelStyle,
    Object? selectedStyle = _unchangedLabelStyle,
    Object? focusedStyle = _unchangedLabelStyle,
    Object? nodeStyleResolver = _unchangedLabelStyle,
    EdgeInsets? padding,
    double? spacing,
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
    hoverStyle: identical(hoverStyle, _unchangedLabelStyle)
        ? this.hoverStyle
        : hoverStyle as TreemapLabelStyle?,
    selectedStyle: identical(selectedStyle, _unchangedLabelStyle)
        ? this.selectedStyle
        : selectedStyle as TreemapLabelStyle?,
    focusedStyle: identical(focusedStyle, _unchangedLabelStyle)
        ? this.focusedStyle
        : focusedStyle as TreemapLabelStyle?,
    nodeStyleResolver: identical(nodeStyleResolver, _unchangedLabelStyle)
        ? this.nodeStyleResolver
        : nodeStyleResolver as TreemapLabelStyleResolver<K>?,
    padding: padding ?? this.padding,
    spacing: spacing ?? this.spacing,
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
      hoverStyle == other.hoverStyle &&
      selectedStyle == other.selectedStyle &&
      focusedStyle == other.focusedStyle &&
      nodeStyleResolver == other.nodeStyleResolver &&
      padding == other.padding &&
      spacing == other.spacing &&
      valueColorOpacity == other.valueColorOpacity &&
      colorResolver == other.colorResolver &&
      linesBuilder == other.linesBuilder &&
      maxLines == other.maxLines &&
      overflow == other.overflow &&
      ellipsis == other.ellipsis &&
      alignment == other.alignment &&
      textDirection == other.textDirection;

  @override
  int get hashCode => Object.hashAll([
    showTitle,
    showValue,
    titleFormatter,
    valueFormatter,
    localizedValueFormatter,
    fallbackTitle,
    weightFractionDigits,
    titleStyle,
    valueStyle,
    hoverStyle,
    selectedStyle,
    focusedStyle,
    nodeStyleResolver,
    padding,
    spacing,
    valueColorOpacity,
    colorResolver,
    linesBuilder,
    maxLines,
    overflow,
    ellipsis,
    alignment,
    textDirection,
  ]);

  /// Resolves base → hovered → selected → focused → per-node typography.
  ///
  /// Both returned styles are populated. A nonnull override replaces the whole
  /// preceding TextStyle. This does not apply contrast colors or value opacity.
  /// Widget builders may call this during building, never during measurement.
  TreemapLabelStyle resolveStyles(
    BuildContext context,
    TreemapNodeDetails<K> details,
    Set<TreemapVisualState> states,
  ) {
    var title = titleStyle;
    var value = valueStyle;
    void apply(TreemapLabelStyle? override) {
      title = override?.titleStyle ?? title;
      value = override?.valueStyle ?? value;
    }

    if (states.contains(TreemapVisualState.hovered)) apply(hoverStyle);
    if (states.contains(TreemapVisualState.selected)) apply(selectedStyle);
    if (states.contains(TreemapVisualState.focused)) apply(focusedStyle);
    apply(nodeStyleResolver?.call(context, details, states));
    return TreemapLabelStyle(titleStyle: title, valueStyle: value);
  }

  /// Resolves lines for a label region using [resolveStyles] output.
  List<TreemapCanvasLabelLine> resolveLines(
    TreemapNodeDetails<K> details,
    TreemapAppearance appearance,
    Locale? locale, {
    required TreemapLabelStyle styles,
  }) {
    final customLines = linesBuilder?.call(details, appearance, locale, styles);
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
          style: _withFallbackTextColor(styles.titleStyle!, baseColor),
        ),
      if (showValue && value.isNotEmpty)
        TreemapCanvasLabelLine(
          text: value,
          style: _withFallbackTextColor(
            styles.valueStyle!,
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
