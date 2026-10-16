import 'package:flutter/widgets.dart';

import '../model.dart';

typedef TreemapCenteredTextPaintEntry<K> = ({
  TreemapKey<K> key,
  Rect bounds,
  double scale,
  TextPainter painter,
});

/// Paints cached single-line paragraphs using a shared reference box.
final class TreemapCenteredTextPainter<K> extends CustomPainter {
  const TreemapCenteredTextPainter({
    required this.entries,
    required this.referenceSize,
    required this.paintOffset,
  });

  final List<TreemapCenteredTextPaintEntry<K>> entries;
  final Size referenceSize;
  final Offset paintOffset;

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in entries) {
      canvas.save();
      canvas.clipRect(entry.bounds);
      canvas.translate(entry.bounds.center.dx, entry.bounds.center.dy);
      canvas.scale(entry.scale);
      entry.painter.paint(canvas, paintOffset);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant TreemapCenteredTextPainter<K> oldDelegate) =>
      entries != oldDelegate.entries || paintOffset != oldDelegate.paintOffset;
}
