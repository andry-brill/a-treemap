import 'package:flutter/widgets.dart';

import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Explicit invisible tile layer for geometry-only or interaction-only hosts.
final class TreemapNoopTileLayer<K> implements TreemapTileLayer<K> {
  const TreemapNoopTileLayer();

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      const SizedBox.expand();
}

/// Explicitly stacks multiple independently replaceable tile layers.
final class TreemapCompositeTileLayer<K> implements TreemapTileLayer<K> {
  TreemapCompositeTileLayer(Iterable<TreemapTileLayer<K>> layers)
    : layers = List.unmodifiable(layers);

  final List<TreemapTileLayer<K>> layers;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final layer in layers)
        Positioned.fill(child: layer.build(context, visual)),
    ],
  );
}
