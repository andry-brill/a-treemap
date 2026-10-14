import 'package:flutter/widgets.dart';

import '../appearance/breadcrumbs.dart';
import '../appearance/overlay.dart';
import '../geometry.dart';
import '../presentation/context.dart';
import '../presentation/state.dart';
import '../presentation/contracts.dart';
import 'surrounding_grid.dart';

/// Places presentation-driven breadcrumbs around a chart viewport.
final class TreemapBreadcrumbs<K>
    implements TreemapSurroundingContent<K>, TreemapSurroundingLayer<K> {
  const TreemapBreadcrumbs({this.config = const TreemapBreadcrumbsConfig()});

  final TreemapBreadcrumbsConfig<K> config;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      TreemapBreadcrumbsView<K>(
        config: config,
        presentation: visual.presentation,
        onNavigate: (entry) {
          if (entry.key.isSource) {
            visual.actions.zoomTo(entry.key.sourceKey as K);
          }
        },
      );

  @override
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapVisualContext<K> visual,
  ) => TreemapSurroundingGrid<K>.fromMap({
    config.position: this,
  }).wrap(context, treemap, visual);
}

/// Standalone breadcrumb widget for compositions outside a chart.
class TreemapBreadcrumbsView<K> extends StatelessWidget {
  const TreemapBreadcrumbsView({
    super.key,
    this.presentation,
    this.onNavigate,
    this.config = const TreemapBreadcrumbsConfig(),
  });

  final TreemapPresentationState<K>? presentation;
  final ValueChanged<TreemapPathEntry<K>>? onNavigate;
  final TreemapBreadcrumbsConfig<K> config;

  @override
  Widget build(BuildContext context) {
    final state = presentation ?? TreemapPresentationScope.of<K>(context);
    final path = state.currentPath;
    final children = <Widget>[];
    for (final entry in path.indexed) {
      final isCurrent = entry.$1 == path.length - 1;
      children.add(
        config.itemBuilder(
          context,
          entry.$2,
          isCurrent,
          isCurrent || onNavigate == null ? null : () => onNavigate!(entry.$2),
        ),
      );
      if (!isCurrent) children.add(config.separatorBuilder(context));
    }
    final content = switch (config.overflow) {
      TreemapOverflowMode.wrap => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
      TreemapOverflowMode.scroll => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
      TreemapOverflowMode.ellipsis => Row(
        children: [
          if (children.length > config.ellipsisMaximumChildren)
            config.overflowIndicatorBuilder(context),
          ...children.skip(
            children.length > config.ellipsisMaximumChildren
                ? children.length - config.ellipsisMaximumChildren
                : 0,
          ),
        ],
      ),
    };
    return config.wrapperBuilder(context, content);
  }
}
