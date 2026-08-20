import 'package:flutter/material.dart';

import '../widgets/legend_bar.dart';
import '../widgets/legend_item.dart';
import '../widgets/legend_pointer.dart';
import '../widgets/overlay_container.dart';
import 'color_scale.dart';
import 'overlay.dart';

/// Identifies the structural presentation used for a legend.
enum TreemapLegendKind {
  /// Shows separate items for categorical values or numeric ranges.
  discrete,

  /// Shows a continuous or segmented color bar.
  bar,
}

/// Builds a legend title from the configured title string.
typedef TreemapLegendTitleBuilder =
    Widget Function(BuildContext context, String title);

/// Builds the label widget used by discrete items and bar endpoints.
typedef TreemapLegendLabelBuilder =
    Widget Function(BuildContext context, TreemapLegendEntry entry);

/// Builds one complete discrete legend item around its resolved label.
///
/// The default builder returns a configurable [TreemapLegendItem].
typedef TreemapLegendItemBuilder =
    Widget Function(
      BuildContext context,
      TreemapLegendEntry entry,
      Widget label,
    );

/// Builds the color bar for sampled colors and the configured axis.
///
/// The default builder returns a configurable [TreemapLegendBar].
typedef TreemapLegendBarBuilder =
    Widget Function(BuildContext context, List<Color> colors, Axis direction);

/// Builds the marker for the current value on a color bar.
///
/// The default builder returns a configurable [TreemapLegendPointer].
typedef TreemapLegendPointerBuilder =
    Widget Function(BuildContext context, Color color, double fraction);

Widget _buildTreemapLegendTitle(BuildContext context, String title) =>
    Text(title, style: Theme.of(context).textTheme.labelLarge);

Widget _buildTreemapLegendLabel(
  BuildContext context,
  TreemapLegendEntry entry,
) => Text(entry.label, style: Theme.of(context).textTheme.bodyMedium);

Widget _buildTreemapLegendItem(
  BuildContext context,
  TreemapLegendEntry entry,
  Widget label,
) => TreemapLegendItem(color: entry.color, label: label);

Widget _buildTreemapLegendBar(
  BuildContext context,
  List<Color> colors,
  Axis direction,
) => TreemapLegendBar(colors: colors, direction: direction);

Widget _buildTreemapLegendPointer(
  BuildContext context,
  Color color,
  double fraction,
) => const TreemapLegendPointer();

Widget _wrapTreemapLegend(BuildContext context, Widget child) =>
    TreemapOverlayContainer(padding: const EdgeInsets.all(8), child: child);

/// Configures a discrete-item or color-bar legend.
final class TreemapLegendConfig {
  const TreemapLegendConfig.discrete({
    this.position = TreemapOverlayPosition.bottomCenter,
    this.title,
    this.overflow = TreemapOverflowMode.wrap,
    this.direction = Axis.horizontal,
    this.wrapperBuilder = _wrapTreemapLegend,
    this.spacing = 8,
    this.semanticsLabel = 'Treemap legend',
    this.titleBuilder = _buildTreemapLegendTitle,
    this.labelBuilder = _buildTreemapLegendLabel,
    this.itemBuilder = _buildTreemapLegendItem,
    this.runSpacing = 4,
  }) : assert(spacing >= 0),
       assert(runSpacing >= 0),
       kind = TreemapLegendKind.discrete,
       segmented = true,
       barBuilder = _buildTreemapLegendBar,
       pointerBuilder = _buildTreemapLegendPointer,
       horizontalBarSize = const Size(160, 20),
       verticalBarSize = const Size(20, 120),
       pointerExtent = 18,
       horizontalPointerOffset = 16,
       verticalPointerOffset = 18,
       showLabels = true,
       sampleCount = 32;

  const TreemapLegendConfig.bar({
    this.position = TreemapOverlayPosition.bottomCenter,
    this.title,
    this.overflow = TreemapOverflowMode.scroll,
    this.direction = Axis.horizontal,
    this.wrapperBuilder = _wrapTreemapLegend,
    this.spacing = 8,
    this.semanticsLabel = 'Treemap legend',
    this.titleBuilder = _buildTreemapLegendTitle,
    this.labelBuilder = _buildTreemapLegendLabel,
    this.segmented = false,
    this.barBuilder = _buildTreemapLegendBar,
    this.pointerBuilder = _buildTreemapLegendPointer,
    this.horizontalBarSize = const Size(160, 20),
    this.verticalBarSize = const Size(20, 120),
    this.pointerExtent = 18,
    this.horizontalPointerOffset = 16,
    this.verticalPointerOffset = 18,
    this.showLabels = true,
    this.sampleCount = 32,
  }) : assert(spacing >= 0),
       assert(pointerExtent > 0),
       assert(horizontalPointerOffset >= 0),
       assert(verticalPointerOffset >= 0),
       assert(sampleCount >= 2),
       kind = TreemapLegendKind.bar,
       itemBuilder = _buildTreemapLegendItem,
       runSpacing = 4;

  final TreemapLegendKind kind;
  final TreemapOverlayPosition position;
  final String? title;
  final TreemapOverflowMode overflow;
  final Axis direction;
  final double spacing;

  /// Wraps the complete legend content with padding, decoration, or other
  /// caller-defined presentation.
  final TreemapOverlayWrapperBuilder wrapperBuilder;

  /// Builds the complete title widget.
  final TreemapLegendTitleBuilder titleBuilder;

