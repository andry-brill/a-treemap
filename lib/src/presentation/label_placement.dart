import 'package:flutter/widgets.dart';

import '../model.dart';

/// The rectangle used by centered widget and text layers before sizing.
enum TreemapContentRegion {
  /// Remaining space after the node's own header and label reservations.
  available,

  /// Full displayed tile bounds, ignoring label and header reservations.
  tile,
}

/// Prepared label output and the remaining rectangles shared with tile layers.
///
/// Coordinates are relative to the chart. Missing keys use the tile bounds below
/// its own structural header. Reservations affect presentation only; geometry,
/// aggregation and hit testing are unchanged.
final class TreemapLabelPlacement<K> {
  TreemapLabelPlacement({
    required this.child,
    Map<TreemapKey<K>, Rect> contentBounds = const {},
  }) : contentBounds = Map.unmodifiable(contentBounds);

  final Widget child;
  final Map<TreemapKey<K>, Rect> contentBounds;
}
