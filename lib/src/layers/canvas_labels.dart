import 'package:flutter/widgets.dart';

import '../appearance/label.dart';
import '../appearance/resolver.dart';
import '../painters/canvas_label_painter.dart';
import '../painters/text_layout_cache.dart';
import '../presentation/context.dart';
import '../presentation/contracts.dart';
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
final class TreemapCanvasLabels<K> implements TreemapLabelLayer<K> {
  TreemapCanvasLabels({
    required this.appearance,
    TreemapLabelConfig<K> config = _neutralTreemapLabelConfig,
  }) : _config = config;

  final TreemapAppearanceResolver<K> appearance;
  final TreemapLabelConfig<K> _config;

  /// Canvas-label formatting and layout configuration.
  TreemapLabelConfig<K> get config =>
      identical(_config, _neutralTreemapLabelConfig)
      ? TreemapLabelConfig<K>()
      : _config;
  final TreemapTextLayoutCache _textCache = TreemapTextLayoutCache();

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
    final appearances = {
      for (final node in visual.snapshot.nodes)
        node.key: appearance.resolve(
          context,
          visual.details[node.key]!,
          visual.statesFor(node.key),
        ),
    };
    return IgnorePointer(
      child: CustomPaint(
        painter: TreemapCanvasLabelPainter<K>(
          nodes: visual.visibleLeafNodes.toList(growable: false),
          details: visual.details,
          appearances: appearances,
          config: config,
          padding: appearance.style.labelPadding,
          textDirection: visual.textDirection,
          textScaler: visual.textScaler,
          locale: locale,
          textCache: _textCache,
        ),
      ),
    );
  }
}