  /// Builds labels for discrete entries and color-bar endpoints.
  final TreemapLegendLabelBuilder labelBuilder;

  /// Base semantics label, followed by [title] when one is supplied.
  final String semanticsLabel;

  final bool segmented;
  final TreemapLegendItemBuilder itemBuilder;

  /// Builds the complete sampled or segmented color bar.
  final TreemapLegendBarBuilder barBuilder;

  final TreemapLegendPointerBuilder pointerBuilder;

  /// Space between runs in a wrapping discrete legend.
  final double runSpacing;

  /// Horizontal color-bar viewport size.
  final Size horizontalBarSize;

  /// Vertical color-bar viewport size.
  final Size verticalBarSize;

  /// Main-axis extent assumed while centering a bar pointer.
  final double pointerExtent;

  /// Distance a horizontal bar pointer extends above the bar.
  final double horizontalPointerOffset;

  /// Distance a vertical bar pointer extends to the left of the bar.
  final double verticalPointerOffset;

  /// Whether the first and last scale labels accompany the color bar.
  final bool showLabels;

  /// Number of colors sampled from a continuous scale for a smooth bar.
  final int sampleCount;

  TreemapLegendConfig copyWith({
    TreemapOverlayPosition? position,
    String? title,
    TreemapOverflowMode? overflow,
    Axis? direction,
    TreemapOverlayWrapperBuilder? wrapperBuilder,
    double? spacing,
    TreemapLegendTitleBuilder? titleBuilder,
    TreemapLegendLabelBuilder? labelBuilder,
    String? semanticsLabel,
    bool? segmented,
    TreemapLegendItemBuilder? itemBuilder,
    TreemapLegendBarBuilder? barBuilder,
    TreemapLegendPointerBuilder? pointerBuilder,
    double? runSpacing,
    Size? horizontalBarSize,
    Size? verticalBarSize,
    double? pointerExtent,
    double? horizontalPointerOffset,
    double? verticalPointerOffset,
    bool? showLabels,
    int? sampleCount,
  }) => kind == TreemapLegendKind.discrete
      ? TreemapLegendConfig.discrete(
          position: position ?? this.position,
          title: title ?? this.title,
          overflow: overflow ?? this.overflow,
          direction: direction ?? this.direction,
          wrapperBuilder: wrapperBuilder ?? this.wrapperBuilder,
          spacing: spacing ?? this.spacing,
          titleBuilder: titleBuilder ?? this.titleBuilder,
          labelBuilder: labelBuilder ?? this.labelBuilder,
          semanticsLabel: semanticsLabel ?? this.semanticsLabel,
          itemBuilder: itemBuilder ?? this.itemBuilder,
          runSpacing: runSpacing ?? this.runSpacing,
        )
      : TreemapLegendConfig.bar(
          position: position ?? this.position,
          title: title ?? this.title,
          overflow: overflow ?? this.overflow,
          direction: direction ?? this.direction,
          wrapperBuilder: wrapperBuilder ?? this.wrapperBuilder,
          spacing: spacing ?? this.spacing,
          titleBuilder: titleBuilder ?? this.titleBuilder,
          labelBuilder: labelBuilder ?? this.labelBuilder,
          semanticsLabel: semanticsLabel ?? this.semanticsLabel,
          segmented: segmented ?? this.segmented,
          barBuilder: barBuilder ?? this.barBuilder,
          pointerBuilder: pointerBuilder ?? this.pointerBuilder,
          horizontalBarSize: horizontalBarSize ?? this.horizontalBarSize,
          verticalBarSize: verticalBarSize ?? this.verticalBarSize,
          pointerExtent: pointerExtent ?? this.pointerExtent,
          horizontalPointerOffset:
              horizontalPointerOffset ?? this.horizontalPointerOffset,
          verticalPointerOffset:
              verticalPointerOffset ?? this.verticalPointerOffset,
          showLabels: showLabels ?? this.showLabels,
          sampleCount: sampleCount ?? this.sampleCount,
        );

  @override
  bool operator ==(Object other) =>
      other is TreemapLegendConfig &&
      kind == other.kind &&
      position == other.position &&
      title == other.title &&
      overflow == other.overflow &&
      direction == other.direction &&
      wrapperBuilder == other.wrapperBuilder &&
      spacing == other.spacing &&
      titleBuilder == other.titleBuilder &&
      labelBuilder == other.labelBuilder &&
      semanticsLabel == other.semanticsLabel &&
      segmented == other.segmented &&
      itemBuilder == other.itemBuilder &&
      barBuilder == other.barBuilder &&
      pointerBuilder == other.pointerBuilder &&
      runSpacing == other.runSpacing &&
      horizontalBarSize == other.horizontalBarSize &&
      verticalBarSize == other.verticalBarSize &&
      pointerExtent == other.pointerExtent &&
      horizontalPointerOffset == other.horizontalPointerOffset &&
      verticalPointerOffset == other.verticalPointerOffset &&
      showLabels == other.showLabels &&
      sampleCount == other.sampleCount;

  @override
  int get hashCode => Object.hashAll([
    kind,
    position,
    title,
    overflow,
    direction,
    wrapperBuilder,
    spacing,
    titleBuilder,
    labelBuilder,
    semanticsLabel,
    segmented,
    itemBuilder,
    barBuilder,
    pointerBuilder,
    runSpacing,
    horizontalBarSize,
    verticalBarSize,
    pointerExtent,
    horizontalPointerOffset,
    verticalPointerOffset,
    showLabels,
    sampleCount,
  ]);
}
