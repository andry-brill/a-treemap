import '../geometry.dart';
import '../presentation/state.dart';

/// Keeps parent headers and ordinary terminal labels mutually exclusive.
Iterable<TreemapGeometryNode<K>> labelNodes<K>(
  TreemapPresentationState<K> presentation, {
  required bool includeHeaders,
}) sync* {
  for (final node in presentation.visibleLeafNodes) {
    if (node.headerBounds == null) yield node;
  }
  if (includeHeaders) {
    for (final node
        in presentation.displayedSnapshot?.visibleNodes ??
            <TreemapGeometryNode<K>>[]) {
      if (node.headerBounds != null) yield node;
    }
  }
}

TreemapBounds labelBounds<K>(TreemapGeometryNode<K> node) =>
    node.headerBounds ?? node.bounds;
