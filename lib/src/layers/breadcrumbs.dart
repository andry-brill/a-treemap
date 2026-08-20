import 'package:flutter/widgets.dart';

import '../appearance/breadcrumbs.dart';
import '../appearance/overlay.dart';
import '../controller.dart';
import '../presentation/contracts.dart';
import 'surrounding_grid.dart';

/// Places controller-driven breadcrumbs around a chart viewport.
final class TreemapBreadcrumbs<K>
    implements TreemapSurroundingContent<K>, TreemapSurroundingLayer<K> {
  const TreemapBreadcrumbs({this.config = const TreemapBreadcrumbsConfig()});

  final TreemapBreadcrumbsConfig<K> config;

  @override
  Widget build(BuildContext context, TreemapController<K> controller) =>
      TreemapBreadcrumbsView(controller: controller, config: config);

  @override
  Widget wrap(
    BuildContext context,
    Widget treemap,
    TreemapController<K> controller,
  ) => TreemapSurroundingGrid<K>.fromMap({
    config.position: this,
  }).wrap(context, treemap, controller);
}

/// Standalone breadcrumb widget for compositions outside a chart.
class TreemapBreadcrumbsView<K> extends StatelessWidget {
  const TreemapBreadcrumbsView({
    super.key,
    required this.controller,
    this.config = const TreemapBreadcrumbsConfig(),
  });

  final TreemapController<K> controller;
  final TreemapBreadcrumbsConfig<K> config;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final path = controller.currentPath;
        final children = <Widget>[];
        for (final entry in path.indexed) {
          final isCurrent = entry.$1 == path.length - 1;
          children.add(
            config.itemBuilder(
              context,
              entry.$2,
              isCurrent,
              isCurrent ? null : () => controller.zoomToPathEntry(entry.$2),
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
      },
    );
  }
}
