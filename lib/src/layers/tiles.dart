import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../painters/tile_painter.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Canvas tile implementation with the package's standard visual logic.
final class TreemapTiles<K> implements TreemapTileLayer<K> {
  const TreemapTiles({required this.appearance});

  final TreemapAppearanceResolver<K> appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) {
    final appearances = {
      for (final node in visual.snapshot.nodes)
        node.key: appearance.resolve(
          context,
          visual.details[node.key]!,
          visual.statesFor(node.key),
        ),
    };
    return CustomPaint(
      painter: TreemapTilePainter<K>(
        snapshot: visual.snapshot,
        appearances: appearances,
        backgroundColor: appearance.style.backgroundColor,
      ),
    );
  }
}
