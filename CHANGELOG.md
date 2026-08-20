# Changelog

## 1.0.0

- Added `TreemapChart.surrounding`, `TreemapSurroundingContent`, and
  `TreemapSurroundingGrid` for placing breadcrumbs, legends, and custom content
  in eight direction-aware cells around the treemap. The grid supports named
  slots or `fromMap`, uses standard flex layout, and leaves sizing to callers.
- Breadcrumbs and legends work as either direct surrounding layers or grid
  content; custom content uses the `widget` and `builder` factories.
- Split presentation from the treemap core. `TreemapChart` now consumes
  replaceable tile, label, semantics, tooltip, and surrounding-layer contracts;
  all contracts and implementations share the `any_treemap.dart` entry point.
- Removed implicit labels, tooltips, legends, breadcrumbs, semantics, empty
  text, palette, fallback colors, animation, and clipping from the core chart.
  A tile layer is explicit, and all color-scale fallbacks are required.
- Added no-op, composite, and widget-builder layers plus immutable visual
  contexts. Included labels and semantics target deepest visible blocks while
  tile layers retain ancestor geometry for hierarchy painting.
- Added optimized `TreemapCanvasLabels` and fully customizable, per-node
  clipped `TreemapWidgetLabels`. Canvas labels support a configurable ellipsis;
  label rendering no longer measures or changes layout geometry.
- Moved interaction contracts out of appearance code and changed presentation
  data labels/color values to remain nullable instead of inventing display
  strings or weight-based colors in the core.
- Removed per-node minimum dimensions from `TreemapNode`; minimum width, height,
  and area thresholds now belong exclusively to `TreemapLayoutConfig`.
- Removed device-pixel snapping from core geometry and removed implicit
  high-contrast appearance mutation and context state.
- Renamed node and record `colorValue` inputs to `color`. A Flutter `Color`
  now bypasses the included appearance resolver's configured color scale.
- Removed `emptyBuilder`, `TreemapEmptyBuilder`, and `TreemapEmptyState`;
  empty geometry now always produces the neutral `SizedBox.shrink` output.
- Moved flat-record construction to `TreemapNode.fromRecords` and removed both
  `TreemapNodeFactory` and `TreemapChart.fromRecords`.

## 0.1.0

- Introduced the clean standalone immutable API: `TreemapNode<K>`,
  `TreemapChart<K>`, `TreemapLayoutConfig<K>`, typed node details/results, and
  `TreemapController<K>`.
- Added explicit-tree and flat-record inputs through one validated normalizer.
- Added squarified, resquarified, slice, dice, alternating slice/dice, strip,
  binary-by-weight, binary-by-count, multilevel rules, sorting, origins, axes,
  spacing, padding, explicit minimum dimensions, and generated aggregate reveal.
- Added keyed animations, safe focus preservation, selection/multi-selection,
  hover, long press, tooltip lifecycle, breadcrumbs, and controller commands.
- Added exact, categorical, numeric-range, interpolated, and saturation color
  scales; discrete/bar legends; gradients; state styling; and virtualized
  tile/label builders.
- Added canvas semantics, keyboard navigation, RTL, locale formatter hooks,
  text scaling, reduced motion, platform behavior documentation,
  diagnostics, optional isolate layout, and benchmark budgets.
- Added property, unit, widget, gesture, accessibility, golden, public-extension,
  example-catalog, dependency-boundary, and feature-coverage validation.
- Removed all mutable legacy chart symbols, `GlobalKey` commands, private
  `fl_chart` integration, and `fl_chart`/`equatable` dependencies. No deprecated
  aliases, forwarding constructors, or compatibility adapters are included.
