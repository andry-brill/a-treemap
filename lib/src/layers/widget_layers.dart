import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/parent_label.dart';
import '../appearance/resolver.dart';
import '../painters/parent_label_metrics.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';
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
