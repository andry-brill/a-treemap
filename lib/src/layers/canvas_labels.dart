import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/parent_label.dart';
import '../model.dart';
import '../painters/canvas_label_painter.dart';
import '../painters/parent_label_metrics.dart';
import '../painters/text_layout_cache.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';
import 'label_regions.dart';
import 'widget_layers.dart';

const _neutralTreemapLabelConfig = TreemapLabelConfig<Never>();

/// Optimized canvas label implementation for large treemaps.
///
/// It measures and paints text through cached [TextPainter] instances without
/// creating one widget and render object per label. Use [TreemapWidgetLabels]
/// when labels need SVGs, images, arbitrary widgets, or widget-level effects.
/// Painting is clipped independently to every deepest visible block. Text is
/// constrained to that block's available width and omitted when its complete
/// line block cannot fit vertically.
/// Opt-in [parentLabels] add reserved header regions above nested children.
/// Background appearances come exclusively from the tile layer through
/// [TreemapTileLayer.appearance], including when the tiles are invisible.
final class TreemapCanvasLabels<K> implements TreemapLabelLayer<K> {
  TreemapCanvasLabels({
    TreemapLabelConfig<K> config = _neutralTreemapLabelConfig,
    this.parentLabels,
  }) : _config = config;

  final TreemapParentLabelConfig? parentLabels;
  final TreemapLabelConfig<K> _config;

  /// Canvas-label formatting and layout configuration.
  TreemapLabelConfig<K> get config =>
      identical(_config, _neutralTreemapLabelConfig)
      ? TreemapLabelConfig<K>()
      : _config;
  final TreemapTextLayoutCache _textCache = TreemapTextLayoutCache();

  @override
  double? resolveParentHeaderHeight(BuildContext context) =>
      resolveParentLabelHeight(
        context,
        parentLabels,
        titleStyle: config.titleStyle,
        valueStyle: config.valueStyle,
        padding: config.padding,
        spacing: config.linesBuilder == null ? config.spacing : 0,
        textDirection: config.textDirection,
      );

  @override
  Widget build(BuildContext context, TreemapVisualContext<K> visual) {
    final locale = Localizations.maybeLocaleOf(context);
    if (locale == null &&
        config.linesBuilder == null &&
        config.localizedValueFormatter != null) {
      throw FlutterError(
        'TreemapCanvasLabels requires a Localizations ancestor when '
        'TreemapLabelConfig.localizedValueFormatter is configured. Wrap the '
        'chart in WidgetsApp, MaterialApp, or Localizations.',
      );
    }
    final appearances = visual.resolveTileAppearances(context);
    final nodes = labelNodes(
      visual.presentation,
      includeHeaders: parentLabels?.enabled ?? false,
    ).toList(growable: false);
    final styles = Map<TreemapKey<K>, TreemapLabelStyle>.unmodifiable({
      for (final node in nodes)
        node.key: config.resolveStyles(
          context,
          visual.presentation.details[node.key]!,
          visual.presentation.statesFor(node.key),
        ),
    });
    return IgnorePointer(
      child: CustomPaint(
        painter: TreemapCanvasLabelPainter<K>(
          nodes: nodes,
          styles: styles,
          details: visual.presentation.details,
          appearances: appearances,
          config: config,
          parentLabels: parentLabels,
          textDirection: visual.textDirection,
          textScaler: visual.textScaler,
          locale: locale,
          textCache: _textCache,
        ),
      ),
    );
  }
}
