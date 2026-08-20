import 'package:flutter/widgets.dart';

import '../controller.dart';
import '../presentation/context.dart';
import 'color_scale.dart';
import 'style.dart';

/// Resolves the package's Material tile appearance.
///
/// A color scale is required: this implementation never invents a
/// palette or fallback color on behalf of the chart. A Flutter [Color]
/// stored in a node's `color` field becomes the base color directly and
/// bypasses the scale; other values, or the node weight when absent, are
/// resolved by [colorScale]. Explicit state and node-style appearances can
/// still override that base color.
final class TreemapAppearanceResolver<K> {
  TreemapAppearanceResolver({
    required this.colorScale,
    TreemapStyle? style,
    this.nodeStyleResolver,
  }) : style = style ?? TreemapStyle();

  final TreemapColorScale colorScale;
  final TreemapStyle style;
  final TreemapNodeStyleResolver<K>? nodeStyleResolver;

  TreemapAppearance resolve(
    BuildContext context,
    TreemapNodeDetails<K> details,
    Set<TreemapVisualState> states,
  ) {
    final colorInput = details.color;
    final color = colorInput is Color
        ? colorInput
        : colorScale.colorFor(colorInput ?? details.weight);
    var appearance = TreemapAppearance(
      color: color,
    ).merge(style.tileAppearance);
    if (states.contains(TreemapVisualState.hovered)) {
      appearance = appearance.merge(style.hoverAppearance);
    }
    if (states.contains(TreemapVisualState.selected)) {
      appearance = appearance.merge(style.selectedAppearance);
    }
    if (states.contains(TreemapVisualState.focused)) {
      appearance = appearance.merge(style.focusedAppearance);
    }
    appearance = appearance.merge(
      nodeStyleResolver?.call(context, details, states),
    );
    if (appearance.color == null && appearance.gradient == null) {
      throw FlutterError(
        'TreemapTiles requires every visible node to resolve to a '
        'color or gradient.',
      );
    }
    return appearance;
  }
}
