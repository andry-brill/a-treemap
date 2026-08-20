import 'package:flutter/widgets.dart';

import '../appearance/tooltip.dart';
import '../controller.dart';
import '../geometry.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Adapts tooltip configuration and a node builder to the tooltip-layer
/// contract.
final class TreemapTooltip<K> implements TreemapTooltipLayer<K> {
  const TreemapTooltip({
    required this.builder,
    this.config = const TreemapTooltipConfig(),
  });

  final TreemapNodeWidgetBuilder<K> builder;
  final TreemapTooltipConfig config;

  @override
  TreemapTooltipActivation get activation => config.activation;

  @override
  Duration? get hideDelay => config.hideDelay;

  @override
  bool get suppressDuringAnimation => config.suppressDuringAnimation;

  @override
  Widget build(BuildContext context, TreemapTooltipContext<K> tooltip) {
    return TreemapTooltipView<K>(
      details: tooltip.details,
      config: config,
      builder: builder,
    );
  }
}

/// Standalone positioned tooltip widget for custom stack compositions.
class TreemapTooltipView<K> extends StatelessWidget {
  const TreemapTooltipView({
    super.key,
    required this.details,
    required this.config,
    required this.builder,
  });

  final TreemapNodeDetails<K> details;
  final TreemapTooltipConfig config;
  final TreemapNodeWidgetBuilder<K> builder;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _TreemapTooltipDelegate(
            target: details.bounds,
            placement: config.placement,
            margin: config.margin,
            fitInside: config.fitInside,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: config.maxWidth),
            child: config.containerBuilder(context, builder(context, details)),
          ),
        ),
      ),
    );
  }
}

/// Sizes and positions one tooltip relative to its target leaf rectangle.
final class _TreemapTooltipDelegate extends SingleChildLayoutDelegate {
  const _TreemapTooltipDelegate({
    required this.target,
    required this.placement,
    required this.margin,
    required this.fitInside,
  });

  final TreemapBounds target;
  final TreemapTooltipPlacement placement;
  final double margin;
  final bool fitInside;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final resolved = placement == TreemapTooltipPlacement.auto
        ? (target.top >= childSize.height + margin
              ? TreemapTooltipPlacement.above
              : TreemapTooltipPlacement.below)
        : placement;
    var x = target.centerX - childSize.width / 2;
    var y = target.top - childSize.height - margin;
    switch (resolved) {
      case TreemapTooltipPlacement.above:
        break;
      case TreemapTooltipPlacement.below:
        y = target.bottom + margin;
      case TreemapTooltipPlacement.left:
        x = target.left - childSize.width - margin;
        y = target.centerY - childSize.height / 2;
      case TreemapTooltipPlacement.right:
        x = target.right + margin;
        y = target.centerY - childSize.height / 2;
      case TreemapTooltipPlacement.auto:
        break;
    }
    if (fitInside) {
      x = x.clamp(0, mathMax(0, size.width - childSize.width));
      y = y.clamp(0, mathMax(0, size.height - childSize.height));
    }
    return Offset(x, y);
  }

  double mathMax(double a, double b) => a > b ? a : b;

  @override
  bool shouldRelayout(covariant _TreemapTooltipDelegate oldDelegate) =>
      target != oldDelegate.target ||
      placement != oldDelegate.placement ||
      margin != oldDelegate.margin ||
      fitInside != oldDelegate.fitInside;
}
