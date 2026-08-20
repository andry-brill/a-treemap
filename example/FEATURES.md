# Feature-to-example coverage

Every row points to a named scenario in the runnable catalog. Keep this matrix
aligned with the catalog: each scenario should appear once, and every public
feature or meaningfully different variant should have a runnable example.

| Feature or meaningful variant | Scenario | Source | What to try |
|---|---|---|---|
| Explicit immutable hierarchy | `data-explicit-tree` | `lib/scenarios/data.dart` | Inspect nested source nodes. |
| Flat records and grouping factory | `data-from-records` | `lib/scenarios/data.dart` | Compare with the explicit tree. |
| Visual-free core, explicit no-op tiles, and neutral all-zero output | `data-empty-state` | `lib/scenarios/data.dart` | Observe that no package-defined empty visual is rendered. |
| Invalid input and typed errors | `data-invalid-errors` | `lib/scenarios/data.dart` | Read the issue and correction. |
| Optional isolate layout | `performance-isolate-layout` | `lib/scenarios/data.dart` | Run a 10,000-node layout. |
| Squarified | `layout-squarified` | `lib/scenarios/layout.dart` | Default area-preserving layout. |
| Resquarified stable updates | `layout-resquarified` | `lib/scenarios/layout.dart` | Compare topology during updates. |
| Slice | `layout-slice` | `lib/scenarios/layout.dart` | Horizontal flow. |
| Dice | `layout-dice` | `lib/scenarios/layout.dart` | Vertical flow. |
| Alternating slice-and-dice | `layout-alternating` | `lib/scenarios/layout.dart` | Observe absolute-depth alternation. |
| Strip | `layout-strip` | `lib/scenarios/layout.dart` | Ordered strip rows. |
| Binary by weight | `layout-binary-weight` | `lib/scenarios/layout.dart` | Weight-balanced partitions. |
| Binary by count | `layout-binary-count` | `lib/scenarios/layout.dart` | Count-balanced partitions. |
| Multilevel/depth/parent/resolver rules | `layout-multilevel` | `lib/scenarios/layout.dart` | Inspect mixed branch strategies. |
| Stable source/ascending/descending/custom sort policy | `layout-sort-policies` | `lib/scenarios/layout.dart` | Ascending stable order; edit the enum. |
| Four layout origins | `layout-four-origins` | `lib/scenarios/layout.dart` | Compare all corners together. |
| Horizontal-first and vertical-first | `layout-axis-orders` | `lib/scenarios/layout.dart` | Compare both primary axes. |
| Outer/level padding, gutters, explicit minimum dimensions, and Other | `layout-minimum-aggregation` | `lib/scenarios/layout.dart` | Resize and activate Other. |
| Custom layout strategy | `layout-custom-strategy` | `lib/scenarios/layout.dart` | Equal-column extension point. |
| Direct per-node Flutter colors that bypass scale resolution | `appearance-direct-node-colors` | `lib/scenarios/appearance.dart` | Compare assigned colors with the deliberately conflicting scale. |
| Exact color scale | `appearance-exact-scale` | `lib/scenarios/appearance.dart` | Exact values and fallback. |
| Categorical color scale and configurable `TreemapLegendItem`/`TreemapOverlayContainer` builders, title, labels, wrapping, and semantics label | `appearance-categorical-scale` | `lib/scenarios/appearance.dart` | Inspect the rounded theme-aware wrapper, custom 16 px swatches, and compact text. |
| Numeric range color scale | `appearance-range-scale` | `lib/scenarios/appearance.dart` | Range boundaries and legend. |
| Interpolated color scale, configurable stop formatter, `TreemapLegendBar`/`TreemapLegendPointer` builders, bar size, sampling, semantics, and pointer geometry | `appearance-interpolated-scale` | `lib/scenarios/appearance.dart` | Inspect the unit labels and custom 200×14 px rounded bar. |
| Saturation color scale | `appearance-saturation-scale` | `lib/scenarios/appearance.dart` | One-hue intensity mapping. |
| Explicit tiles, optimized bounded canvas labels, configurable/freely built lines, fallbacks, numeric precision, styles, opacity, color resolver, ellipsis, scale, gradients, borders, radius, and state resolver | `appearance-gradients-states` | `lib/scenarios/appearance.dart` | Inspect the title/value/depth lines, then hover and select. |
| `TreemapSurroundingGrid.fromMap`, natural-height rows, caller-sized content, and start/end placement; constraint-fitted 1:1 container, focused second-level navigation, custom selected breadcrumb styling, paired opacity-scale legends, edge-to-edge outer layout, transparent groups, responsive trailing-edge alignment, per-group aggregation, 32 px group spacing, and 16 px rounded/guttered children | `appearance-screenshot` | `lib/scenarios/appearance.dart` | Use the mapped top-start Level 1 > Level 2 breadcrumb and compare it with the paired mapped top-end scales; their 56 px SizedBoxes determine the row height, their `FittedBox` owns tight-cell scaling, and empty middle side slots let the treemap span the full width. |
| Composite tiles, fully customizable widget labels, clipping, layout minimum dimensions, aggregation, culling, and virtualization | `appearance-builders-virtualized` | `lib/scenarios/appearance.dart` | Inspect 80 icon/text labels over 79 normal leaves and a small Other block aggregating 41 tiny leaves. |
| Discrete legend, custom items, middle-start/vertical layout | `appearance-discrete-legend` | `lib/scenarios/appearance.dart` | Custom chip items. |
| Bar/segmented legend, custom pointer, middle-end layout | `appearance-bar-legend` | `lib/scenarios/appearance.dart` | Hover tiles to move the pointer. |
| Uncontrolled single selection | `interaction-uncontrolled-selection` | `lib/scenarios/interaction.dart` | Tap to toggle. |
| Controlled selection | `interaction-controlled-selection` | `lib/scenarios/interaction.dart` | Parent owns the set. |
| Multi-selection | `interaction-multi-selection` | `lib/scenarios/interaction.dart` | Select several keys. |
| Replaceable tooltip content/container builders, configurable `TreemapTooltipContainer`, deepest-leaf anchor, and lifecycle | `interaction-hover-tooltip` | `lib/scenarios/interaction.dart` | Hover, tap, inspect the configured standard shell, and wait for hide delay. |
| Tap drill-down, controller, and configurable `TreemapBreadcrumbItem`/separator/overlay widgets through thin builders | `interaction-drilldown-controller` | `lib/scenarios/interaction.dart` | Use chart taps and controller buttons, then inspect the themed wrapper and ellipsis result. |
| Animated breadcrumb indicator and aggregate reveal | `interaction-aggregate-reveal` | `lib/scenarios/interaction.dart` | Activate Other and navigate back. |
| Keyed data updates, resquarify, enter/exit animation | `interaction-updates-animation` | `lib/scenarios/interaction.dart` | Repeatedly update weights. |
| Mouse, touch, stylus, tap, long press, cursor callbacks | `interaction-pointer-modes` | `lib/scenarios/interaction.dart` | Use available device inputs. |
| Explicit replaceable semantics layer and keyboard traversal/activate/back | `accessibility-keyboard-semantics` | `lib/scenarios/accessibility.dart` | Use arrows, Enter, and Escape. |
| RTL labels/tooltips plus explicit RTL geometry policy | `accessibility-rtl` | `lib/scenarios/accessibility.dart` | Inspect direction independently. |
| Text scaling, bounded labels, dark theme, reduced animation | `accessibility-text-theme` | `lib/scenarios/accessibility.dart` | Inspect ellipsis and height-based omission. |
| Locale-aware value formatting | `accessibility-locale-formatting` | `lib/scenarios/accessibility.dart` | German decimal output. |
| Reduced motion | `accessibility-reduced-motion` | `lib/scenarios/accessibility.dart` | Environment disables transitions. |
