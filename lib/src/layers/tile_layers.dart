import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Explicit invisible tile layer for geometry-only or interaction-only hosts.
final class TreemapNoopTileLayer<K> implements TreemapTileLayer<K> {
  const TreemapNoopTileLayer({this.appearance});

  /// Optional background source for labels and other rendering layers.
  /// Describes the background they should assume; this layer paints nothing.
  /// Geometry-only charts and arbitrary widget labels may omit it.
  @override
  final TreemapAppearanceResolver<K>? appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) =>
      const SizedBox.expand();
}

/// Explicitly stacks multiple independently replaceable tile layers.
final class TreemapCompositeTileLayer<K> implements TreemapTileLayer<K> {
  TreemapCompositeTileLayer(
    Iterable<TreemapTileLayer<K>> layers, {
    this.appearance,
  }) : layers = List.unmodifiable(layers);

  final List<TreemapTileLayer<K>> layers;

  /// Declared background source for labels. Child layers retain their own paint
  /// sources; no source is inferred from child order or overlapping paints.
  @override
  final TreemapAppearanceResolver<K>? appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final layer in layers)
        Positioned.fill(child: layer.build(context, visual)),
    ],
  );
}
