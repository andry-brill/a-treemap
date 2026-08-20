import 'package:flutter/widgets.dart';

import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Widget-per-node tile implementation with no implicit clipping or styling.
final class TreemapBuilderTileLayer<K> implements TreemapTileLayer<K> {
  const TreemapBuilderTileLayer({
    required this.builder,
    this.maximumNodes,
    this.ignorePointer = false,
  }) : assert(maximumNodes == null || maximumNodes > 0);

  final TreemapStatefulNodeWidgetBuilder<K> builder;
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
final class TreemapWidgetLabels<K> implements TreemapLabelLayer<K> {
  const TreemapWidgetLabels({
    required this.builder,
    this.maximumNodes,
    this.ignorePointer = true,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(maximumNodes == null || maximumNodes > 0);

  final TreemapStatefulNodeWidgetBuilder<K> builder;
  final int? maximumNodes;
  final bool ignorePointer;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      _buildNodeWidgets(
        context,
        visual,
        builder,
        maximumNodes: maximumNodes,
        ignorePointer: ignorePointer,
        clipBehavior: clipBehavior,
      );
}

Widget _buildNodeWidgets<K>(
  BuildContext context,
  TreemapVisualContext<K> visual,
  TreemapStatefulNodeWidgetBuilder<K> builder, {
  required int? maximumNodes,
  required bool ignorePointer,
  Clip clipBehavior = Clip.none,
}) {
  final nodes = visual.visibleLeafNodes.toList()
    ..sort((a, b) {
      final area = b.bounds.area.compareTo(a.bounds.area);
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
          left: node.bounds.left,
          top: node.bounds.top,
          width: node.bounds.width,
          height: node.bounds.height,
          child: _configureNodeWidget(
            builder(
              context,
              visual.details[node.key]!,
              visual.statesFor(node.key),
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
