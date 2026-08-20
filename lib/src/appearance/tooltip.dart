import 'package:flutter/material.dart';

import '../presentation/contracts.dart';
import '../widgets/tooltip_container.dart';

/// Selects the preferred position of a tooltip relative to its target leaf.
enum TreemapTooltipPlacement {
  /// Chooses a side according to the available space around the target.
  auto,

  /// Places the tooltip above the target.
  above,

  /// Places the tooltip below the target.
  below,

  /// Places the tooltip to the left of the target.
  left,

  /// Places the tooltip to the right of the target.
  right,
}

/// Builds the visual shell around tooltip contents.
///
/// The default builder returns a configurable [TreemapTooltipContainer].
typedef TreemapTooltipContainerBuilder =
    Widget Function(BuildContext context, Widget child);

Widget _buildTreemapTooltipContainer(BuildContext context, Widget child) =>
    TreemapTooltipContainer(child: child);

/// Configures tooltip activation, placement, constraints, and visual shell.
final class TreemapTooltipConfig {
  const TreemapTooltipConfig({
    this.activation = TreemapTooltipActivation.hoverAndTap,
    this.placement = TreemapTooltipPlacement.auto,
    this.fitInside = true,
    this.hideDelay = const Duration(seconds: 2),
    this.margin = 8,
    this.maxWidth = 280,
    this.containerBuilder = _buildTreemapTooltipContainer,
    this.suppressDuringAnimation = true,
  }) : assert(margin >= 0),
       assert(maxWidth > 0);

  final TreemapTooltipActivation activation;
  final TreemapTooltipPlacement placement;
  final bool fitInside;
  final Duration hideDelay;
  final double margin;
  final double maxWidth;

  /// Builds the complete decoration and padding around tooltip contents.
  final TreemapTooltipContainerBuilder containerBuilder;

  final bool suppressDuringAnimation;

  TreemapTooltipConfig copyWith({
    TreemapTooltipActivation? activation,
    TreemapTooltipPlacement? placement,
    bool? fitInside,
    Duration? hideDelay,
    double? margin,
    double? maxWidth,
    TreemapTooltipContainerBuilder? containerBuilder,
    bool? suppressDuringAnimation,
  }) => TreemapTooltipConfig(
    activation: activation ?? this.activation,
    placement: placement ?? this.placement,
    fitInside: fitInside ?? this.fitInside,
    hideDelay: hideDelay ?? this.hideDelay,
    margin: margin ?? this.margin,
    maxWidth: maxWidth ?? this.maxWidth,
    containerBuilder: containerBuilder ?? this.containerBuilder,
    suppressDuringAnimation:
        suppressDuringAnimation ?? this.suppressDuringAnimation,
  );

  @override
  bool operator ==(Object other) =>
      other is TreemapTooltipConfig &&
      activation == other.activation &&
      placement == other.placement &&
      fitInside == other.fitInside &&
      hideDelay == other.hideDelay &&
      margin == other.margin &&
      maxWidth == other.maxWidth &&
      containerBuilder == other.containerBuilder &&
      suppressDuringAnimation == other.suppressDuringAnimation;

  @override
  int get hashCode => Object.hash(
    activation,
    placement,
    fitInside,
    hideDelay,
    margin,
    maxWidth,
    containerBuilder,
    suppressDuringAnimation,
  );
}
