import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/parent_label.dart';
import '../appearance/resolver.dart';
import '../painters/parent_label_metrics.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';
import 'centered_content.dart';
import 'label_regions.dart';

const _neutralTreemapLabelConfig = TreemapLabelConfig<Never>();

/// Widget-per-node tile implementation with no implicit clipping or styling.
final class TreemapBuilderTileLayer<K> implements TreemapTileLayer<K> {
  const TreemapBuilderTileLayer({
    required this.builder,
    this.appearance,
    this.maximumNodes,
    this.ignorePointer = false,
  }) : assert(maximumNodes == null || maximumNodes > 0);

  final TreemapStatefulNodeWidgetBuilder<K> builder;

  /// Optional background source shared with labels. The builder remains
  /// responsible for painting the corresponding background itself.
  @override
  final TreemapAppearanceResolver<K>? appearance;
  final int? maximumNodes;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      _buildNodeWidgets(
        context,
        visual,
        builder,
        maximumNodes: maximumNodes,
        ignorePointer: ignorePointer,
      );
}

/// Centers a proportionally sized widget in each deepest visible block.
///
/// Width and height are independent fractions of the displayed tile bounds.
/// Optional [aspect] fits a width-to-height ratio inside those dimensions.
/// The allocation does not scale the child's content.
/// Use a [FittedBox] in [builder] when the content itself should scale.
/// Compose this layer over `TreemapTiles` to retain standard tile painting.
final class TreemapCenteredWidgetLayer<K> implements TreemapTileLayer<K> {
  const TreemapCenteredWidgetLayer({
    required this.builder,
    this.widthFactor = 1.0,
    this.heightFactor = 1.0,
    this.aspect,
    this.minimumSize,
    this.appearance,
    this.ignorePointer = true,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(widthFactor >= 0 && widthFactor <= 1),
       assert(heightFactor >= 0 && heightFactor <= 1),
       assert(aspect == null || (aspect > 0 && aspect < double.infinity));

  /// Builds content only for nonempty allocations that meet [minimumSize].
  final TreemapStatefulNodeWidgetBuilder<K> builder;
  final double widthFactor;
  final double heightFactor;

  /// Optional width-to-height ratio fitted inside the factor-resolved box.
  ///
  /// Must be finite and positive. Null keeps the independent dimensions; 1
  /// produces a square. Fitting only shrinks dimensions and precedes the
  /// [minimumSize] check.
  final double? aspect;

  /// Minimum allocated width and height in logical pixels, or no cutoff.
  ///
  /// Content is skipped if either dimension falls below its minimum. Equality
  /// passes. This affects only this layer, never tile geometry or visibility.
  /// Dimensions must be finite and nonnegative; asserted when building so the
  /// constructor can remain const.
  final Size? minimumSize;

  /// Optional background declaration for labels; this layer paints no fill.
  @override
  final TreemapAppearanceResolver<K>? appearance;
  final bool ignorePointer;

  /// Clipping applied to the allocated content box, rather than the whole tile.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) {
    final minimum = minimumSize;
    assert(
      minimum == null ||
          (minimum.width.isFinite &&
              minimum.width >= 0 &&
              minimum.height.isFinite &&
              minimum.height >= 0),
      'minimumSize dimensions must be finite and nonnegative.',
    );
    return _buildNodeWidgets(
      context,
      visual,
      (context, details, states) {
        final size = resolveCenteredContentSize(
          Size(details.bounds.width, details.bounds.height),
          widthFactor: widthFactor,
          heightFactor: heightFactor,
          aspect: aspect,
          minimumSize: minimum,
        );
        if (size == null) return const SizedBox.shrink();
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: _configureNodeWidget(
              builder(context, details, states),
              ignorePointer: false,
              clipBehavior: clipBehavior,
            ),
          ),
        );
      },
      maximumNodes: null,
      ignorePointer: ignorePointer,
    );
  }
}

/// Widget label implementation for fully customized labels.
///
/// Each deepest visible block receives a tightly constrained [Positioned]
/// widget, so the builder can return text, SVGs, images, badges, animations,
/// or any other widget. Per-block clipping is enabled by default. Configure
/// `minimumWidth` and `minimumHeight` in the chart's layout when the custom
/// label needs reserved geometry, together with an aggregate or hide minimum
/// node policy.
/// Opt-in [parentLabels] also build widgets in reserved parent header regions.
final class TreemapWidgetLabels<K> implements TreemapLabelLayer<K> {
  const TreemapWidgetLabels({
    required this.builder,
    TreemapLabelConfig<K> config = _neutralTreemapLabelConfig,
    this.maximumNodes,
    this.ignorePointer = true,
    this.clipBehavior = Clip.hardEdge,
    this.parentLabels,
    this.parentBuilder,
  }) : _config = config,
       assert(maximumNodes == null || maximumNodes > 0);

