import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/label_reservation.dart';
import '../appearance/parent_label.dart';
import '../appearance/style.dart';
import '../controller.dart';
import '../geometry.dart';
import '../model.dart';
import 'text_layout_cache.dart';

/// Paints bounded text labels for the deepest visible geometry nodes.
final class TreemapCanvasLabelPainter<K> extends CustomPainter {
  TreemapCanvasLabelPainter({
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
    this.reservation = const TreemapLabelReservation.automatic(),
  });

  final List<TreemapGeometryNode<K>> nodes;
  final Map<TreemapKey<K>, TreemapNodeDetails<K>> details;
  final Map<TreemapKey<K>, TreemapAppearance> appearances;
  final Map<TreemapKey<K>, TreemapLabelStyle> styles;
  final TreemapLabelConfig<K> config;
  final TreemapParentLabelConfig? parentLabels;
  final TreemapLabelReservation reservation;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final TreemapTextLayoutCache textCache;
  TreemapCanvasLabelLayout<K>? _prepared;

  /// Resolve formatting, fit and placement once for both labels and content.
  TreemapCanvasLabelLayout<K> prepare() => _prepared ??= _prepare();

  TreemapCanvasLabelLayout<K> _prepare() {
    final entries = <TreemapCanvasLabelEntry>[];
    final contentBounds = <TreemapKey<K>, Rect>{};
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
      _prepareLabel(
        rect,
        details[node.key]!,
        appearances[node.key]!,
        entries,
        contentBounds,
      );
    }
    return TreemapCanvasLabelLayout(
      List.unmodifiable(entries),
      Map.unmodifiable(contentBounds),
    );
  }

  void _prepareLabel(
    Rect rect,
    TreemapNodeDetails<K> nodeDetails,
    TreemapAppearance tileAppearance,
    List<TreemapCanvasLabelEntry> entries,
    Map<TreemapKey<K>, Rect> contentBounds,
  ) {
    final parent = nodeDetails.headerBounds == null ? null : parentLabels;
    final effectiveConfig = parent == null
        ? config
        : config.copyWith(
            showTitle: parent.showTitle,
            showValue: parent.showValue,
            maxLines: parent.height == null ? 1 : config.maxLines,
          );
    final isHeader = nodeDetails.headerBounds != null;
    final alignment = isHeader
        ? config.alignment
        : reservationAlignment(reservation, config.alignment);
    Rect? reserved;
    if (!isHeader && reservation.height != null) {
      reserved = labelReservationBounds(rect, reservation, alignment, 0);
      if (reserved != null) {
        contentBounds[nodeDetails.key] = remainingLabelBounds(
          rect,
          reserved,
          alignment,
        );
      }
    }
    final labelRect = reserved ?? rect;
    final lines = effectiveConfig.resolveLines(
      nodeDetails,
      tileAppearance,
      locale,
      styles: styles[nodeDetails.key]!,
    );
    if (lines.isEmpty) return;
    final spacing = effectiveConfig.spacing;
    final padding = effectiveConfig.padding;
    final available = Rect.fromLTRB(
      labelRect.left + padding.left,
      labelRect.top + padding.top,
      labelRect.right - padding.right,
      labelRect.bottom - padding.bottom,
    );
    if (available.isEmpty) return;
    final painters = <TextPainter>[];
    var totalHeight = spacing * (lines.length - 1);
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
    if (!isHeader && reserved == null) {
      reserved = labelReservationBounds(
        rect,
        reservation,
        alignment,
        totalHeight + padding.vertical,
      );
      if (reserved != null) {
        contentBounds[nodeDetails.key] = remainingLabelBounds(
          rect,
          reserved,
          alignment,
        );
      }
    }
    final blockSize = Size(
      painters.fold<double>(
        0,
        (width, painter) => width > painter.width ? width : painter.width,
      ),
      totalHeight,
    );
    final origin = alignment.inscribe(blockSize, available).topLeft;
    var y = origin.dy;
    for (final painter in painters) {
      entries.add(
        TreemapCanvasLabelEntry(
          nodeDetails.key,
          labelRect,
          painter,
          Offset(origin.dx, y),
        ),
      );
      y += painter.height + spacing;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in prepare().entries) {
      canvas.save();
      canvas.clipRect(entry.bounds);
      entry.painter.paint(canvas, entry.offset);
      canvas.restore();
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
      reservation != oldDelegate.reservation ||
      textDirection != oldDelegate.textDirection ||
      textScaler != oldDelegate.textScaler ||
      locale != oldDelegate.locale;
}

final class TreemapCanvasLabelLayout<K> {
  const TreemapCanvasLabelLayout(this.entries, this.contentBounds);
  final List<TreemapCanvasLabelEntry> entries;
  final Map<TreemapKey<K>, Rect> contentBounds;
}

final class TreemapCanvasLabelEntry {
  const TreemapCanvasLabelEntry(
    this.key,
    this.bounds,
    this.painter,
    this.offset,
  );
  final TreemapKey key;
  final Rect bounds;
  final TextPainter painter;
  final Offset offset;
}
