import 'package:flutter/widgets.dart';

/// Wraps the complete contents of a surrounding treemap layer.
typedef TreemapOverlayWrapperBuilder =
    Widget Function(BuildContext context, Widget child);

/// Selects a directional cell around the treemap viewport.
enum TreemapOverlayPosition {
  /// Places content in the top-start cell.
  topStart,

  /// Places content in the top-center cell.
  topCenter,

  /// Places content in the top-end cell.
  topEnd,

  /// Places content beside the treemap at the middle-start edge.
  middleStart,

  /// Places content beside the treemap at the middle-end edge.
  middleEnd,

  /// Places content in the bottom-start cell.
  bottomStart,

  /// Places content in the bottom-center cell.
  bottomCenter,

  /// Places content in the bottom-end cell.
  bottomEnd,
}

/// Determines how breadcrumb and legend items handle insufficient main-axis
/// space.
enum TreemapOverflowMode {
  /// Continues items on additional runs.
  wrap,

  /// Makes overflowing items available through scrolling.
  scroll,

  /// Keeps a compact visible subset and marks omitted content.
  ellipsis,
}