  final TreemapStatefulNodeWidgetBuilder<K> builder;
  final TreemapLabelConfig<K> _config;

  /// Shared typography, padding, spacing and direction for header sizing.
  ///
  /// Builders apply these styles, padding and their own spacer. Formatting and
  /// visibility remain the builder's responsibility. Canvas-only
  /// [TreemapLabelConfig.linesBuilder] is ignored.
  TreemapLabelConfig<K> get config =>
      identical(_config, _neutralTreemapLabelConfig)
      ? TreemapLabelConfig<K>()
      : _config;

  final int? maximumNodes;
  final bool ignorePointer;
  final Clip clipBehavior;
  final TreemapParentLabelConfig? parentLabels;

  /// Replaces [builder] for header regions only. The widget owns its content,
  /// visibility flags and padding; [TreemapNodeDetails.headerBounds] describes
  /// its allocation while the node's ordinary bounds remain unchanged.
  /// Builders can call [TreemapLabelConfig.resolveStyles] for configured state
  /// and per-node typography; automatic sizing always uses base styles.
  final TreemapStatefulNodeWidgetBuilder<K>? parentBuilder;

  @override
  double? resolveParentHeaderHeight(BuildContext context) =>
      resolveParentLabelHeight(
        context,
        parentLabels,
        titleStyle: config.titleStyle,
        valueStyle: config.valueStyle,
        padding: config.padding,
        spacing: config.spacing,
        textDirection: config.textDirection,
      );

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      _buildNodeWidgets(
        context,
        visual,
        builder,
        maximumNodes: maximumNodes,
        ignorePointer: ignorePointer,
        clipBehavior: clipBehavior,
        labels: true,
        includeHeaders: parentLabels?.enabled ?? false,
        parentBuilder: parentBuilder,
      );
}

Widget _buildNodeWidgets<K>(
  BuildContext context,
  TreemapVisualContext<K> visual,
  TreemapStatefulNodeWidgetBuilder<K> builder, {
  required int? maximumNodes,
  required bool ignorePointer,
  Clip clipBehavior = Clip.none,
  bool labels = false,
  bool includeHeaders = false,
  TreemapStatefulNodeWidgetBuilder<K>? parentBuilder,
}) {
  final nodes =
      (labels
              ? labelNodes(visual.presentation, includeHeaders: includeHeaders)
              : visual.presentation.visibleLeafNodes)
          .toList()
        ..removeWhere(
          (node) => (labels ? labelBounds(node) : node.bounds).isEmpty,
        )
        ..sort((a, b) {
          final area = (labels ? labelBounds(b) : b.bounds).area.compareTo(
            (labels ? labelBounds(a) : a.bounds).area,
          );
          return area != 0 ? area : a.key.hashCode.compareTo(b.key.hashCode);
        });
  if (maximumNodes != null && nodes.length > maximumNodes) {
    nodes.length = maximumNodes;
  }
  nodes.sort((a, b) => a.depth.compareTo(b.depth));
  return Stack(
    clipBehavior: Clip.none,
    children: [
      for (final node in nodes)
        Positioned(
          key: ValueKey(node.key),
          left: (labels ? labelBounds(node) : node.bounds).left,
          top: (labels ? labelBounds(node) : node.bounds).top,
          width: (labels ? labelBounds(node) : node.bounds).width,
          height: (labels ? labelBounds(node) : node.bounds).height,
          child: _configureNodeWidget(
            (labels && node.headerBounds != null
                ? parentBuilder ?? builder
                : builder)(
              context,
              visual.presentation.details[node.key]!,
              visual.presentation.statesFor(node.key),
            ),
            ignorePointer: ignorePointer,
            clipBehavior: clipBehavior,
          ),
        ),
    ],
  );
}

Widget _configureNodeWidget(
  Widget child, {
  required bool ignorePointer,
  required Clip clipBehavior,
}) {
  if (clipBehavior != Clip.none) {
    child = ClipRect(clipBehavior: clipBehavior, child: child);
  }
  return ignorePointer ? IgnorePointer(child: child) : child;
}
