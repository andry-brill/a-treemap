import 'package:flutter/widgets.dart';

import '../appearance/resolver.dart';
import '../painters/tile_painter.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';

/// Canvas tile implementation with the package's standard visual logic.
final class TreemapTiles<K> implements TreemapTileLayer<K> {
  const TreemapTiles({required this.appearance});

  @override
  final TreemapAppearanceResolver<K> appearance;

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) {
    final appearances = visual.resolveAppearances(context, appearance);
    return CustomPaint(
      painter: TreemapTilePainter<K>(
        snapshot: visual.presentation.displayedSnapshot!,
        appearances: appearances,
        backgroundColor: appearance.style.backgroundColor,
      ),
    );
  }
}
