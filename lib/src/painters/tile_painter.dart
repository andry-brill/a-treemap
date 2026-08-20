import 'package:flutter/widgets.dart';

import '../appearance/style.dart';
import '../geometry.dart';
import '../model.dart';

/// Paints resolved tile backgrounds, gradients, borders, and opacity.
final class TreemapTilePainter<K> extends CustomPainter {
  const TreemapTilePainter({
    required this.snapshot,
    required this.appearances,
    required this.backgroundColor,
  });

  final TreemapGeometrySnapshot<K> snapshot;
  final Map<TreemapKey<K>, TreemapAppearance> appearances;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor.a > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }
    final ordered = snapshot.visibleNodes.toList()
      ..sort((a, b) => a.depth.compareTo(b.depth));
    for (final node in ordered) {
      final appearance = appearances[node.key]!;
      final rect = Rect.fromLTWH(
        node.bounds.left,
        node.bounds.top,
        node.bounds.width,
        node.bounds.height,
      );
      if (rect.isEmpty) continue;
      final rrect = appearance.borderRadius.toRRect(rect);
      final fill = Paint()
        ..isAntiAlias = true
        ..color = (appearance.color ?? const Color(0x00000000)).withValues(
          alpha: appearance.opacity * node.opacity,
        );
      if (appearance.gradient case final gradient?) {
        fill.shader = gradient.createShader(rect);
      }
      canvas.drawRRect(rrect, fill);
      if (appearance.border != BorderSide.none && appearance.border.width > 0) {
        final border = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = appearance.border.width
          ..color = appearance.border.color.withValues(
            alpha: appearance.opacity * node.opacity,
          )
          ..isAntiAlias = true;
        final inset = appearance.border.width / 2;
        canvas.drawRRect(
          appearance.borderRadius.toRRect(rect.deflate(inset)),
          border,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TreemapTilePainter<K> oldDelegate) =>
      snapshot.revision != oldDelegate.snapshot.revision ||
      snapshot.nodes != oldDelegate.snapshot.nodes ||
      appearances != oldDelegate.appearances ||
      backgroundColor != oldDelegate.backgroundColor;
}
