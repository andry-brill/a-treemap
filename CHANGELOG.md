# Changelog

## 2.0.0

- Added opt-in `TreemapSingleChildPolicy.promote` to normalization. Non-root
  single-child branches and repeated chains are replaced before the prepared
  tree is used. The root and child metadata are preserved; removed parent
  metadata, keys and colors are discarded. Navigation, breadcrumbs, layout
  depths and color domains use only the resulting hierarchy. The default
  `preserve` policy retains existing behavior, and all input is validated first.
- Added the playground's Single-child branches control and
  `data-single-child-promotion` preset. Automatic saturation now promotes B's
  only child Sixty, so its 60 tile stays at the root when clicked.
- **Breaking:** all chart, controller, layout and standalone presentation inputs
  now share a `TreemapNormalizedTree` prepared explicitly with
  `TreemapNormalizer.normalize`. Validation, indexes, branch totals and global
  color extrema are computed once and reused.
- **Breaking:** the controller owns navigation and uncontrolled selection.
  Hover, keyboard focus, tooltips, snapshots, color domains and transitions
  belong to the chart's single update coordinator.
- **Breaking:** visual and surrounding layers read immutable
  `TreemapPresentationState` and send keyed `TreemapActions`. Removed controller
  inputs from legends/breadcrumbs and duplicate fields from visual contexts.
- **Breaking:** removed `onSnapshot`, its callback typedef, controller hover
  APIs, `zoomIn` and `zoomToPathEntry`. `onPresentationChanged` is the sole
  chart-output callback, coalesced after the frame.
- Shared scale resolution and tile/label appearance calculations within a
  frame. Transient targets and timers are reconciled for source, focus,
  viewport, depth, culling, aggregation and disabled-interaction changes.
- Appearance caches expire after each rendering frame so custom layers refresh
  when inherited themes change. Aggregate navigation refreshes source ancestry
  and falls back safely when members move between parents.
- Rebuilt the example catalog as a URL-driven property playground. The 50
  existing IDs remain editable presets; `data-prepared-tree` adds two charts
  sharing one prepared source with independent interaction and visible domains.
- Added accessible property help, structured editors, responsive previews,
  comparisons, custom actions, standalone/external legends and isolate execution.
  Custom URLs include complete configuration and support browser Back/Forward.
- Moved example tests and goldens into the example package; CI runs package and
  example analysis/tests and a web build. Benchmarks separate source preparation
  from reused-tree layout.

### Migration from v1.x to v2

Prepare data once when it changes, and replace chart/layout `root` inputs with
`tree`. A controller can bind the same prepared input before standalone commands:

```dart
// v1
TreemapChart(root: root, tiles: tiles);
engine.layout(root: root, viewport: viewport);
controller.synchronize(root);

// v2
final tree = TreemapNormalizer.normalize(root);
TreemapChart(tree: tree, tiles: tiles);
engine.layout(tree: tree, viewport: viewport);
controller.synchronize(tree);
```

Replace `onSnapshot: (snapshot) => ...` with
`onPresentationChanged: (state) => ...` and read `state.targetSnapshot` for layout
or `state.displayedSnapshot` for the painted frame. Output callbacks now run after
the frame; keep prepared inputs stable during observer-driven rebuilds.

Read hover from `state.hoveredKey`/`state.hoveredColor`; replace controller hover
writes with `visual.actions.hover(key)` or `TreemapPresentationScope.actionsOf`.
Use `controller.zoomTo(key)` for explicit navigation. Aggregate reveal now accepts
its key and `memberKeys`, while custom chart layers use `actions.revealAggregate(key)`.

Custom layers read `visual.presentation.displayedSnapshot`, `.details`, `.statesFor`,
`.selectedEntries` and `.isAnimating`. Replace `visual.controller`, `onActivate`
and `onFocus` with keyed `visual.actions` commands. Surrounding `build`/`wrap`
callbacks receive `TreemapVisualContext` instead of a controller.

Pass `presentation` to an external legend. Breadcrumbs accept `presentation` and
`onNavigate: (entry) => controller.zoomTo(entry.key.sourceKey!)`. Inside a chart,
built-ins use the presentation scope and actions automatically. Standalone
presentation uses `TreemapPresentationState.fromData(tree: tree, targetSnapshot: snapshot)`;
static standalone legends may still use explicitly resolved scales. Remove controller `resolveColorScale` and `synchronizeLayout` calls. Resolve
automatic scales with `presentation.resolveColorScale` or `scale.resolveDomain`.

No deprecated aliases, forwarding constructors or compatibility adapters are
provided. Migration guidance is confined to this changelog.

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
