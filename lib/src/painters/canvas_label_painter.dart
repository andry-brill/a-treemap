import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/parent_label.dart';
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
    required this.styles,
    required this.config,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.textCache,
    this.parentLabels,
  });

  final List<TreemapGeometryNode<K>> nodes;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  final Map<TreemapKey<K>, TreemapAppearance> appearances;
  final Map<TreemapKey<K>, TreemapLabelStyle> styles;
  final TreemapLabelConfig<K> config;
  final TreemapParentLabelConfig? parentLabels;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final TreemapTextLayoutCache textCache;

  @override
  void paint(Canvas canvas, Size size) {
    final ordered = nodes.toList()..sort((a, b) => a.depth.compareTo(b.depth));
    for (final node in ordered) {
      final bounds = node.headerBounds ?? node.bounds;
      final rect = Rect.fromLTWH(
        bounds.left,
        bounds.top,
        bounds.width,
        bounds.height,
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
    final parent = nodeDetails.headerBounds == null ? null : parentLabels;
    final effectiveConfig = parent == null
        ? config
        : config.copyWith(
            showTitle: parent.showTitle,
            showValue: parent.showValue,
            maxLines: parent.height == null ? 1 : config.maxLines,
          );
    final lines = effectiveConfig.resolveLines(
      nodeDetails,
      tileAppearance,
      locale,
      styles: styles[nodeDetails.key]!,
    );
    if (lines.isEmpty) return;
    final spacing = effectiveConfig.linesBuilder == null && lines.length == 2
        ? effectiveConfig.spacing
        : 0.0;
    final padding = effectiveConfig.padding;
    final available = Rect.fromLTRB(
      rect.left + padding.left,
      rect.top + padding.top,
      rect.right - padding.right,
      rect.bottom - padding.bottom,
    );
    if (available.isEmpty) return;
    final painters = <TextPainter>[];
    var totalHeight = spacing;
    for (final line in lines) {
      final painter = textCache.layout(
        text: line.text,
        style: line.style,
        maxWidth: available.width,
        maxLines: effectiveConfig.maxLines,
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
    // Subtracting fractional tile coordinates can lose a few floating-point
    // bits even when an automatic header reserved exactly this text height.
    if (totalHeight - available.height > 1e-7) return;
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
      y += painter.height + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant TreemapCanvasLabelPainter<K> oldDelegate) =>
      nodes != oldDelegate.nodes ||
      details != oldDelegate.details ||
      appearances != oldDelegate.appearances ||
      styles != oldDelegate.styles ||
      config != oldDelegate.config ||
      parentLabels != oldDelegate.parentLabels ||
      textDirection != oldDelegate.textDirection ||
      textScaler != oldDelegate.textScaler ||
      locale != oldDelegate.locale;
}
