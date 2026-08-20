import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/style.dart';
import '../controller.dart';
import '../geometry.dart';
import '../model.dart';
import 'text_layout_cache.dart';

/// Paints bounded text labels for the deepest visible geometry nodes.
final class TreemapCanvasLabelPainter<K> extends CustomPainter {
  const TreemapCanvasLabelPainter({
    required this.nodes,
    required this.details,
    required this.appearances,
    required this.config,
    required this.padding,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.textCache,
  });

  final List<TreemapGeometryNode<K>> nodes;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  final Map<TreemapKey<K>, TreemapAppearance> appearances;
  final TreemapLabelConfig<K> config;
  final EdgeInsets padding;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final TreemapTextLayoutCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final ordered = nodes.toList()..sort((a, b) => a.depth.compareTo(b.depth));
    for (final node in ordered) {
      final rect = Rect.fromLTWH(
        node.bounds.left,
        node.bounds.top,
        node.bounds.width,
        node.bounds.height,
      );
      if (rect.isEmpty) continue;
      canvas.save();
      canvas.clipRect(rect);
      _paintLabel(canvas, rect, details[node.key]!, appearances[node.key]!);
      canvas.restore();
    }
  }

  void _paintLabel(
    Canvas canvas,
    Rect rect,
    TreemapNodeDetails<K> nodeDetails,
    TreemapAppearance tileAppearance,
  ) {
    final lines = config.resolveLines(nodeDetails, tileAppearance, locale);
    if (lines.isEmpty) return;
    final available = Rect.fromLTRB(
      rect.left + padding.left,
      rect.top + padding.top,
      rect.right - padding.right,
      rect.bottom - padding.bottom,
    );
    if (available.isEmpty) return;
    final painters = <TextPainter>[];
    var totalHeight = 0.0;
    for (final line in lines) {
      final painter = textCache.layout(
        text: line.text,
        style: line.style,
        maxWidth: available.width,
        maxLines: config.maxLines,
        direction: config.textDirection ?? textDirection,
        scaler: textScaler,
        locale: locale,
        ellipsis: config.overflow == TextOverflow.ellipsis
            ? config.ellipsis
            : null,
      );
      painters.add(painter);
      totalHeight += painter.height;
    }
    if (totalHeight > available.height) return;
    final blockSize = Size(
      painters.fold<double>(
        0,
        (width, painter) => width > painter.width ? width : painter.width,
      ),
      totalHeight,
    );
    final origin = config.alignment.inscribe(blockSize, available).topLeft;
    var y = origin.dy;
    for (final painter in painters) {
      painter.paint(canvas, Offset(origin.dx, y));
      y += painter.height;
    }
  }

  @override
  bool shouldRepaint(covariant TreemapCanvasLabelPainter<K> oldDelegate) =>
      nodes != oldDelegate.nodes ||
      details != oldDelegate.details ||
      appearances != oldDelegate.appearances ||
      config != oldDelegate.config ||
      padding != oldDelegate.padding ||
      textDirection != oldDelegate.textDirection ||
      textScaler != oldDelegate.textScaler ||
      locale != oldDelegate.locale;
}
