# Changelog

## 2.0.0

- Rebuilt the example catalog as a URL-driven property playground. All 50
  example IDs now select editable presets over shared datasets; customized
  links include complete settings and support browser Back/Forward.
- Added searchable property controls, accessible property help, structured
  palette/range/rule editors, responsive preview sizing, and registered modes
  for comparisons, custom compositions, standalone legends and isolate layout.
- Moved example-specific tests and golden coverage into the example package
  and added example analysis/tests to CI.

- **Breaking:** moved chart snapshots and color domains to immutable
  `TreemapPresentationState`. Removed controller `resolveColorScale` and
  `synchronizeLayout`; use `visual.presentation.resolveColorScale` in layers or
  `TreemapPresentationScope.of` in surrounding content. Controllers retain
  navigation, hover, and selection without receiving computed layout results.
- **Breaking:** `TreemapVisualContext` now requires a `presentation` argument.
  Custom hosts can construct it with `TreemapPresentationState.fromData`.
- Added `TreemapChart.onPresentationChanged` and `TreemapLegendView.presentation`
  for external legends and custom observers. Notifications reach presentation
  consumers after the frame without rebuilding through controller listeners.
- Standalone automatic legends now require presentation state or an explicitly
  resolved scale; a controller alone supplies interaction, not color domains.
- Added a runnable example of chart-owned state, scope-based chrome, custom
  tiles, and an external legend following depth changes and drill-down.

## 1.2.0

- Added automatic bounds to interpolated and saturation color scales. Minimum
  defaults to `double.negativeInfinity` and maximum to `double.infinity`;
  either bound can independently remain fixed.
- Added `TreemapColorDomainScope.global` (the default) and `.visible` to infer
  bounds from the full source hierarchy or the current focus, visible depth,
  culling, and aggregation. Constant domains use the midpoint color; empty
  domains retain the configured fallback and omit legend entries.
- Added immutable `resolveDomain` and controller `resolveColorScale` resolution
  for standalone and custom presentations. Tiles, labels, and legends share
  the destination domain throughout updates and transitions.
- Fixed weight-based legend pointers and stale color inputs when source data
  changes without changing tile geometry. Continuous pointers ignore
  nonnumeric inputs, including direct Flutter colors.
- Added runnable examples for global and visible automatic interpolation,
  mixed fixed/automatic bounds, automatic saturation, and standalone resolution.

## 1.1.0

- Added `TreemapLayoutConfig.maxVisibleDepth` for depth-limited rendering
  relative to the current zoom focus. Boundary branches retain full totals
  and drill-down behavior; null preserves unlimited depth. The category card
  example compares All (null), Depth 1, and Depth 2 above the chart.

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
